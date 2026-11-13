import SwiftUI

/// The pills in a card's top-left corner (Sodalite#79).
///
/// A leaf on purpose: it, not `MediaCard`, reads the badge store, so a batch of enrichment landing
/// invalidates the overlays and not the two hundred cards around them. The top right belongs to the
/// watched checkmark and the bottom edge to the resume bar, so the corner is free.
struct PosterBadgeOverlay: View {
    let item: JellyfinItem
    let fontSize: CGFloat
    let posterWidth: CGFloat
    let scale: CGFloat

    @Environment(\.dependencies) private var dependencies

    var body: some View {
        let appearance = dependencies.appearancePreferences
        let pills = appearance.showPosterBadges ? dependencies.posterBadgeStore.badges(for: item).pills : []
        // Jellyfin UserData.Rating is the viewer's own rating (including Scrob's computed
        // series rating synced back as a user rating), not CommunityRating.
        let rating = appearance.showPosterRating ? item.userData?.rating : nil

        if item.type == .series, let rating {
            VStack(alignment: .leading, spacing: fontSize * 0.2) {
                SeriesPosterRatingBadge(
                    rating: rating,
                    posterWidth: posterWidth,
                    scale: scale
                )
                if !pills.isEmpty {
                    PosterBadgePills(pills: pills, fontSize: fontSize)
                }
            }
            .padding(PosterBadgeMetrics.checkInset(posterWidth: posterWidth, scale: scale))
        } else if !pills.isEmpty || rating != nil {
            PosterBadgePills(pills: pills, fontSize: fontSize, rating: rating)
        }
    }
}

/// A series rating mirrors the watched mark: same circular footprint and corner inset,
/// with the score readable inside the disc.
private struct SeriesPosterRatingBadge: View {
    let rating: Double
    let posterWidth: CGFloat
    let scale: CGFloat

    private var diameter: CGFloat {
        PosterBadgeMetrics.checkDiameter(posterWidth: posterWidth, scale: scale)
    }

    var body: some View {
        HStack(spacing: diameter * 0.035) {
            Image(systemName: "star.fill")
                .font(.system(size: diameter * 0.27, weight: .bold))
            Text(PosterBadgePills.ratingText(rating))
                .font(.system(size: diameter * 0.30, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundStyle(.white)
        .frame(width: diameter, height: diameter)
        .background(Color.Theme.scrim, in: Circle())
        .overlay(Circle().strokeBorder(Color.Theme.hairline, lineWidth: 1))
        .shadow(color: .black.opacity(0.45), radius: diameter * 0.12, y: diameter * 0.05)
        .accessibilityLabel(Text(RatingPickerSheet.label(rating)))
    }
}
