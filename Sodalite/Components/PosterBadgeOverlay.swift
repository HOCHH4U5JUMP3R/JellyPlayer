import SwiftUI

/// Shared personal-rating mark for poster and season artwork.
struct PersonalRatingMark: View {
    let rating: Int
    let fontSize: CGFloat
    let accessibilityLabel: String
    var inset: CGFloat = 0

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "star.fill")
            Text("\(rating)")
        }
        .font(.system(size: fontSize, weight: .semibold))
        .foregroundStyle(.white)
        .padding(inset)
        .accessibilityLabel(accessibilityLabel)
    }
}

/// The pills in a card's top-left corner (Sodalite#79).
///
/// A leaf on purpose: it, not `MediaCard`, reads the badge store, so a batch of enrichment landing
/// invalidates the overlays and not the two hundred cards around them. The top right belongs to the
/// watched checkmark and the bottom edge to the resume bar, so the corner is free.
struct PosterBadgeOverlay: View {
    let item: JellyfinItem
    let fontSize: CGFloat

    @Environment(\.dependencies) private var dependencies

    var body: some View {
        let appearance = dependencies.appearancePreferences
        let pills = appearance.showPosterBadges ? dependencies.posterBadgeStore.badges(for: item).pills : []
        let personalRating: Int? = {
            guard appearance.showPosterRating else { return nil }
            if item.type == .series {
                return item.userData?.rating.map { Int($0.rounded()) }
                    ?? dependencies.posterBadgeStore.personalSeriesRating(for: item)
            }
            return item.userData?.rating.map { Int($0.rounded()) }
        }()
        if !pills.isEmpty || personalRating != nil {
            VStack(alignment: .leading, spacing: 4) {
                if !pills.isEmpty {
                    PosterBadgePills(pills: pills, fontSize: fontSize)
                }
                if let personalRating {
                    PersonalRatingMark(
                        rating: personalRating,
                        fontSize: fontSize * (0.13 / 0.06) * 0.90,
                        accessibilityLabel: "Meine Bewertung \(personalRating) von 10"
                    )
                }
            }
        }
    }
}
