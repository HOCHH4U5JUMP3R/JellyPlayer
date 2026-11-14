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
            // PosterBadgePills supplies its own optical inset. Adding the watched-check inset here
            // stacked two transparent margins and pushed the rating noticeably farther inward.
            // Keep the visible capsule on the same corner line as the state badge.
            PosterBadgePills(pills: pills, fontSize: fontSize, rating: rating)
        }
    }
}


/// Shared personal-rating capsule for posters, season covers and episode artwork.
/// It occupies the top-left corner; the watched/favourite mark stays independently top-right.
struct PosterRatingBadge: View {
    let rating: Double
    let posterWidth: CGFloat
    let scale: CGFloat

    private var fontSize: CGFloat {
        PosterBadgeMetrics.fontSize(posterWidth: posterWidth, scale: scale)
    }

    var body: some View {
        PosterBadgePills(pills: [], fontSize: fontSize, rating: rating)
            .fixedSize()
            .accessibilityLabel(Text(RatingPickerSheet.label(rating)))
    }
}
