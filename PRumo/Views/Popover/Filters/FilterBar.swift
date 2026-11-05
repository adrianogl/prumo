import SwiftUI
import PRumoKit

struct FilterBar: View {
    let organization: OrganizationStore
    let snapshot: Snapshot?
    let tab: ListTab
    @State private var showsRepositories = false
    @State private var showsFilters = false
    @State private var showsOrder = false
    @State private var isSavingView = false
    @State private var viewName = ""

    private var settings: OrganizationSettings { organization.settings }

    private var orderTitle: String {
        let ordering = settings.ordering(for: tab)
        return ordering.groupByRepository ? FiltersText.groupedByRepository : FiltersText.label(ordering.order)
    }

    private var trimmedViewName: String {
        viewName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FiltersMetrics.barSpacing) {
            HStack(spacing: FiltersMetrics.barSpacing) {
                barButton(
                    FiltersText.withCount(FiltersText.repositories, count: settings.filter.repositories.count),
                    isPresented: $showsRepositories
                ) {
                    RepositoryPicker(organization: organization, snapshot: snapshot) {
                        startSavingView { showsRepositories = false }
                    }
                }
                barButton(
                    FiltersText.withCount(FiltersText.filters, count: settings.filter.criteriaCount),
                    isPresented: $showsFilters
                ) {
                    FilterPicker(organization: organization, snapshot: snapshot) {
                        startSavingView { showsFilters = false }
                    }
                }
                Spacer(minLength: 0)
                barButton(orderTitle, symbol: FiltersSymbol.order, isPresented: $showsOrder) {
                    OrderPicker(organization: organization, tab: tab)
                }
            }
            FilterChipsView(organization: organization)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .alert(FiltersText.saveViewTitle, isPresented: $isSavingView) {
            TextField(FiltersText.viewName, text: $viewName)
            Button(FiltersText.save, action: saveView)
                .disabled(trimmedViewName.isEmpty)
            Button(FiltersText.cancel, role: .cancel) {}
        }
    }

    private func startSavingView(closing close: () -> Void) {
        close()
        viewName = ""
        Task { isSavingView = true }
    }

    private func saveView() {
        let name = trimmedViewName
        guard !name.isEmpty else { return }
        organization.settings.views.append(SavedView(name: name, filter: organization.settings.filter))
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
            HStack(spacing: 4) {
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
