import Foundation

/// Berekening van de retourtermijn: winkelprofiel + leverdatum.
public enum ReturnWindow {
    /// Laatste dag waarop retourneren nog kan (begin van die dag).
    /// De termijn begint de dag na levering; zonder leverdatum rekenen we
    /// voorzichtig vanaf de koopdatum.
    public static func lastDay(
        purchaseDate: Date, deliveryDate: Date?, returnDays: Int,
        calendar: Calendar = .current
    ) -> Date {
        let start = calendar.startOfDay(for: deliveryDate ?? purchaseDate)
        return calendar.date(byAdding: .day, value: max(returnDays, 0), to: start) ?? start
    }

    /// Aantal dagen dat je nog hebt, vandaag meegeteld als 0 op de laatste
    /// dag. Negatief = verlopen.
    public static func daysRemaining(lastDay: Date, now: Date, calendar: Calendar = .current) -> Int {
        let today = calendar.startOfDay(for: now)
        let end = calendar.startOfDay(for: lastDay)
        return calendar.dateComponents([.day], from: today, to: end).day ?? 0
    }

    public static func isOpen(lastDay: Date, now: Date, calendar: Calendar = .current) -> Bool {
        daysRemaining(lastDay: lastDay, now: now, calendar: calendar) >= 0
    }

    /// Moment voor de herinnering: drie dagen voor het einde, om 09:00.
    /// nil als dat moment al voorbij is.
    public static func reminderDate(
        lastDay: Date, now: Date, daysBefore: Int = 3, calendar: Calendar = .current
    ) -> Date? {
        let end = calendar.startOfDay(for: lastDay)
        guard let day = calendar.date(byAdding: .day, value: -daysBefore, to: end),
              let moment = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day),
              moment > now
        else { return nil }
        return moment
    }
}
