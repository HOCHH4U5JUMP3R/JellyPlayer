import SwiftUI

enum MediaCardStyle: Sendable {
    case poster    // Vertical 2:3 (movies, series)
    case landscape // Horizontal 16:9 (episodes, continue watching)
    case square    // 1:1 (album / music covers)

}

struct MediaCard: View {
    let item: JellyfinItem
    let imageURL: URL?
    /// Tried when `imageURL` is nil or fails (e.g. series Thumb to backdrop/episode still for Continue Watching).
    let fallbackURL: URL?
    let style: MediaCardStyle

    /// Passed explicitly because tvOS's `@Environment(\.isFocused)` doesn't propagate reliably through Button labels; caller forwards from `FocusableCard` or a `@FocusState` match.
    let isFocused: Bool

    /// Sodalite#66. Set where the row paints show-level art (Continue Watching on Backdrop or
    /// Thumb): a series backdrop is marketing art, so the spoiler veil stays off the image.
    let showsSeriesArtwork: Bool
    /// Server name for a same-name collection or playlist from another server (Sodalite#85).
    let serverLabel: String?

    @Environment(\.dependencies) private var dependencies
    @Environment(\.appState) private var appState
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @State private var isHovered = false

    /// Enlarge factor from Appearance settings (1.0 normal), applied to every style so rows stay proportional.
    private var scale: CGFloat { dependencies.appearancePreferences.cardScale }

    private var cardSize: CGSize {
        let base = LayoutMetrics.current(hSizeClass).size(for: style)
        return CGSize(width: base.width * scale, height: base.height * scale)
    }
    private var cardWidth: CGFloat { cardSize.width }

    /// Off the tier's poster width, not this card's, so a landscape card wears the same pill as the
    /// poster beside it (Sodalite#79). The watched badge opposite reads the same width (Sodalite#89).
    private var tierPosterWidth: CGFloat { LayoutMetrics.current(hSizeClass).posterSize.width }

    private var badgeFontSize: CGFloat {
        PosterBadgeMetrics.fontSize(posterWidth: tierPosterWidth, scale: scale)
    }
    private var cardHeight: CGFloat { cardSize.height }

    init(
        item: JellyfinItem,
        imageURL: URL?,
        fallbackURL: URL? = nil,
        style: MediaCardStyle = .poster,
        isFocused: Bool = false,
        showsSeriesArtwork: Bool = false,
        serverLabel: String? = nil
    ) {
        self.item = item
        self.imageURL = imageURL
        self.fallbackURL = fallbackURL
        self.style = style
        self.isFocused = isFocused
        self.showsSeriesArtwork = showsSeriesArtwork
        self.serverLabel = serverLabel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            posterImage
            itemInfo
        }
        .frame(width: cardWidth)
        .accessibilityElement(children: .combine)
        .accessibilityValue(accessibilityProgress)
        #if !os(tvOS)
        .onHover { isHovered = $0 }
        #endif
    }

    private var posterImage: some View {
        AsyncCachedImage(url: imageURL, fallbackURL: fallbackURL) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            ZStack {
                Rectangle()
                    .fill(Color.Theme.surface)
                Image(systemName: iconForType)
                    .font(.system(size: 40))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        // Sodalite#50: before the clip so the blur cannot bleed past the tile edge. No type check
        // here, the policy already passes everything that is not an unseen episode or movie.
        .spoilerVeil(for: item, style: .image, veils: !showsSeriesArtwork)
        .clipShape(RoundedRectangle(cornerRadius: ArtworkCorner.radius))
        // The clip is visual only, so without this the artwork stays TAPPABLE where it is invisible.
        // A fill-scaled image overflows the card on one axis by design: a 16:9 still in a 2:3 card
        // draws 320pt wide inside a 120pt frame, so it reached 100pt past both edges and, being a
        // later sibling in the row, sat on top of the card to its left and answered its taps
        // (measured on device, discussion #98: a tap at x=89 fired the card whose frame is 148..268).
        // Only cards whose artwork aspect matches their style were ever safe, which is why it showed
        // up on one row and not the rest.
        .contentShape(RoundedRectangle(cornerRadius: ArtworkCorner.radius))
        .overlay(alignment: .bottom) {
            progressOverlay
        }
        // The personal rating belongs at top-left; the watched mark keeps its own top-right corner.
        .overlay(alignment: .topLeading) {
            if style != .square {
                PosterBadgeOverlay(
                    item: item,
                    fontSize: badgeFontSize,
                    posterWidth: tierPosterWidth,
                    scale: scale
                )
            }
        }
        .overlay(alignment: .topTrailing) {
            ArtworkStateBadges(
                isPlayed: item.userData?.played == true,
                posterWidth: tierPosterWidth,
                scale: scale
            )
        }
        .overlay(
            MediaFocusRing(
                cornerRadius: ArtworkCorner.radius,
                isFocused: isFocused
            )
        )
    }

    private var itemInfo: some View {
        // Always render the subtitle slot (even empty) so cards keep equal height; poster titles and
        // their year share a centred baseline under the artwork.
        VStack(alignment: style == .poster ? .center : .leading, spacing: style == .poster ? 6 : 2) {
            if style == .poster {
                MediaCardMarqueeLabel(
                    text: displayTitle,
                    font: .caption,
                    color: .primary,
                    isActive: isFocused || isHovered
                )
                // Keep the year on its own fixed line; only the title uses the marquee.
                Text(displaySubtitle ?? " ")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(width: cardWidth, height: 18, alignment: .center)
            } else {
                Text(displayTitle)
                    .font(.caption)
                    .lineLimit(1)

                Text(displaySubtitle ?? " ")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: cardWidth, alignment: style == .poster ? .center : .leading)
    }

    private var displayTitle: String {
        let policy = dependencies.spoilerPolicy(userID: appState.activeUser?.id)
        guard style == .landscape, item.type == .episode else { return policy.displayName(of: item) }
        let label = EpisodeMetadataFormatter.label(season: nil, episode: item.indexNumber,
                                                   title: policy.visibleTitle(of: item))
        return label.isEmpty ? policy.displayName(of: item) : label
    }

    private var displaySubtitle: String? {
        if let serverLabel { return serverLabel }
        if item.type == .episode, let seriesName = item.seriesName {
            // Season only: the episode number is already on the title line above.
            return EpisodeMetadataFormatter.label(seriesName: seriesName,
                                                  season: item.parentIndexNumber,
                                                  episode: nil, title: nil)
        }
        if let year = item.productionYear {
            return String(year)
        }
        return nil
    }

    @ViewBuilder
    private var progressOverlay: some View {
        if let resumeFraction {
            ResumeProgressBar(fraction: resumeFraction,
                              remaining: item.resumeRemainingTicks?.ticksToDurationDisplay,
                              posterWidth: tierPosterWidth,
                              scale: scale)
        }
    }

    /// nil means this card shows no progress at all, which is both the bar and what VoiceOver
    /// reads: one source, so the spoken description cannot describe something that is not drawn.
    private var resumeFraction: Double? {
        ResumeIndicator.cardFraction(
            style: style,
            posterProgressEnabled: dependencies.appearancePreferences.showPosterProgress,
            playedPercentage: item.userData?.playedPercentage,
            isPlayed: item.userData?.played == true,
            playbackPositionTicks: item.userData?.playbackPositionTicks
        )
    }

    /// Progress was purely visual before this, VoiceOver got nothing from the bar at all. Composed
    /// from a percent style and the same compact remaining string the label shows, so it carries no
    /// sentence of its own into 26 languages.
    private var accessibilityProgress: String {
        guard let resumeFraction else { return "" }
        let percent = resumeFraction.formatted(.percent.precision(.fractionLength(0)))
        guard let remaining = item.resumeRemainingTicks?.ticksToDurationDisplay else { return percent }
        return "\(percent), \(remaining)"
    }

    private var iconForType: String {
        switch item.type {
        case .movie: "film"
        case .series: "tv"
        case .episode: "play.rectangle"
        case .season: "tv"
        case .musicAlbum, .audio: "music.note"
        case .video: "play.rectangle"
        case .folder: "folder"
        default: "photo"
        }
    }
}


/// A poster title stays centred and truncated at rest, then scrolls continuously while its card
/// is focused/hovered. Measuring the intrinsic width avoids guessed character counts across locales.
private struct MediaCardMarqueeLabel: View {
    let text: String
    let font: Font
    let color: Color
    let isActive: Bool

    @State private var textWidth: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0

    private let gap: CGFloat = 30

    private func updateScroll(start: CGFloat, overflows: Bool) {
        guard isActive, overflows else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { scrollOffset = 0 }
            return
        }
        scrollOffset = start
        withAnimation(.linear(duration: Double(textWidth + gap) / 28).repeatForever(autoreverses: false)) {
            scrollOffset = -(textWidth + gap) + start
        }
    }

    private var label: some View {
        Text(text)
            .font(font)
            .foregroundStyle(color)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let start = max(0, (width - textWidth) / 2)
            let overflows = textWidth > width + 1

            Group {
                if overflows && isActive {
                    HStack(spacing: gap) {
                        label
                        label
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .offset(x: scrollOffset)
                    .onAppear { updateScroll(start: start, overflows: overflows) }
                    .onChange(of: isActive) { _, _ in
                        updateScroll(start: start, overflows: overflows)
                    }
                    .onChange(of: textWidth) { _, _ in
                        updateScroll(start: start, overflows: overflows)
                    }
                } else {
                    Text(text)
                        .font(font)
                        .foregroundStyle(color)
                        .lineLimit(1)
                        .frame(width: width, alignment: .center)
                        .offset(x: overflows ? start : 0)
                }
            }
            .frame(width: width, alignment: .leading)
            .clipped()
            .background {
                label
                    .background {
                        GeometryReader { textGeometry in
                            Color.clear.preference(
                                key: MediaCardTextWidthKey.self,
                                value: textGeometry.size.width
                            )
                        }
                    }
                    .hidden()
            }
        }
        .onPreferenceChange(MediaCardTextWidthKey.self) { textWidth = $0 }
        .frame(height: 22)
        .accessibilityLabel(Text(text))
    }
}

private struct MediaCardTextWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
