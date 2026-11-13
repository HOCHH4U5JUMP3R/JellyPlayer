import SwiftUI

/// The viewer's own rating and technical pills, in the same top-right corner as the watched mark.
/// The score keeps the original dark capsule treatment; only its placement follows the state badge.
struct PosterBadgeOverlay: View {
    let item: JellyfinItem
    let fontSize: CGFloat
    let posterWidth: CGFloat
    let scale: CGFloat

    @Environment(\.dependencies) private var dependencies
    @Environment(\.appState) private var appState

    var body: some View {
        let appearance = dependencies.appearancePreferences
        let pills = appearance.showPosterBadges ? dependencies.posterBadgeStore.badges(for: item).pills : []
        let rating = appearance.showPosterRating
            ? dependencies.posterBadgeStore.rating(for: item, userID: appState.activeUser?.id)
            : nil

        if !pills.isEmpty || rating != nil {
            PosterBadgePills(pills: pills, fontSize: fontSize, rating: rating)
                .padding(PosterBadgeMetrics.checkInset(posterWidth: posterWidth, scale: scale))
        }
    }
}


/// Compact personal-rating capsule for episode and season artwork.
/// It occupies the top-left corner; the watched/favourite mark stays independently top-right.
struct PosterRatingBadge: View {
    let rating: Double
    let posterWidth: CGFloat
    let scale: CGFloat

    private var fontSize: CGFloat {
        PosterBadgeMetrics.fontSize(posterWidth: posterWidth, scale: scale)
    }

    var body: some View {
        HStack(spacing: fontSize * 0.28) {
            Image(systemName: "star.fill")
                .foregroundStyle(.yellow)
            Text(PosterBadgePills.ratingText(rating))
                .monospacedDigit()
        }
        .font(.system(size: fontSize, weight: .semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, fontSize * PosterBadgeMetrics.pillHorizontalPadding)
        .padding(.vertical, fontSize * PosterBadgeMetrics.pillVerticalPadding)
        .background(Color.Theme.scrim, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.Theme.hairline, lineWidth: 1))
        .fixedSize()
        .accessibilityLabel(Text(RatingPickerSheet.label(rating)))
    }
}
