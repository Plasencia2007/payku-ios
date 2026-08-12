import Foundation

/// Build-time role for a Payku target. The role is never selected inside the app.
enum AppRole: String, Codable, Hashable, Sendable {
    case owner
    case cashier

    var paykuRole: PaykuRole {
        switch self {
        case .owner: .owner
        case .cashier: .cashier
        }
    }

    var linkPath: String {
        switch self {
        case .owner: "/device/vincular"
        case .cashier: "/espejo/vincular"
        }
    }
}

enum AppConfig {
    /// Replace this URL with the production API before shipping.
    static let baseURL: URL = URL(string: "https://TU-BACKEND") ?? URL(string: "https://localhost")!

    /// Keep true for previews and local UI work. Set false for a real backend build.
    static let useFakeBackend: Bool = true
    static let requestTimeout: TimeInterval = 15
    static let pollingInterval: Duration = .seconds(5)
    static let overlapInterval: TimeInterval = 48 * 60 * 60
    static let limaTimeZone: TimeZone = TimeZone(identifier: "America/Lima") ?? .gmt
    static let sessionKey = "device-session"
    static let introKey = "has-seen-intro"
    static let setupKey = "setup-complete"

    static var currentRole: AppRole {
        #if OWNER_APP
        return .owner
        #elseif CASHIER_APP
        return .cashier
        #else
        return .owner
        #endif
    }
}

