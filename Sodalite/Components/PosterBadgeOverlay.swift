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
