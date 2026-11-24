import SwiftData
import SwiftUI
import UserNotifications

@main
struct PrijswachtApp: App {
    @State private var router = AppRouter.shared
    @State private var plus = PlusStore()
    private let notificationDelegate = NotificationDelegate()

    init() {
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .environment(plus)
                .tint(Theme.money)
                .task { await plus.start() }
        }
        .modelContainer(AppGroup.container)
    }
}

/// Stuurt de app naar een aankoop, bijvoorbeeld na een tik op een melding.
@MainActor
@Observable
final class AppRouter {
    static let shared = AppRouter()

    enum Tab: Hashable {
        case watched, reclaimed, settings
    }

    var tab: Tab = .watched
    var watchedPath: [UUID] = []

    func open(purchaseID: UUID) {
        tab = .watched
        watchedPath = [purchaseID]
    }
}

struct RootView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context
    @AppStorage(AppSettings.onboardedKey, store: AppGroup.defaults) private var hasOnboarded = false

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.tab) {
            BewaaktView()
                .tabItem { Label("Bewaakt", systemImage: "eye") }
                .tag(AppRouter.Tab.watched)
            TeruggekregenView()
                .tabItem { Label("Teruggekregen", systemImage: "eurosign.circle") }
                .tag(AppRouter.Tab.reclaimed)
            InstellingenView()
                .tabItem { Label("Instellingen", systemImage: "gearshape") }
                .tag(AppRouter.Tab.settings)
        }
        .fullScreenCover(isPresented: .constant(!hasOnboarded)) {
            OnboardingView { hasOnboarded = true }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await PriceChecker.refreshReminders(in: context) }
        }
    }
}
