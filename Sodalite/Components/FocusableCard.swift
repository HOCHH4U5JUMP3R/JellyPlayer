import SwiftUI

/// Focusable card avoiding tvOS's default white focus border; use instead of Button for media cards and settings tiles.
struct FocusableCard<Content: View>: View {
    let action: () -> Void
    var highlightsOnPress = false
    var exposesButtonSemantics = false
    /// Optional parent-owned focus memory for rows that restore a specific card.
    var externalFocus: FocusState<String?>.Binding? = nil
    var focusID: String? = nil
    @ViewBuilder let content: (_ isFocused: Bool) -> Content

    @FocusState private var isFocused: Bool
    @GestureState private var isPressed = false

    @ViewBuilder
    var body: some View {
        if exposesButtonSemantics {
            pressAwareCard
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { action() }
        } else {
            pressAwareCard
        }
    }

    @ViewBuilder
    private var baseCard: some View {
        if let externalFocus, let focusID {
            content(isHighlighted)
                .focusable()
                .focused($isFocused)
                .focused(externalFocus, equals: focusID)
                .stableTap(isFocused: isFocused) { action() }
                .focusResponse(.card, isFocused: isHighlighted)
        } else {
            content(isHighlighted)
                .focusable()
                .focused($isFocused)
                .stableTap(isFocused: isFocused) { action() }
                .focusResponse(.card, isFocused: isHighlighted)
        }
    }

    @ViewBuilder
    private var pressAwareCard: some View {
        #if os(iOS)
        if highlightsOnPress {
            baseCard.simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .updating($isPressed) { value, pressed, _ in
                        pressed = abs(value.translation.width) <= 24
                            && abs(value.translation.height) <= 24
                    }
            )
        } else {
            baseCard
        }
        #else
        baseCard
        #endif
    }

    private var isHighlighted: Bool {
        #if os(iOS)
        isFocused || (highlightsOnPress && isPressed)
        #else
        isFocused
        #endif
    }
}
