import SwiftUI

/// Sub-components extracted from SeriesDetailView. SeasonTab receives the season-bar FocusState as a parameter, so nothing here reaches into the view's focus state.

// MARK: - Season Tab

struct SeasonTab: View {
    let id: String
    let name: String
    let imageURL: URL?
    let personalRating: Double?
    let isPlayed: Bool
    let isSelected: Bool
    var focusedID: FocusState<String?>.Binding
    let action: () -> Void

    private var isFocused: Bool { focusedID.wrappedValue == id }

    var body: some View {
        VStack(alignment: .center, spacing: 5) {
            Button { action() } label: {
                ZStack(alignment: .topLeading) {
                    AsyncCachedImage(url: imageURL) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.Theme.surface)
                            .overlay(Image(systemName: "tv").font(.title2).foregroundStyle(.tertiary))
                    }
                    .frame(width: 150, height: 225)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder((isFocused || isSelected) ? Color.accentColor : Color.clear,
                                          lineWidth: (isFocused || isSelected) ? FocusStroke.width : 0)
                    }

                    if isPlayed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 23, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(7)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    }

                    if let personalRating {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                            Text(Int(personalRating.rounded()).formatted())
                        }
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 5)
                        .background(.black.opacity(0.72), in: Capsule())
                        .padding(7)
                    }
                }
            }
            .buttonStyle(SeasonTabButtonStyle())
            .focused(focusedID, equals: id)

            Text(name)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 150, alignment: .center)
                .multilineTextAlignment(.center)
        }
        .scaleEffect(isFocused ? 1.05 : 1)
        .zIndex(isFocused ? 1 : 0)
        .animation(.easeOut(duration: 0.16), value: isFocused)
    }
}


// MARK: - Button Styles

struct EpisodeCardButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        // Stroke drawn inside EpisodeLandscapeCard so it hugs the thumbnail only, not the caption below.
        configuration.label
            .focusResponse(.card, isFocused: isFocused)
    }
}

struct SeasonTabButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        // Asymmetric stroke: 50ms fade-in delay, 0 fade-out. A residual wrong-tab transition slipping past the onMoveCommand prime never shows the stroke, the 50ms window lets the DispatchQueue fallback land focus on the right tab first. 50ms is sub-perceptual.
        configuration.label
            // Not `.focusStroke`: this stroke carries its own asymmetric timing, which the shared
            // modifier has no place for. The width is the same 3.
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.tint, lineWidth: FocusStroke.width)
                    .opacity(isFocused ? 1 : 0)
                    .animation(
                        isFocused
                            ? .easeIn(duration: 0.15).delay(0.05)
                            : .easeOut(duration: 0.1),
                        value: isFocused
                    )
            )
            // Keep the focused poster outlined without applying the tvOS chip scale transform;
            // the first season must remain fully inside the leading viewport edge.
    }
}

// MARK: - Episode Landscape Card

/// Loading placeholder mirroring EpisodeLandscapeCard's 360x202 thumbnail + caption lines, with one sweeping highlight.
struct EpisodeSkeletonCard: View {
    @State private var shimmer = false

    @Environment(\.dependencies) private var dependencies
    @Environment(\.horizontalSizeClass) private var hSizeClass
    var sizeOverride: CGSize? = nil
    private var cardSize: CGSize {
        sizeOverride ?? LayoutMetrics.current(hSizeClass)
            .tileSize(cardScale: dependencies.appearancePreferences.cardScale)
    }

    /// What is left for the artwork once the ring has its margin. The CARD keeps `cardSize`, so the
    /// row's spacing, the scroll aim and every tile measurement stay exactly where they were.
    private var artworkSize: CGSize {
        CGSize(width: cardSize.width - 2 * EpisodeCardStroke.ringMargin,
               height: cardSize.height - 2 * EpisodeCardStroke.ringMargin)
    }
    private var synopsisWidth: CGFloat { cardSize.width - 28 }

    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.Theme.surface)
            .frame(width: cardSize.width, height: cardSize.height)
            .overlay(shimmerOverlay.clipShape(RoundedRectangle(cornerRadius: 12)))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: false)) {
                shimmer = true
            }
        }
    }

    private var shimmerOverlay: some View {
        LinearGradient(
            colors: [.clear, Color.white.opacity(0.08), .clear],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: 180)
        .offset(x: shimmer ? cardSize.width : -180)
    }
}

struct EpisodeLandscapeCard: View {
    let episode: JellyfinItem
    let imageURL: URL?

    /// The episode the page's Play button acts on, resolved by the page's own playTarget so the ring and the button cannot claim different cards.
    var isPlayTarget: Bool = false

    /// Passed explicitly (focusedEpisodeID == episode.id): @Environment(\.isFocused) in a Button label is unreliable on tvOS.
    var isFocused: Bool = false

    /// Passed explicitly so the badge live-updates from the VM override map (the immutable episode.userData wouldn't change in-session).
    var isPlayed: Bool = false

    /// Same reason as isPlayed; also the only feedback the context-menu favorite toggle has.
    var isFavorite: Bool = false

    /// The viewer's personal rating, rendered at the artwork's top-left.
    var personalRating: Double? = nil

    /// The viewer's own mark-watched from this session, which is a different fact from `isPlayed`
    /// and the only one that may hide the resume indicator (`DetailViewModel.wasMarkedPlayedInSession`).
    var justMarkedPlayed: Bool = false
    var sizeOverride: CGSize? = nil

    @Environment(\.appearanceTheme) private var appearanceTheme
    @Environment(\.dependencies) private var dependencies
    @Environment(\.appState) private var appState
    @Environment(\.horizontalSizeClass) private var hSizeClass
    private var spoilerPolicy: SpoilerPolicy {
        dependencies.spoilerPolicy(userID: appState.activeUser?.id)
    }
    private var cardSize: CGSize {
        sizeOverride ?? LayoutMetrics.current(hSizeClass)
            .tileSize(cardScale: dependencies.appearancePreferences.cardScale)
    }

    /// What is left for the artwork once the ring has its margin. The CARD keeps `cardSize`, so the
    /// row's spacing, the scroll aim and every tile measurement stay exactly where they were.
    private var artworkSize: CGSize {
        CGSize(width: cardSize.width - 2 * EpisodeCardStroke.ringMargin,
               height: cardSize.height - 2 * EpisodeCardStroke.ringMargin)
    }

    var body: some View {
        ZStack {
            AsyncCachedImage(url: imageURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle().fill(Color.Theme.surface)
                    .overlay(Image(systemName: "play.rectangle").font(.system(size: 30)).foregroundStyle(.tertiary))
            }
            .frame(width: artworkSize.width, height: artworkSize.height)
            .spoilerVeil(for: episode, style: .image)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            if let fraction = resumeFraction {
                ResumeProgressBar(fraction: fraction, remaining: remainingLabel,
                                  posterWidth: LayoutMetrics.current(hSizeClass).posterSize.width)
                    .frame(width: artworkSize.width, height: artworkSize.height)
            }
            ArtworkStateBadges(isFavorite: isFavorite, isPlayed: isPlayed,
                               posterWidth: LayoutMetrics.current(hSizeClass).posterSize.width)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            if let personalRating {
                HStack(spacing: 5) {
                    Image(systemName: "star.fill").font(.system(size: 17, weight: .semibold))
                    Text(Int(personalRating.rounded()).formatted()).font(.system(size: 17, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white).padding(.horizontal, 9).padding(.vertical, 6)
                .background(.black.opacity(0.72), in: Capsule())
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(10)
            }
            VStack(spacing: 3) {
                let rawToken = EpisodeMetadataFormatter.seasonEpisode(season: nil, episode: episode.indexNumber)
                let token = rawToken.hasPrefix("E") ? String(rawToken.dropFirst()) : rawToken
                if let title = spoilerPolicy.visibleTitle(of: episode) {
                    Text(token.isEmpty ? title : "\(token) · \(title)")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .lineLimit(2).multilineTextAlignment(.center).foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.95), radius: 4, x: 0, y: 2)
                } else if !token.isEmpty {
                    Text(token).font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white).shadow(color: .black.opacity(0.95), radius: 4, x: 0, y: 2)
                }
            }
            .padding(.horizontal, 12).padding(.bottom, 10)
            .frame(width: artworkSize.width, height: artworkSize.height, alignment: .bottom)
            .background(alignment: .bottom) {
                LinearGradient(colors: [.clear, .black.opacity(0.82)], startPoint: .center, endPoint: .bottom)
                    .frame(width: artworkSize.width, height: artworkSize.height * 0.42)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .frame(width: artworkSize.width, height: artworkSize.height)
        // Clip the COMPLETE artwork composition (image, resume bar, badges and title gradient)
        // rather than only the source image; otherwise the bottom gradient paints square corners.
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12 + strokeWidth)
            .strokeBorder(strokeStyle, lineWidth: strokeWidth).padding(-strokeWidth)
            .animation(.easeInOut(duration: 0.2), value: isFocused))
        .padding(EpisodeCardStroke.ringMargin)
        .frame(width: cardSize.width, height: cardSize.height)
    }

    /// Capsule and label go together, and both read the session's own mark-watched rather than    /// Capsule and label go together, and both read the session's own mark-watched rather than
    /// `isPlayed`: marking an episode watched in the context menu has to clear the indicator without
    /// a refetch, while a server `played` that came WITH a position is a re-watch and keeps it.
    private var resumeFraction: Double? {
        guard !justMarkedPlayed else { return nil }
        return ResumeIndicator.fraction(playedPercentage: episode.userData?.playedPercentage,
                                        playbackPositionTicks: episode.userData?.playbackPositionTicks)
    }

    private var remainingLabel: String? {
        guard !justMarkedPlayed else { return nil }
        return episode.resumeRemainingTicks?.ticksToDurationDisplay
    }

    private var stroke: EpisodeCardStroke {
        .role(isFocused: isFocused, isPlayTarget: isPlayTarget)
    }

    /// Focus takes the semantic media role, the play target a green that is neither of the two accent
    /// roles on this row (the tint on the episode token, the focus role on the ring next door).
    private var strokeStyle: AnyShapeStyle {
        switch stroke {
        case .focused: return AnyShapeStyle(appearanceTheme.palette.focus.color)
        case .playTarget: return AnyShapeStyle(appearanceTheme.palette.focus.color)
        case .none: return AnyShapeStyle(Color.clear)
        }
    }

    private var strokeWidth: CGFloat { stroke.lineWidth }
}

// MARK: - Episode Synopsis Box

/// Navigable per-card synopsis box (mirrors ExpandableTextBox). Always reserves three lines so columns stay equal height; an overview-less episode renders non-focusable reserved space, no focusable-but-empty dead end.
struct EpisodeSynopsisBox: View {
    let episode: JellyfinItem
    let text: String
    @State private var showFullText = false
    @FocusState private var isFocused: Bool

    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.dependencies) private var dependencies
    @Environment(\.appState) private var appState

    private var isSpoilerHidden: Bool {
        SpoilerReveal.isHidden(episode, dependencies: dependencies, appState: appState)
    }
    /// Matches the episode card width (card width minus the 14pt horizontal padding each side) so
    /// the synopsis column lines up under its card, Large Cards included: the padding stays put and
    /// the text column takes the growth, so the box still measures exactly one card.
    private var synopsisWidth: CGFloat {
        LayoutMetrics.current(hSizeClass)
            .tileSize(cardScale: dependencies.appearancePreferences.cardScale).width - 28
    }

    private var hasText: Bool { !text.isEmpty }

    var body: some View {
        Group {
            if hasText {
                Text(text)
            } else {
                // Visible placeholder, not an invisible spacer: an overview-less column looks broken next to filled ones (Sodalite#15). Non-focusable, nothing to expand.
                Text("detail.noDescription")
                    .italic()
            }
        }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(3, reservesSpace: true)
            .multilineTextAlignment(.leading)
            .frame(width: synopsisWidth, alignment: .topLeading)
            // Sodalite#50: only the text is veiled, so the material and the focus stroke stay sharp.
            .spoilerVeil(for: episode, style: .text)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                // Material base for the full-bleed backdrop redesign (ExpandableTextBox rationale).
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            )
            .focusStroke(cornerRadius: 12, isFocused: isFocused)
            .focusResponse(.inline, isFocused: isFocused)
            .focusableSurface(hasText)
            .focused($isFocused)
            .stableTap(isFocused: isFocused) {
                guard hasText else { return }
                // Sodalite#50: the first Select uncovers, the second expands as before. One reveal
                // covers this episode's still too, both resolve through the same key.
                if isSpoilerHidden {
                    SpoilerReveal.reveal(episode, dependencies: dependencies, appState: appState)
                    return
                }
                showFullText = true
            }
            .fullScreenCoverCompat(isPresented: $showFullText) {
                TextOverlay(text: text, isPresented: $showFullText)
            }
    }
}

// MARK: - Episode Row Aim

/// Which card the episode row aims at when focus enters it. Three entries read it (a move down from
/// the season bar, the one-shot redirect that catches a focus arriving from anywhere else, and the
/// return from the player), so it is one memory and one resolver rather than a rule per entry.
///
/// The memory is written on the way OUT of the row, never on the way in, else it would answer the
/// entry redirect with the card that redirect is still resolving. The player writes it too: an
/// in-session item switch happens behind the modal, and without that write the row still names the
/// episode the session was STARTED from, which is what dropped a viewer who binged 10 through 20
/// back on 10.
struct EpisodeRowAim: Equatable {
    private(set) var rememberedID: String?

    /// Focus left the row on `id`.
    mutating func focusLeft(_ id: String) {
        rememberedID = id
    }

    /// The player moved the session onto `id` (auto-advance, queue, season picker) while the row sat behind it.
    mutating func sessionMoved(to id: String) {
        rememberedID = id
    }

    /// The card an entry lands on: the remembered one while the loaded season still holds it (the
    /// filter is what makes a memory from another season fall through), else the series' current
    /// episode, else the start of the row.
    func target(in episodeIDs: [String], currentEpisodeID: String?) -> String? {
        if let rememberedID, episodeIDs.contains(rememberedID) {
            return rememberedID
        }
        if let currentEpisodeID, episodeIDs.contains(currentEpisodeID) {
            return currentEpisodeID
        }
        return episodeIDs.first
    }
}

// MARK: - Episode Card Stroke

/// What the ring around an episode card says, and how thick it is saying it.
///
/// It used to carry three meanings, two of which always landed on the same card: the page resolves
/// its play target from the selected episode first, so "selected" and "what Play does" were one
/// answer drawn twice, in two colours. Focus wins over the play target, because a ring answers "you
/// are here" before it answers "this is where Play goes".
enum EpisodeCardStroke: CaseIterable {
    case none
    case playTarget
    case focused

    static func role(isFocused: Bool, isPlayTarget: Bool) -> EpisodeCardStroke {
        if isFocused { return .focused }
        return isPlayTarget ? .playTarget : .none
    }

    var lineWidth: CGFloat {
        switch self {
        case .none: return 0
        case .playTarget: return 3
        case .focused: return 4
        }
    }

    /// The margin a card reserves around its artwork for its own ring.
    ///
    /// The stroke is drawn OUTSIDE the artwork so it does not bite into it or cover the resume bar
    /// (Sodalite#134), and it used to be drawn outside the CARD as well, which is a different thing
    /// and the reason a lifted card lost its ring: iOS builds a long-press preview by snapshotting
    /// the view's bounds, and three of the ring's four sides were beyond them (reported on the
    /// iPhone, 2026-09-14). Reserving the widest stroke keeps the ring off the artwork and inside
    /// the card, and reserving it CONSTANTLY, rather than per state, is what stops the artwork
    /// resizing when a card takes focus.
    static var ringMargin: CGFloat { allCases.map(\.lineWidth).max() ?? 0 }
}
