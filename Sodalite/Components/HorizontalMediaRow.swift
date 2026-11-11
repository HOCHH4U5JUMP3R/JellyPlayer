import SwiftUI

struct HorizontalMediaRow: View {
    let title: LocalizedStringKey
    /// Rendered verbatim instead of `title` for per-library rows whose heading is a runtime string, not a localization key.
    var verbatimTitle: String? = nil
    let items: [JellyfinItem]
    let imageURLProvider: (JellyfinItem) -> URL?
    /// Per-item fallback image tried when the primary fails (e.g. series Thumb to backdrop/still).
    var fallbackURLProvider: ((JellyfinItem) -> URL?)? = nil
    var onItemSelected: ((JellyfinItem) -> Void)?
    var cardStyle: MediaCardStyle = .poster
    /// Sodalite#66. The row paints show-level art rather than each item's own still, so the cards
    /// skip the spoiler blur (Continue Watching set to Backdrop or Thumb).
    var showsSeriesArtwork: Bool = false
    /// Optional focus binding used by detail pages to aim first entry and remember the last card.
    var focusedID: FocusState<String?>.Binding? = nil
    /// Overrides the default row inset. Pass 0 when this row is already inside an inset parent column.
    var inset: CGFloat? = nil

    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.shellPaysLeadingInset) private var shellPaysLeading
    private var metrics: LayoutMetrics { LayoutMetrics.current(hSizeClass) }
    private var rowInset: CGFloat { inset ?? metrics.rowInset }
    /// An explicit inset belongs to the host content column and therefore overrides both the
    /// tier default and the shell's usual leading inset. Without an override, preserve shell layout.
    private var leadingInset: CGFloat {
        if inset != nil { return rowInset }
        return shellPaysLeading ? metrics.rowLeading(shellPaysLeading: true) : rowInset
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Group {
                if let verbatimTitle {
                    Text(verbatimTitle)
                } else {
                    Text(title)
                }
            }
            .font(.title3)
            .fontWeight(.semibold)
            .padding(.leading, leadingInset)
            .padding(.trailing, rowInset)

            RowScrollView(leading: leadingInset, trailing: rowInset,
                          vertical: metrics.rowVerticalPadding) {
                LazyHStack(spacing: metrics.itemSpacing) {
                    ForEach(items) { item in
                        FocusableCard(
                            action: { onItemSelected?(item) },
                            externalFocus: focusedID,
                            focusID: item.id
                        ) { isFocused in
                            MediaCard(
                                item: item,
                                imageURL: imageURLProvider(item),
                                fallbackURL: fallbackURLProvider?(item),
                                style: cardStyle,
                                isFocused: isFocused,
                                showsSeriesArtwork: showsSeriesArtwork
                            )
                        }
                    }
                }
            }
            // A row is its own focus section so vertical navigation can reach it from any column (#80).
            .focusSectionCompat()
            .enrichesPosterBadges(items)
        }
    }
}
