import SwiftUI

struct SearchField: View {
    @Binding var text: String
    var focus: FocusState<PopoverFocus?>.Binding
    @State private var selection: TextSelection?

    var body: some View {
        HStack(spacing: PopoverMetrics.searchSpacing) {
            Image(systemName: PopoverSymbol.search)
                .foregroundStyle(.secondary)
            TextField(PopoverText.searchPlaceholder, text: $text, selection: $selection)
                .textFieldStyle(.plain)
                .focused(focus, equals: .search)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: PopoverSymbol.clearSearch)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel(PopoverText.clearSearch)
            }
        }
        .font(.system(size: 12))
        .padding(.horizontal, 8)
        .padding(.vertical, PopoverMetrics.searchVerticalPadding)
        .background(Color.prumoBadgeBackground, in: RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .onChange(of: focus.wrappedValue) { _, newFocus in
            guard newFocus == .search else { return }
            selection = TextSelection(insertionPoint: text.endIndex)
        }
    }
}
