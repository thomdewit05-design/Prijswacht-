import PrijswachtCore
import SwiftUI

/// Eerste keer openen: belofte, voorbeeld, delen-knop, meldingen, klaar.
/// Geen account nodig.
struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page = 0
    private let lastPage = 4

    var body: some View {
        VStack {
            TabView(selection: $page) {
                promise.tag(0)
                example.tag(1)
                sharing.tag(2)
                notifications.tag(3)
                done.tag(4)
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button(action: next) {
                Text(buttonTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .interactiveDismissDisabled()
    }

    private var buttonTitle: LocalizedStringKey {
        switch page {
        case 3: "Zet meldingen aan"
        case lastPage: "Begin"
        default: "Verder"
        }
    }

    private func next() {
        if page == 3 {
            Task {
                await NotificationManager.requestPermission()
                withAnimation { page = lastPage }
            }
        } else if page == lastPage {
            onFinish()
        } else {
            withAnimation { page += 1 }
        }
    }

    private var promise: some View {
        OnboardingPage(
            symbol: "eye",
            title: "Gekocht en daarna goedkoper?",
            text: "Wij zien het en wijzen je de kortste weg naar je geld.")
    }

    /// Rekenvoorbeeld met verzonnen bedragen. Vervang dit door echte cijfers
    /// uit de prijsstudie zodra die er zijn.
    private var example: some View {
        VStack(spacing: 20) {
            Text("Zo werkt het")
                .font(.title.bold())
            VStack(spacing: 12) {
                exampleRow(day: "Dag 1", label: "Je koopt een laptop", cents: 89_900)
                exampleRow(day: "Dag 9", label: "Dezelfde winkel, dezelfde laptop", cents: 84_900)
                Divider()
                HStack {
                    Text("Het verschil")
                        .font(.headline)
                    Spacer()
                    AmountText(cents: 5_000, style: .title)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
            Text("Rekenvoorbeeld. Je retourtermijn loopt dan nog, dus je kunt de winkel om het verschil vragen.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }

    private func exampleRow(day: LocalizedStringKey, label: LocalizedStringKey, cents: Int) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(day).font(.caption).foregroundStyle(.secondary)
                Text(label)
            }
            Spacer()
            Text(verbatim: Euro.string(cents))
                .font(.body.monospacedDigit().weight(.medium))
        }
    }

    private var sharing: some View {
        OnboardingPage(
            symbol: "square.and.arrow.up",
            title: "Voeg een aankoop toe in vijf seconden",
            text: "Tik op de productpagina in Safari of de winkelapp op Deel en kies Prijswacht. Iets gekocht in de afgelopen twee weken? Begin daarmee.")
    }

    private var notifications: some View {
        OnboardingPage(
            symbol: "bell",
            title: "Je hoort alleen iets als het telt",
            text: "We sturen een melding bij een prijsdaling en als je retourtermijn bijna afloopt. Verder niets.")
    }

    private var done: some View {
        OnboardingPage(
            symbol: "checkmark.circle",
            title: "Klaar",
            text: "Je hebt geen account nodig. We lezen je mail niet en versturen niets namens jou.")
    }
}

private struct OnboardingPage: View {
    let symbol: String
    let title: LocalizedStringKey
    let text: LocalizedStringKey

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: symbol)
                .font(.system(size: 60, weight: .light))
                .foregroundStyle(Theme.money)
                .accessibilityHidden(true)
            Text(title)
                .font(.title.bold())
                .multilineTextAlignment(.center)
            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }
}
