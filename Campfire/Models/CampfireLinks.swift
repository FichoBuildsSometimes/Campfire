import Foundation

enum CampfireLinks {
    static let privacyPolicy = URL(string: "https://fichobuildssometimes.github.io/privacy/")!
    static let support = URL(string: "https://fichobuildssometimes.github.io/support/")!
}

enum CampfireDeepLink: Equatable {
    case home

    init?(url: URL) {
        guard url.scheme?.lowercased() == "campfire",
              url.host?.lowercased() == "home",
              url.user == nil,
              url.password == nil,
              url.port == nil,
              url.query == nil,
              url.fragment == nil,
              url.path.isEmpty || url.path == "/" else {
            return nil
        }

        self = .home
    }
}
