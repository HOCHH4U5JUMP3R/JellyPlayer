import SwiftUI

/// Poster-corner rating and technical badges. The personal score is a circle matching the watched
/// mark; technical pills remain stacked below it.
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

        if let rating {
            VStack(alignment: .leading, spacing: fontSize * 0.2) {
                PosterRatingBadge(rating: rating, posterWidth: posterWidth, scale: scale)
                if !pills.isEmpty {
                    PosterBadgePills(pills: pills, fontSize: fontSize)
                }
            }
            .padding(PosterBadgeMetrics.checkInset(posterWidth: posterWidth, scale: scale))
        } else if !pills.isEmpty {
            PosterBadgePills(pills: pills, fontSize: fontSize)
        }
    }
}

/// Shared rating mark for movie/series posters, season covers and episode artwork.
struct PosterRatingBadge: View {
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
