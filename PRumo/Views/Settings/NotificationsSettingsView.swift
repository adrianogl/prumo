import SwiftUI
import PRumoKit

struct NotificationsSettingsView: View {
    let store: NotificationPreferencesStore
    @State private var start = Date.now
    @State private var end = Date.now

    var body: some View {
        Form {
            Section {
                ForEach(NotificationToggle.allCases, id: \.self) { toggle in
                    Toggle(NotificationsSettingsText.title(toggle), isOn: binding(for: toggle))
                }
            }
            Section {
                Picker(NotificationsSettingsText.staleAfter, selection: staleHours) {
                    ForEach(staleOptions, id: \.self) { hours in
                        Text(NotificationsSettingsText.hours(hours)).tag(hours)
                    }
                }
                .disabled(store.preferences.disabled.contains(.staleReview))
                Toggle(NotificationsSettingsText.groupByPullRequest, isOn: groupByPullRequest)
            }
            Section {
                Toggle(NotificationsSettingsText.workingHoursOnly, isOn: workingHoursEnabled)
                if store.preferences.workingHours.enabled {
                    weekdayButtons
                    DatePicker(NotificationsSettingsText.from, selection: $start, displayedComponents: .hourAndMinute)
                    DatePicker(NotificationsSettingsText.to, selection: $end, displayedComponents: .hourAndMinute)
                    if !rangeIsValid {
                        Text(NotificationsSettingsText.invalidRange)
                            .font(.system(size: NotificationsSettingsMetrics.errorSize))
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: loadRange)
        .onChange(of: start) { commitRange() }
        .onChange(of: end) { commitRange() }
    }

    private var weekdayButtons: some View {
        HStack(spacing: NotificationsSettingsMetrics.weekdaySpacing) {
            ForEach(Array(NotificationsSettingsText.weekdayLetters.enumerated()), id: \.offset) { index, letter in
                let weekday = index + 1
                let selected = store.preferences.workingHours.weekdays.contains(weekday)
                Button {
                    toggleWeekday(weekday)
                } label: {
                    Text(letter)
                        .frame(
                            width: NotificationsSettingsMetrics.weekdayButtonSize,
                            height: NotificationsSettingsMetrics.weekdayButtonSize)
                        .background(selected ? Color.prumoCaramel : Color.clear, in: .circle)
                        .foregroundStyle(selected ? Color.white : Color.primary)
                        .overlay(Circle().strokeBorder(Color.secondary.opacity(selected ? 0 : 0.5)))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var staleOptions: [Int] {
        let current = store.preferences.staleReviewHours
        let options = NotificationsSettingsOptions.staleReviewHours
        return options.contains(current) ? options : (options + [current]).sorted()
    }

    private var rangeIsValid: Bool {
        minutes(of: start) < minutes(of: end)
    }

    private func binding(for toggle: NotificationToggle) -> Binding<Bool> {
        Binding(
            get: { !store.preferences.disabled.contains(toggle) },
            set: { isOn in
                if isOn {
                    store.preferences.disabled.remove(toggle)
                } else {
                    store.preferences.disabled.insert(toggle)
                }
            })
    }

    private var staleHours: Binding<Int> {
        Binding(
            get: { store.preferences.staleReviewHours },
            set: { store.preferences.staleReviewHours = $0 })
    }

    private var groupByPullRequest: Binding<Bool> {
        Binding(
            get: { store.preferences.groupByPullRequest },
            set: { store.preferences.groupByPullRequest = $0 })
    }

    private var workingHoursEnabled: Binding<Bool> {
        Binding(
            get: { store.preferences.workingHours.enabled },
            set: { store.preferences.workingHours.enabled = $0 })
    }

    private func toggleWeekday(_ weekday: Int) {
        if store.preferences.workingHours.weekdays.contains(weekday) {
            store.preferences.workingHours.weekdays.remove(weekday)
        } else {
            store.preferences.workingHours.weekdays.insert(weekday)
        }
    }

    private func loadRange() {
        let hours = store.preferences.workingHours
        start = date(forMinute: hours.startMinute)
        end = date(forMinute: hours.endMinute)
    }

    private func commitRange() {
        guard rangeIsValid else { return }
        let startMinute = minutes(of: start)
        let endMinute = minutes(of: end)
        let hours = store.preferences.workingHours
        guard hours.startMinute != startMinute || hours.endMinute != endMinute else { return }
        store.preferences.workingHours.startMinute = startMinute
        store.preferences.workingHours.endMinute = endMinute
    }

    private func minutes(of date: Date) -> Int {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * NotificationsSettingsMetrics.minutesPerHour + (parts.minute ?? 0)
    }

    private func date(forMinute minute: Int) -> Date {
        let perHour = NotificationsSettingsMetrics.minutesPerHour
        return Calendar.current.date(
            bySettingHour: minute / perHour, minute: minute % perHour, second: 0, of: .now) ?? .now
    }
}
