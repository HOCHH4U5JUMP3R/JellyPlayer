import Foundation

/// Scrob-compatible aggregation for series ratings, which Jellyfin does not calculate for us.
enum PosterRatingCalculator {
    /// Unrated episodes/seasons are omitted from their respective averages.
    static func roundedAverage(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return (values.reduce(0, +) / Double(values.count)).rounded()
    }

    /// A series score is the average of its rounded season scores, not a flat average of every episode.
    static func seriesRating(episodes: [JellyfinItem]) -> Double? {
        let ratedBySeason = Dictionary(grouping: episodes.compactMap { episode -> (Int, Double)? in
            guard let season = episode.parentIndexNumber,
                  let rating = episode.userData?.rating else { return nil }
            return (season, rating)
        }, by: { $0.0 })

        let seasonRatings = ratedBySeason.values.compactMap { values in
            roundedAverage(values.map { $0.1 })
        }
        return roundedAverage(seasonRatings)
    }
}
