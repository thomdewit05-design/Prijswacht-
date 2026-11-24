import Foundation
import PrijswachtCore

/// Winkelprofielen uit shops.json in de bundel.
enum ShopStore {
    static let directory: ShopDirectory = {
        guard let url = Bundle.main.url(forResource: "shops", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let directory = try? ShopDirectory(jsonData: data)
        else { return ShopDirectory(shops: []) }
        return directory
    }()

    static func shop(id: String, fallbackName: String) -> ShopProfile {
        directory.shop(id: id) ?? ShopProfile(id: id, name: fallbackName, domains: [])
    }
}
