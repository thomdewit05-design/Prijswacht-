import SwiftData
import SwiftUI
import UIKit
import UserNotifications

@main
struct PrijswachtApp: App {
    @State private var router = AppRouter.shared
    @State private var plus = PlusStore()
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
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

/// Registratie voor pushmeldingen. Alleen nodig met een ingestelde server;
/// die stuurt de melding bij een prijsdaling.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if ServerClient.config != nil {
            application.registerForRemoteNotifications()
        }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        ServerClient.apnsToken = deviceToken.map { String(format: "%02x", $0) }.joined()
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Zonder push werkt de app verder; de stand komt bij het openen binnen.
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
            if phase == .active {
                Task {
                    await PriceChecker.refreshReminders(in: context)
                    await PriceChecker.sync(in: context)
                    PriceChecker.updateWidget(in: context)
                }
            } else if phase == .background {
                Task { @MainActor in PriceChecker.updateWidget(in: context) }
            }
        }
    }
}
