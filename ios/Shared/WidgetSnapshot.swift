import Foundation

/// Wat de widget toont. De app schrijft dit weg in de App Group; de widget
/// leest het alleen.
struct WidgetSnapshot: Codable, Equatable {
    var reclaimedThisYearCents = 0
    var year = 0
    /// Aantal aankopen met een bevestigde prijsdaling.
    var dropCount = 0
    var watchedCount = 0
    /// Eerstvolgende retourtermijn die afloopt.
    var nextDeadlineTitle: String?
    var nextDeadline: Date?

    static let groupIdentifier = "group.nl.prijswacht.app"
    private static let key = "widgetSnapshot"

    static func load() -> WidgetSnapshot {
        guard let data = UserDefaults(suiteName: groupIdentifier)?.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else { return WidgetSnapshot() }
        return snapshot
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults(suiteName: Self.groupIdentifier)?.set(data, forKey: Self.key)
    }
}
