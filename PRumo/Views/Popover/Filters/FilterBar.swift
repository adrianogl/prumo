import SwiftUI
import PRumoKit

struct FilterBar: View {
    let organization: OrganizationStore
    let snapshot: Snapshot?
    let tab: ListTab
    @State private var showsRepositories = false
    @State private var showsFilters = false
    @State private var showsOrder = false
    @Binding var isPresentingPicker: Bool

    private var settings: OrganizationSettings { organization.settings }

    private var orderTitle: String {
        let ordering = settings.ordering(for: tab)
        return ordering.groupByRepository ? FiltersText.groupedByRepository : FiltersText.label(ordering.order)
    }

    private var isPickerOpen: Bool {
        showsRepositories || showsFilters || showsOrder
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FiltersMetrics.barSpacing) {
            HStack(spacing: FiltersMetrics.barSpacing) {
                barButton(
                    FiltersText.withCount(FiltersText.repositories, count: settings.filter.repositories.count),
                    isPresented: $showsRepositories
                ) {
                    RepositoryPicker(organization: organization, snapshot: snapshot)
                }
                barButton(
                    FiltersText.withCount(FiltersText.filters, count: settings.filter.criteriaCount),
                    isPresented: $showsFilters
                ) {
                    FilterPicker(organization: organization, snapshot: snapshot, tab: tab)
                }
                Spacer(minLength: 0)
                barButton(orderTitle, symbol: FiltersSymbol.order, isPresented: $showsOrder) {
                    OrderPicker(organization: organization, tab: tab)
                }
            }
            FilterChipsView(organization: organization)
        }
        .padding(.horizontal, FiltersMetrics.barHorizontalPadding)
        .padding(.bottom, FiltersMetrics.barBottomPadding)
        .onChange(of: isPickerOpen) { _, isOpen in
            isPresentingPicker = isOpen
        }
    }

    private func barButton<Content: View>(
        _ title: String,
        symbol: String? = nil,
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        Button {
            isPresented.wrappedValue.toggle()
        } label: {
            HStack(spacing: FiltersMetrics.barButtonContentSpacing) {
                if let symbol {
                    Image(systemName: symbol)
                }
                Text(title)
                    .lineLimit(1)
                Image(systemName: FiltersSymbol.chevron)
                    .font(.system(size: FiltersMetrics.chevronSize, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .fixedSize()
            .font(.system(size: FiltersMetrics.barButtonFontSize, weight: .medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, FiltersMetrics.barButtonHorizontalPadding)
            .padding(.vertical, FiltersMetrics.barButtonVerticalPadding)
            .background(Color.prumoBadgeBackground, in: RoundedRectangle(cornerRadius: FiltersMetrics.barButtonCornerRadius))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: isPresented, arrowEdge: .bottom, content: content)
    }
}
