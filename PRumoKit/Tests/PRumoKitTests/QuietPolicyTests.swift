import Foundation
import Testing
@testable import PRumoKit

struct QuietPolicyTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        return calendar
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    private var enabledHours: WorkingHours { WorkingHours(enabled: true) }

    @Test func oneHourEndsSixtyMinutesLater() {
        let now = date(2026, 11, 5, 10)
        #expect(DoNotDisturb.oneHour(from: now) == .until(date(2026, 11, 5, 11)))
    }

    @Test func untilTomorrowIsNextCalendarDayNineAM() {
        #expect(DoNotDisturb.untilTomorrowMorning(from: date(2026, 11, 5, 23, 30), calendar: calendar) == .until(date(2026, 11, 6, 9)))
        #expect(DoNotDisturb.untilTomorrowMorning(from: date(2026, 11, 6, 0, 30), calendar: calendar) == .until(date(2026, 11, 7, 9)))
    }

    @Test func expiredUntilIsInactiveAndNormalizesToOff() {
        let end = date(2026, 11, 5, 11)
        let dnd = DoNotDisturb.until(end)
        #expect(dnd.isActive(at: date(2026, 11, 5, 10, 59)))
        #expect(!dnd.isActive(at: end))
        #expect(dnd.normalized(at: end) == .off)
        #expect(dnd.normalized(at: date(2026, 11, 5, 10)) == dnd)
    }

    @Test func indefiniteStaysActive() {
        let dnd = DoNotDisturb.indefinite
        #expect(dnd.isActive(at: date(2030, 1, 1, 0)))
        #expect(dnd.normalized(at: date(2030, 1, 1, 0)) == .indefinite)
    }

    @Test func insideWorkingHoursIsNotQuiet() {
        #expect(!QuietPolicy.isQuiet(now: date(2026, 11, 5, 10), dnd: .off, hours: enabledHours, calendar: calendar))
    }

    @Test func endIsExclusive() {
        #expect(QuietPolicy.isQuiet(now: date(2026, 11, 5, 18), dnd: .off, hours: enabledHours, calendar: calendar))
        #expect(!QuietPolicy.isQuiet(now: date(2026, 11, 5, 17, 59), dnd: .off, hours: enabledHours, calendar: calendar))
    }

    @Test func weekendIsQuiet() {
        #expect(QuietPolicy.isQuiet(now: date(2026, 11, 7, 10), dnd: .off, hours: enabledHours, calendar: calendar))
    }

    @Test func disabledWorkingHoursNeverQuiet() {
        #expect(!QuietPolicy.isQuiet(now: date(2026, 11, 7, 3), dnd: .off, hours: WorkingHours(), calendar: calendar))
    }

    @Test func doNotDisturbSilencesInsideWorkingHours() {
        #expect(QuietPolicy.isQuiet(now: date(2026, 11, 5, 10), dnd: .indefinite, hours: enabledHours, calendar: calendar))
    }

    @Test func invalidRangeTreatedAsAlwaysInside() {
        let hours = WorkingHours(enabled: true, startMinute: 1080, endMinute: 540)
        #expect(!hours.isValid)
        #expect(hours.contains(date(2026, 11, 7, 3), calendar: calendar))
        #expect(!QuietPolicy.isQuiet(now: date(2026, 11, 7, 3), dnd: .off, hours: hours, calendar: calendar))
    }

    @Test func roundTripCodable() throws {
        let hours = WorkingHours(enabled: true, weekdays: [2, 4], startMinute: 480, endMinute: 1020)
        for dnd in [DoNotDisturb.off, .indefinite, .until(date(2026, 11, 6, 9))] {
            let data = try JSONEncoder().encode(dnd)
            #expect(try JSONDecoder().decode(DoNotDisturb.self, from: data) == dnd)
        }
        let data = try JSONEncoder().encode(hours)
        #expect(try JSONDecoder().decode(WorkingHours.self, from: data) == hours)
    }

    @Test func decodesOldOrPartialData() throws {
        let empty = try JSONDecoder().decode(WorkingHours.self, from: Data("{}".utf8))
        #expect(empty == WorkingHours())
        let partial = try JSONDecoder().decode(WorkingHours.self, from: Data(#"{"enabled":true,"startMinute":"x"}"#.utf8))
        #expect(partial == WorkingHours(enabled: true))
        let unknown = try JSONDecoder().decode(DoNotDisturb.self, from: Data(#"{"kind":"weird"}"#.utf8))
        #expect(unknown == .off)
        let broken = try JSONDecoder().decode(DoNotDisturb.self, from: Data(#"{"kind":"until"}"#.utf8))
        #expect(broken == .off)
    }

    @Test func startIsInclusive() {
        #expect(enabledHours.contains(date(2026, 11, 9, 9), calendar: calendar))
        #expect(!enabledHours.contains(date(2026, 11, 9, 8, 59), calendar: calendar))
    }

    @Test func weekdayRuleIgnoresFirstWeekday() {
        var mondayFirst = calendar
        mondayFirst.firstWeekday = 2
        #expect(enabledHours.contains(date(2026, 11, 9, 10), calendar: mondayFirst))
        #expect(!enabledHours.contains(date(2026, 11, 8, 10), calendar: mondayFirst))
    }

    @Test func nonObjectJSONDecodesDoNotDisturbAsOff() throws {
        #expect(try JSONDecoder().decode(DoNotDisturb.self, from: Data(#""x""#.utf8)) == .off)
        #expect(try JSONDecoder().decode(DoNotDisturb.self, from: Data("42".utf8)) == .off)
    }
}
