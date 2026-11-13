import Foundation
import Observation

/// Fetches the half of the badge data that is not free (Sodalite#79).
///
/// Resolution rides along on every card query, but dynamic range and spatial audio only exist in
/// `MediaStreams`, and Jellyfin's DtoService answers that field with a `GetStaticMediaSources` call
/// per item, which is exactly the cost Sodalite#68 took out of the grids. So the streams are never
/// part of the card field set: they are fetched afterwards, batched by id, cached per item, and the
/// result lives here rather than in `FilterCache`, whose keys must keep carrying one single field
/// set no matter who writes them.
@Observable
@MainActor
final class PosterBadgeStore {

    /// Movie and episode stream badges answer for themselves; series stream badges are sampled
    /// from a recent episode. Series personal ratings are calculated from all rated episodes,
    /// grouped by season, because Jellyfin has no series rating field.
    private static let batchSize = 40

    /// The library service and user an item's server answers through. A nil user means the
    /// caller's, which is how the active server keeps reading `AppState.activeUser` (Sodalite#85).
    private let route: @MainActor (_ serverID: String?) -> (library: JellyfinLibraryServiceProtocol, userID: String?)
    private let isBadgeEnabled: @MainActor () -> Bool
    private let isRatingEnabled: @MainActor () -> Bool

    /// `JellyfinItem.originKey` -> what its streams said. An entry with empty badges is a negative result and stops
    /// the id from being asked about again.
    private var enriched: [String: MediaBadges] = [:]
    private var inFlight: Set<String> = []
    private var seriesRatings: [String: Double] = [:]
    private var resolvedSeriesRatings: Set<String> = []
    private var ratingInFlight: Set<String> = []
    /// Tail of the series-sampling chain. Home shows several rows at once, each with its own task,
    /// so per-row serialisation would still let ten rows fan out; the chain makes it one sample at
    /// a time for the whole app.
    private var seriesTail: Task<Void, Never>?

    /// `userID` is passed per call rather than resolved here: `DependencyContainer.activeUserID`
    /// reads the keychain, and the callers hold `AppState.activeUser?.id` already (same reason
    /// `spoilerPolicy(userID:)` takes it as a parameter, Sodalite#50).
    init(route: @escaping @MainActor (String?) -> (library: JellyfinLibraryServiceProtocol, userID: String?),
         isBadgeEnabled: @escaping @MainActor () -> Bool,
         isRatingEnabled: @escaping @MainActor () -> Bool) {
        self.route = route
        self.isBadgeEnabled = isBadgeEnabled
        self.isRatingEnabled = isRatingEnabled
    }

    /// What the card should paint right now: the free resolution immediately, anything the
    /// enrichment has since found layered on top.
    func badges(for item: JellyfinItem) -> MediaBadges {
        let base = MediaBadgeResolver.badges(width: item.width, height: item.height, streams: item.mediaStreams)
        guard let found = enriched[item.originKey] else { return base }
        return MediaBadges(resolution: found.resolution ?? base.resolution,
                           dynamicRange: found.dynamicRange ?? base.dynamicRange,
                           audio: found.audio ?? base.audio,
                           audioCodec: found.audioCodec ?? base.audioCodec,
                           channelLayout: found.channelLayout ?? base.channelLayout)
    }


    func rating(for item: JellyfinItem, userID: String?) -> Double? {
        guard item.type == .series else { return item.userData?.rating }
        let resolvedUserID = route(item.serverID).userID ?? userID ?? ""
        guard !resolvedUserID.isEmpty else { return nil }
        return seriesRatings["\(item.originKey)|\(resolvedUserID)"]
    }

    func enrich(userID: String, _ items: [JellyfinItem]) async {
        let badgesEnabled = isBadgeEnabled()
        let ratingsEnabled = isRatingEnabled()
        guard badgesEnabled || ratingsEnabled else { return }

        var direct: [JellyfinItem] = []
        var series: [JellyfinItem] = []
        var seen: Set<String> = []
        for item in items where seen.insert(item.originKey).inserted {
            switch item.type {
            case .movie, .episode:
                if badgesEnabled && item.mediaStreams == nil
                    && enriched[item.originKey] == nil && !inFlight.contains(item.originKey) {
                    direct.append(item)
                }
            case .series:
                let targetUserID = route(item.serverID).userID ?? userID
                let ratingKey = "\(item.originKey)|\(targetUserID)"
                let needsBadges = badgesEnabled && item.mediaStreams == nil
                    && enriched[item.originKey] == nil && !inFlight.contains(item.originKey)
                let needsRating = ratingsEnabled && !resolvedSeriesRatings.contains(ratingKey)
                    && !ratingInFlight.contains(ratingKey)
                if needsBadges || needsRating { series.append(item) }
            default:
                continue
            }
        }
        guard !direct.isEmpty || !series.isEmpty else { return }

        let directKeys = Set(direct.map(\.originKey))
        inFlight.formUnion(directKeys)
        defer { inFlight.subtract(directKeys) }

        for (serverID, group) in Dictionary(grouping: direct, by: \.serverID) {
            let target = route(serverID)
            let ids = group.map(\.id)
            for start in stride(from: 0, to: ids.count, by: Self.batchSize) {
                await fetchBatch(Array(ids[start..<min(start + Self.batchSize, ids.count)]),
                                 serverID: serverID, library: target.library, userID: target.userID ?? userID)
            }
        }

        let seriesBadgeKeys = Set(series.filter { isBadgeEnabled() && $0.mediaStreams == nil && enriched[$0.originKey] == nil }.map(\.originKey))
        let seriesRatingKeys = Set(series.filter {
            let targetUserID = route($0.serverID).userID ?? userID
            return isRatingEnabled() && !resolvedSeriesRatings.contains("\($0.originKey)|\(targetUserID)")
        }.map {
            "\($0.originKey)|\(route($0.serverID).userID ?? userID)"
        })
        defer {
            inFlight.subtract(seriesBadgeKeys)
            ratingInFlight.subtract(seriesRatingKeys)
        }
        for item in series {
            guard !Task.isCancelled, isBadgeEnabled() || isRatingEnabled() else { return }
            let target = route(item.serverID)
            let targetUserID = target.userID ?? userID
            let ratingKey = "\(item.originKey)|\(targetUserID)"
            let needsRating = isRatingEnabled() && !resolvedSeriesRatings.contains(ratingKey)
            let needsBadges = isBadgeEnabled() && item.mediaStreams == nil && enriched[item.originKey] == nil
            if needsRating { ratingInFlight.insert(ratingKey) }
            if needsBadges { inFlight.insert(item.originKey) }
            await enqueueSample(item.id, originKey: item.originKey, ratingKey: ratingKey,
                                serverID: item.serverID, library: target.library, userID: targetUserID,
                                enrichBadges: needsBadges, enrichRating: needsRating)
        }
    }

    private func fetchBatch(_ ids: [String], serverID: String?, library: JellyfinLibraryServiceProtocol, userID: String) async {
        let response: JellyfinItemsResponse
        do {
            response = try await library.getItems(
                userID: userID,
                query: ItemQuery(ids: ids, fields: "MediaStreams"))
        } catch {
            return  // Nothing cached, so a later pass over the same row tries again.
        }
        // Seed every requested id, not just the answered ones: an item the server says nothing
        // about must not be asked a second time on every scroll.
        let key = { (id: String) in "\(serverID ?? "")|\(id)" }
        var found = Dictionary(uniqueKeysWithValues: ids.map { (key($0), MediaBadges()) })
        for item in response.items {
            found[key(item.id)] = MediaBadgeResolver.badges(width: item.width, height: item.height, streams: item.mediaStreams)
        }
        enriched.merge(found) { _, new in new }
    }

    private func enqueueSample(_ seriesID: String, originKey: String, ratingKey: String,
                               serverID: String?, library: JellyfinLibraryServiceProtocol, userID: String,
                               enrichBadges: Bool, enrichRating: Bool) async {
        let previous = seriesTail
        let sample = Task { @MainActor [weak self] in
            await previous?.value
            await self?.sampleSeries(seriesID, originKey: originKey, ratingKey: ratingKey,
                                     serverID: serverID, library: library, userID: userID,
                                     enrichBadges: enrichBadges, enrichRating: enrichRating)
        }
        seriesTail = sample
        await withTaskCancellationHandler {
            await sample.value
        } onCancel: {
            sample.cancel()
        }
    }

    private func sampleSeries(_ seriesID: String, originKey: String, ratingKey: String,
                              serverID: String?, library: JellyfinLibraryServiceProtocol, userID: String,
                              enrichBadges: Bool, enrichRating: Bool) async {
        if enrichRating {
            let pageSize = 200
            var episodes: [JellyfinItem] = []
            var startIndex = 0
            var didLoadRatings = true
            while true {
                guard !Task.isCancelled else { return }
                do {
                    let response = try await library.getItems(
                        userID: userID,
                        query: ItemQuery(parentID: seriesID, includeItemTypes: [.episode],
                                         limit: pageSize, startIndex: startIndex, fields: "")
                    )
                    episodes += response.items
                    startIndex += response.items.count
                    if response.items.isEmpty || episodes.count >= response.totalRecordCount
                        || response.items.count < pageSize { break }
                } catch {
                    didLoadRatings = false
                    break
                }
            }
            if didLoadRatings {
                if let rating = PosterRatingCalculator.seriesRating(episodes: episodes) {
                    seriesRatings[ratingKey] = rating
                }
                resolvedSeriesRatings.insert(ratingKey)
            } else {
                ratingInFlight.remove(ratingKey)
            }
        }

        if enrichBadges {
            let query = ItemQuery(parentID: seriesID, includeItemTypes: [.episode],
                                  sortBy: "DateCreated", sortOrder: "Descending",
                                  limit: 1, fields: "MediaStreams")
            guard let response = try? await library.getItems(userID: userID, query: query) else {
                inFlight.remove(originKey)
                return
            }
            enriched["\(serverID ?? "")|\(seriesID)"] = response.items.first.map {
                MediaBadgeResolver.badges(width: $0.width, height: $0.height, streams: $0.mediaStreams)
            } ?? MediaBadges()
            inFlight.remove(originKey)
        }
        ratingInFlight.remove(ratingKey)
    }

}
