import Foundation
import Observation
import PRumoKit

@Observable @MainActor
final class NotificationPreferencesStore {
    var preferences: NotificationPreferences {
        didSet { persist() }
    }
    private(set) var isQuiet = false

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        preferences = defaults.data(forKey: AppConstants.notificationPreferencesKey)
            .flatMap { try? Self.decoder.decode(NotificationPreferences.self, from: $0) } ?? NotificationPreferences()
        refreshQuiet(now: .now)
    }

    func refreshQuiet(now: Date) {
        let normalized = preferences.dnd.normalized(at: now)
        if normalized != preferences.dnd {
            preferences.dnd = normalized
        }
        let quiet = QuietPolicy.isQuiet(
            now: now, dnd: preferences.dnd, hours: preferences.workingHours, calendar: .current)
        if quiet != isQuiet {
            isQuiet = quiet
        }
    }

    private func persist() {
        guard let data = try? Self.encoder.encode(preferences) else { return }
        defaults.set(data, forKey: AppConstants.notificationPreferencesKey)
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .deferredToDate
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .deferredToDate
        return decoder
    }
}
