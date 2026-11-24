import PrijswachtCore
import SwiftUI
import WidgetKit

struct TellerEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct TellerProvider: TimelineProvider {
    func placeholder(in context: Context) -> TellerEntry {
        TellerEntry(date: .now, snapshot: WidgetSnapshot(reclaimedThisYearCents: 3800, watchedCount: 2))
    }

    func getSnapshot(in context: Context, completion: @escaping (TellerEntry) -> Void) {
        completion(TellerEntry(date: .now, snapshot: .load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TellerEntry>) -> Void) {
        // De app ververst de widget zelf bij wijzigingen; elke nacht opnieuw
        // tekenen houdt het aantal resterende dagen kloppend.
        let now = Date.now
        let midnight = Calendar.current.nextDate(
            after: now, matching: DateComponents(hour: 0, minute: 5), matchingPolicy: .nextTime) ?? now.addingTimeInterval(86_400)
        completion(Timeline(entries: [TellerEntry(date: now, snapshot: .load())], policy: .after(midnight)))
    }
}

struct TellerWidgetView: View {
    let entry: TellerEntry

    private var daysLeft: Int? {
        entry.snapshot.nextDeadline.map { ReturnWindow.daysRemaining(lastDay: $0, now: entry.date) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Teruggekregen")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(verbatim: Euro.string(entry.snapshot.reclaimedThisYearCents))
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(.green)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Spacer(minLength: 0)
            if entry.snapshot.dropCount > 0 {
                Label("\(entry.snapshot.dropCount) prijs gedaald", systemImage: "arrow.down.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            } else if let title = entry.snapshot.nextDeadlineTitle, let daysLeft, daysLeft >= 0 {
                Text(title)
                    .font(.caption)
                    .lineLimit(1)
                Text(daysLeft == 0 ? LocalizedStringKey("Laatste retourdag") : LocalizedStringKey("Nog \(daysLeft) dagen retour"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(daysLeft <= 3 ? Color.orange : Color.primary)
            } else {
                Text("\(entry.snapshot.watchedCount) bewaakt")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct TellerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "nl.prijswacht.teller", provider: TellerProvider()) { entry in
            TellerWidgetView(entry: entry)
        }
        .configurationDisplayName("Prijswacht")
        .description("Wat je dit jaar terugkreeg en welke retourtermijn als eerste afloopt.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct PrijswachtWidgetBundle: WidgetBundle {
    var body: some Widget {
        TellerWidget()
    }
}
