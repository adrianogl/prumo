import SwiftUI
import PRumoKit

struct DoNotDisturbButton: View {
    let store: NotificationPreferencesStore

    var body: some View {
        Menu {
            Button(PopoverText.dndOneHour) { set(.oneHour(from: .now)) }
            Button(PopoverText.dndUntilTomorrow) { set(.untilTomorrowMorning(from: .now, calendar: .current)) }
            Button(PopoverText.dndIndefinite) { set(.indefinite) }
            if store.preferences.dnd.isActive(at: .now) {
                Divider()
                Button(PopoverText.dndReactivate) { set(.off) }
            }
        } label: {
            icon
                .frame(width: PopoverMetrics.dndFrameSize, height: PopoverMetrics.dndFrameSize)
                .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .foregroundStyle(store.isQuiet ? Color.prumoCaramel : Color.secondary)
        .help(tooltip)
        .accessibilityLabel(PopoverText.dnd)
    }

    private var icon: some View {
        Image(systemName: PopoverSymbol.dndBell)
            .font(.system(size: PopoverMetrics.dndIconSize))
            .overlay(alignment: .topTrailing) {
                Image(systemName: PopoverSymbol.dndSleep)
                    .font(.system(size: PopoverMetrics.dndSleepSize, weight: .bold))
                    .offset(x: PopoverMetrics.dndSleepOffsetX, y: PopoverMetrics.dndSleepOffsetY)
            }
    }

    private func set(_ value: DoNotDisturb) {
        store.preferences.dnd = value
        store.refreshQuiet(now: .now)
    }

    private var tooltip: String {
        let now = Date.now
        switch store.preferences.dnd {
        case .indefinite:
            return PopoverText.dndUntilIndefinite
        case .until(let end) where end > now:
            let time = end.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
            return Calendar.current.isDate(end, inSameDayAs: now)
                ? PopoverText.dndUntil(time: time)
                : PopoverText.dndUntilTomorrow(time: time)
        default:
            return store.isQuiet ? PopoverText.outsideWorkingHours : PopoverText.dnd
        }
    }
}
