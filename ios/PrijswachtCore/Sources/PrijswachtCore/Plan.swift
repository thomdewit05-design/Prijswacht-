import Foundation

/// Grenzen van de gratis versie.
public enum FreeTier {
    public static let maxActivePurchases = 3

    public static func canAddPurchase(activeCount: Int, isPlus: Bool) -> Bool {
        isPlus || activeCount < maxActivePurchases
    }

    /// De eerste treffer mag een gratis gebruiker altijd afronden; daarna
    /// is het routescherm voor Plus.
    public static func canOpenRoute(completedOutcomes: Int, isPlus: Bool) -> Bool {
        isPlus || completedOutcomes == 0
    }
}

/// Slagingspercentage per winkel en route, uit Gelukt/Geweigerd.
public struct SuccessRate: Equatable, Sendable {
    public let succeeded: Int
    public let total: Int

    public init(succeeded: Int, total: Int) {
        self.succeeded = succeeded
        self.total = total
    }

    /// Pas tonen vanaf een paar antwoorden; daaronder zegt het niets.
    public var percentage: Int? {
        total >= 3 ? Int((Double(succeeded) / Double(total) * 100).rounded()) : nil
    }
}
