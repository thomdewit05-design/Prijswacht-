import Foundation
import SwiftData

/// Opslag die de app en de delen-extensie delen via een App Group.
enum AppGroup {
    static let identifier = "group.nl.prijswacht.app"

    static let defaults: UserDefaults = UserDefaults(suiteName: identifier) ?? .standard

    @MainActor
    static let container: ModelContainer = {
        let schema = Schema([Purchase.self, Outcome.self])
        let grouped = ModelConfiguration(schema: schema, groupContainer: .identifier(identifier))
        if let container = try? ModelContainer(for: schema, configurations: [grouped]) {
            return container
        }
        // Zonder App Group (bijvoorbeeld in previews of zonder ondertekening)
        // valt de app terug op eigen opslag; de extensie deelt dan niet mee.
        if let container = try? ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema)]) {
            return container
        }
        let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        // Laatste redmiddel; mislukt alleen bij een kapot schema.
        return try! ModelContainer(for: schema, configurations: [memory])
    }()
}

/// Instellingen die app en extensie allebei lezen.
enum AppSettings {
    static let thresholdKey = "thresholdCents"
    static let onboardedKey = "hasOnboarded"
    static let plusKey = "isPlus"
    static let defaultThresholdCents = 1000

    static var thresholdCents: Int {
        let stored = AppGroup.defaults.integer(forKey: thresholdKey)
        return stored > 0 ? stored : defaultThresholdCents
    }

    static var isPlus: Bool {
        get { AppGroup.defaults.bool(forKey: plusKey) }
        set { AppGroup.defaults.set(newValue, forKey: plusKey) }
    }
}
