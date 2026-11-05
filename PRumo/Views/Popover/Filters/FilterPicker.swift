import SwiftUI
import PRumoKit
import enum PRumoKit.CIFilter

struct FilterPicker: View {
    let organization: OrganizationStore
    let snapshot: Snapshot?
    let tab: ListTab
    @State private var personSearch = ""

    private var filter: RowFilter { organization.settings.filter }

    private var authors: [String] {
        guard let snapshot else { return [] }
        var seen = Set<String>()
        let query = personSearch.trimmingCharacters(in: .whitespaces)
        return (snapshot.mine + snapshot.toReview)
            .map(\.author)
            .filter { $0.caseInsensitiveCompare(snapshot.viewer) != .orderedSame }
            .filter { seen.insert($0.lowercased()).inserted }
            .filter { query.isEmpty || $0.localizedCaseInsensitiveContains(query) }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if !organization.settings.views.isEmpty { views }
                    group(FiltersText.ciTitle) {
                        ForEach(CIFilter.allCases, id: \.self) { value in
                            chip(FiltersText.label(value), isOn: filter.ci.contains(value)) {
                                organization.settings.filter.ci.formSymmetricDifference([value])
                            }
                        }
                    }
                    group(FiltersText.reviewTitle) {
                        ForEach(ReviewFilter.allCases, id: \.self) { value in
                            chip(FiltersText.label(value), isOn: filter.review.contains(value)) {
                                organization.settings.filter.review.formSymmetricDifference([value])
                            }
                        }
                    }
                    group(FiltersText.stateTitle) {
                        ForEach(StateFilter.allCases, id: \.self) { value in
                            chip(FiltersText.label(value), isOn: filter.state.contains(value)) {
                                organization.settings.filter.state.formSymmetricDifference([value])
                            }
                        }
                    }
                    if tab == .review {
                        group(FiltersText.requestTitle) {
                            ForEach(RequestFilter.allCases, id: \.self) { value in
                                chip(
                                    FiltersText.label(value, staleHours: FiltersDefaults.staleHours),
                                    isOn: filter.request.contains(value)
                                ) {
                                    organization.settings.filter.request.formSymmetricDifference([value])
                                }
                            }
                        }
                    }
                    PickerGroupTitle(title: FiltersText.authorTitle)
                    PickerSearchField(prompt: FiltersText.searchPerson, text: $personSearch)
                        .padding(.bottom, FiltersMetrics.searchBottomPadding)
                    chipFlow {
                        ForEach(authors, id: \.self) { login in
                            chip(login, isOn: isSelected(author: login)) { toggle(author: login) }
                        }
                    }
                }
            }
            .frame(maxHeight: FiltersMetrics.pickerListMaxHeight)
            .fixedSize(horizontal: false, vertical: true)
            Divider()
                .padding(.top, FiltersMetrics.footerDividerTopPadding)
                .padding(.bottom, FiltersMetrics.footerDividerBottomPadding)
            SaveViewRow(organization: organization)
        }
        .padding(FiltersMetrics.pickerPadding)
        .frame(width: FiltersMetrics.pickerWidth)
    }

    private var views: some View {
        VStack(alignment: .leading, spacing: 0) {
            PickerGroupTitle(title: FiltersText.viewsTitle)
            chipFlow {
                ForEach(organization.settings.views) { view in
                    chip(view.name, isOn: view.filter == filter) {
                        organization.settings.filter = view.filter
                    }
                }
            }
        }
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            PickerGroupTitle(title: title)
            chipFlow(content: content)
        }
    }

    private func chipFlow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        FlowLayout(spacing: FiltersMetrics.chipSpacing, lineSpacing: FiltersMetrics.chipLineSpacing) {
            content()
        }
        .padding(.horizontal, FiltersMetrics.chipFlowHorizontalPadding)
    }

    private func chip(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        PickerToggleChip(title: title, isOn: isOn, action: action)
    }

    private func isSelected(author login: String) -> Bool {
        filter.authors.contains { $0.caseInsensitiveCompare(login) == .orderedSame }
    }

    private func toggle(author login: String) {
        let matches = organization.settings.filter.authors.filter { $0.caseInsensitiveCompare(login) == .orderedSame }
        if matches.isEmpty {
            organization.settings.filter.authors.insert(login)
        } else {
            organization.settings.filter.authors.subtract(matches)
        }
    }
}
