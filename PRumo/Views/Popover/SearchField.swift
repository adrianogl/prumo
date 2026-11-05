import SwiftUI

struct SearchField: View {
    @Binding var text: String
    var focus: FocusState<PopoverFocus?>.Binding

    var body: some View {
        HStack(spacing: PopoverMetrics.searchSpacing) {
            Image(systemName: PopoverSymbol.search)
                .foregroundStyle(.secondary)
            TextField(PopoverText.searchPlaceholder, text: $text)
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
    }
}
