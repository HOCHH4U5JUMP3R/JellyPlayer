import SwiftUI

struct SeerrHorizontalMediaRow: View {
    let title: LocalizedStringKey
    var titleFont: Font = .title3
    let items: [SeerrMedia]
    var isLoadingMore: Bool = false
    var onItemSelected: ((SeerrMedia) -> Void)?
    var onNeedsMore: (() -> Void)?
    /// Optional host-controlled focus target for detail-page navigation.
    var focusedID: FocusState<String?>.Binding? = nil

    // Paginate a few items before the end so new cards land before focus reaches them.
    private let prefetchThreshold = 5

    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.shellPaysLeadingInset) private var shellPaysLeading
    private var metrics: LayoutMetrics { LayoutMetrics.current(hSizeClass) }
    private var leadingInset: CGFloat { metrics.rowLeading(shellPaysLeading: shellPaysLeading) }

    @ViewBuilder
    private func bindingFocus<Content: View>(_ card: Content, to id: String) -> some View {
        if let focusedID {
            card.focused(focusedID, equals: id)
        } else {
            card
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(titleFont)
                .fontWeight(.semibold)
                .padding(.leading, leadingInset)
                .padding(.trailing, metrics.rowInset)

            RowScrollView(leading: leadingInset, trailing: metrics.rowInset,
                          vertical: metrics.rowVerticalPadding) {
                LazyHStack(spacing: metrics.itemSpacing) {
                    // stableKey not id: TMDB ids collide across movie/tv (trending mixes both); duplicate ForEach ids cause ghost cards and focus jumps.
                    ForEach(Array(items.enumerated()), id: \.element.stableKey) { index, media in
                        bindingFocus(
                            FocusableCard {
                                onItemSelected?(media)
                            } content: { isFocused in
                                SeerrMediaCard(media: media, isFocused: isFocused)
                            },
                            to: media.stableKey
                        )
                        .onAppear {
                            if index >= items.count - prefetchThreshold {
                                onNeedsMore?()
                            }
                        }
                    }

                    if isLoadingMore {
                        ProgressView()
                            .frame(width: metrics.posterSize.width, height: metrics.posterSize.height)
                    }
                }
            }
            .focusSectionCompat()
        }
    }
}
