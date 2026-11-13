import SwiftUI

/// Scores supplied by Jellyseerr or a configured metadata source.
struct ExternalRatings: Equatable, Sendable {
    var tmdb: Double?
    var imdb: Double?
    var tvdb: Double?
    var rottenTomatoes: Int?
}

/// All available rating sources are shown independently; Jellyfin Community is not hidden when
/// an external score arrives.
struct RatingDisplay: Equatable {
    var tmdb: Double?
    var imdb: Double?
    var tvdb: Double?
    var community: Double?
    var rottenTomatoes: Int?

    static func resolve(
        communityRating: Double?,
        criticRating: Double?,
        external: ExternalRatings?,
        awaitingExternal: Bool
    ) -> RatingDisplay {
        RatingDisplay(
            tmdb: external?.tmdb.flatMap { $0 > 0 ? $0 : nil },
            imdb: external?.imdb.flatMap { $0 > 0 ? $0 : nil },
            tvdb: external?.tvdb.flatMap { $0 > 0 ? $0 : nil },
            community: communityRating.flatMap { $0 > 0 ? $0 : nil },
            rottenTomatoes: criticRating.map { Int($0) } ?? external?.rottenTomatoes
        )
    }
}

/// Brand mark and score. The marks are kept at a common visual height across sources.
struct NamedScoreLabel: View {
    let source: String
    let score: Double?

    var body: some View {
        HStack(spacing: 5) {
            brandMark
                .frame(height: 22)
            Text(score.map { String(format: "%.1f", $0) } ?? "–")
                .monospacedDigit()
        }
        .accessibilityLabel(Text("\(source) \(score.map { String(format: "%.1f", $0) } ?? "keine Wertung")"))
    }

    @ViewBuilder
    private var brandMark: some View {
        switch source {
        case "IMDb":
            Image("IMDbMark")
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: 26, height: 22)
        case "TMDB":
            Image("TMDBMark")
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: 26, height: 22)
        case "TVDB":
            AsyncImage(url: URL(string: "https://thetvdb.com/images/attribution/logo1.png")) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Text("TVDB")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(.white)
            }
            .frame(width: 48, height: 22)
            .accessibilityLabel("TheTVDB")
        default:
            Text(source)
                .font(.caption.weight(.heavy))
        }
    }
}

/// Jellyfin's community score.
struct StarScoreLabel: View {
    let score: Double

    var body: some View {
        HStack(spacing: 5) {
            Image("JellyfinMark")
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
            Text(String(format: "%.1f", score))
                .monospacedDigit()
        }
        .accessibilityLabel("Jellyfin Community \(String(format: "%.1f", score))")
    }
}

/// The viewer's own score, distinct from the community score.
struct PersonalRatingLabel: View {
    let score: Double

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "star.fill")
                .foregroundStyle(.yellow)
                .font(.system(size: 21, weight: .semibold))
            Text(String(format: "%.1f", score))
                .monospacedDigit()
        }
        .accessibilityLabel("Meine Wertung \(String(format: "%.1f", score))")
    }
}

/// Rotten Tomatoes uses the red rotten-tomato mark consistently, as requested.
struct RottenTomatoesLabel: View {
    let score: Int
    var iconHeight: CGFloat = 22

    var body: some View {
        HStack(spacing: 5) {
            Image("RTRotten")
                .resizable()
                .renderingMode(.original)
                .aspectRatio(contentMode: .fit)
                .frame(height: iconHeight)
            Text(verbatim: "\(score) %")
                .monospacedDigit()
        }
    }
}
