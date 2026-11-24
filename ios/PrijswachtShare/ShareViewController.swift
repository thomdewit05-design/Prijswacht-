import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Delen-extensie: ontvangt de gedeelde productpagina en laat de gebruiker
/// de aankoop bevestigen. Gebruikt alleen de gedeelde link, niets anders
/// uit de browser.
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        let root = ShareRootView(
            loadURL: { [weak self] in await self?.sharedURL() },
            onClose: { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: nil)
            })
            .modelContainer(AppGroup.container)

        let host = UIHostingController(rootView: root)
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        host.didMove(toParent: self)
    }

    /// De gedeelde weblink; winkelapps delen soms tekst met een link erin.
    private func sharedURL() async -> URL? {
        let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
        let providers = items.flatMap { $0.attachments ?? [] }

        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            let item = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier)
            if let url = item as? URL, url.scheme?.hasPrefix("http") ?? false {
                return url
            }
        }
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            let item = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier)
            if let text = item as? String, let url = OfferFetcher.firstURL(in: text) {
                return url
            }
        }
        return nil
    }
}
