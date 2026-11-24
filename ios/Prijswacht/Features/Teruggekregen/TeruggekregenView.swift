import PrijswachtCore
import SwiftData
import SwiftUI

/// Tab "Teruggekregen": de teller, de geschiedenis en de deelkaart.
struct TeruggekregenView: View {
    @Query(filter: #Predicate<Outcome> { $0.succeeded == true }, sort: \Outcome.date, order: .reverse)
    private var successes: [Outcome]

    private var year: Int { Calendar.current.component(.year, from: .now) }

    private var totalThisYear: Int {
        successes
            .filter { Calendar.current.component(.year, from: $0.date) == year }
            .reduce(0) { $0 + $1.amountCents }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 6) {
                        Text("Dit jaar teruggekregen")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        AmountText(cents: totalThisYear, style: .largeTitle)
                            .scaleEffect(1.3)
                            .padding(.vertical, 6)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .accessibilityElement(children: .combine)

                    if totalThisYear > 0 {
                        let card = shareImage(cents: totalThisYear)
                        ShareLink(item: card, preview: SharePreview("Mijn Prijswacht-teller", image: card)) {
                            Label("Deel als kaart", systemImage: "square.and.arrow.up")
                        }
                    }
                }

                if successes.isEmpty {
                    Section {
                        Text("Hier komt te staan wat je hebt teruggekregen. Tik na een geslaagde route op Gelukt.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("Geschiedenis") {
                        ForEach(successes) { outcome in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(outcome.purchaseTitle)
                                        .lineLimit(1)
                                    Text(verbatim: outcome.shopName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(outcome.date, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                AmountText(cents: outcome.amountCents, style: .body)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Teruggekregen")
        }
    }

    @MainActor
    private func shareImage(cents: Int) -> Image {
        let renderer = ImageRenderer(content: ShareCard(cents: cents, year: year))
        renderer.scale = 3
        if let image = renderer.uiImage {
            return Image(uiImage: image)
        }
        return Image(systemName: "eurosign.circle")
    }
}

/// De kaart voor WhatsApp en Stories.
struct ShareCard: View {
    let cents: Int
    let year: Int

    var body: some View {
        VStack(spacing: 14) {
            Text(verbatim: "Prijswacht")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
            Text(verbatim: Euro.string(cents))
                .font(.system(size: 76, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
            Text("teruggekregen in \(String(year)), omdat de prijs daalde na mijn aankoop")
                .font(.system(.body, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(32)
        .frame(width: 360, height: 360)
        .background(
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.48, blue: 0.29), Color(red: 0.02, green: 0.33, blue: 0.24)],
                startPoint: .top, endPoint: .bottom))
    }
}
