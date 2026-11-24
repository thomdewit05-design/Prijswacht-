import PrijswachtCore
import SwiftUI
import UIKit

enum Theme {
    /// Groen voor bedragen; iets lichter in de donkere modus.
    static let money = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.30, green: 0.85, blue: 0.55, alpha: 1)
            : UIColor(red: 0.04, green: 0.48, blue: 0.29, alpha: 1)
    })
    static let warning = Color.orange
}

/// Bedragen zijn het ontwerp: groot, groen, altijd netto.
struct AmountText: View {
    let cents: Int
    var style: Font.TextStyle = .title2

    var body: some View {
        Text(verbatim: Euro.string(cents))
            .font(.system(style, design: .rounded, weight: .bold))
            .foregroundStyle(Theme.money)
            .monospacedDigit()
    }
}

/// "Nog 6 dagen", "Laatste dag", "Verlopen".
struct DaysBadge: View {
    let days: Int

    var body: some View {
        Text(label)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    private var label: LocalizedStringKey {
        switch days {
        case ..<0: "Retourtermijn verlopen"
        case 0: "Laatste dag"
        case 1: "Nog 1 dag"
        default: "Nog \(days) dagen"
        }
    }

    private var color: Color {
        switch days {
        case ..<0: .secondary
        case 0...3: Theme.warning
        default: .primary
        }
    }
}

struct ProductImage: View {
    let url: URL?
    var size: CGFloat = 52

    var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image.resizable().scaledToFit()
            } else {
                Image(systemName: "shippingbox")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityHidden(true)
    }
}
