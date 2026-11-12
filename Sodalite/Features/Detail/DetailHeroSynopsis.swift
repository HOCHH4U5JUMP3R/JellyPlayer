import SwiftUI

/// The synopsis teaser inside the first viewport's panel (Sodalite#146).
///
/// The plot used to be the first child BELOW the fold, so the page a viewer met carried the studio
/// and little else of substance. Three lines up here answer "what is this" before the first scroll;
/// the full text stays reachable below.
///
/// The height is reserved rather than measured, and that is the point of the component. The panel
/// sits in a bottom-aligned, viewport-tall first page, so a block that grows when the detail fetch
/// lands pushes the button row down after first paint (Sodalite#15), and a panel whose height
/// varies within one mode lands the page at a different scroll offset every time it is opened
/// (the episode-vs-series case). A fixed line count with `reservesSpace` removes both.
struct DetailHeroSynopsis: View {
    let text: String?
    /// Whether the fetch that could still deliver an overview is in flight. Only then is empty
    /// space held: a title that settles without a synopsis collapses the block instead of keeping
    /// three blank lines, the same rule `DetailInfoRows` applies to its skeletons.
    var isPending: Bool = false
    /// Sodalite#50. The teaser is veiled by exactly the same rule as the box below the fold, or a
    /// hidden episode synopsis would simply be printed one screen higher.
    var spoilerItem: JellyfinItem?
    /// What a tap on the teaser does on touch: the page's More Details action, so the truncated
    /// text is not a dead end. tvOS leaves the panel outside the focus engine and ignores it.
    var onTap: (() -> Void)?
    /// Shared page focus state: the synopsis has its own identity, so moving down can
    /// assign the exact destination without letting tvOS choose a geometric neighbour.
    var focusedAction: FocusState<DetailAction?>.Binding? = nil
    /// Explicit fallback for callers that do not share the page's action focus state.
    var onMoveDown: (() -> Void)?
    /// The upright iPhone's placement under the action row (Blexbi): the page scrolls freely there,
    /// so a tap opens the whole text in place instead of leaving for More Details. The reserved
    /// lines still hold while it is closed, which is what keeps the buttons above it still.
    var expandsInPlace = false

    @State private var isExpanded = false
    @Environment(\.verticalSizeClass) private var vSizeClass
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.dependencies) private var dependencies
    @Environment(\.appState) private var appState
    @Environment(\.isFocused) private var isFocused

    /// Two lines in a short viewport (iPhone landscape), where the first page is not viewport-locked
    /// and every added line pushes the action row further past the fold, and in the upright
    /// iPhone's column, which shares its first screen with the poster. The rest is behind the info
    /// button.
    private var lineCount: Int {
        vSizeClass == .compact || hSizeClass == .compact ? 2 : 3
    }

    private var isSpoilerHidden: Bool {
        guard let spoilerItem else { return false }
        return SpoilerReveal.isHidden(spoilerItem, dependencies: dependencies, appState: appState)
    }

    @ViewBuilder
    private var synopsisText: some View {
        if let text, !text.isEmpty {
            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineLimit(isExpanded ? .max : lineCount, reservesSpace: !isExpanded)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .spoilerVeil(isHidden: isSpoilerHidden, style: .text)
                .onChange(of: text) { isExpanded = false }
                .onChange(of: isSpoilerHidden) { if $1 { isExpanded = false } }
        } else {
            Text(verbatim: " ")
                .font(.body)
                .lineLimit(lineCount, reservesSpace: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    var body: some View {
        #if os(tvOS)
        synopsisText
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .contentShape(RoundedRectangle(cornerRadius: 13))
            // Match the secondary action buttons' quiet focus fill without turning the
            // synopsis into a Button (which reintroduced the bright system hover plate).
            .background {
                RoundedRectangle(cornerRadius: 13)
                    .fill(Color.white.opacity(isFocused ? 0.28 : 0.10))
                    .animation(.easeOut(duration: 0.12), value: isFocused)
            }
            .focusable()
            .focusEffectDisabled(true)
            .focused(focusedAction ?? .init(get: { nil }, set: { _ in }), equals: .synopsis)
            .onTapGesture { onTap?() }
            .onMoveCommand { direction in
                guard direction == .down else { return }
                if let focusedAction {
                    focusedAction.wrappedValue = .watched
                } else {
                    onMoveDown?()
                }
            }
        #else
        synopsisText
            .contentShape(Rectangle())
            .onTapGesture {
                if expandsInPlace, !isSpoilerHidden {
                    withAnimation(.easeInOut(duration: 0.25)) { isExpanded.toggle() }
                } else {
                    onTap?()
                }
            }
        #endif
    }
}
