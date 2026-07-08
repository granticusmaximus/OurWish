import Foundation
import OurWishServer

enum AppRuntime {
    static let remoteAPIBaseURL: URL? = {
        guard let rawValue = ProcessInfo.processInfo.environment["OURWISH_API_BASE_URL"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !rawValue.isEmpty else {
            return nil
        }
        return URL(string: rawValue)
    }()

    static let webBaseURL: URL? = {
        guard let rawValue = ProcessInfo.processInfo.environment["OURWISH_WEB_BASE_URL"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !rawValue.isEmpty else {
            return remoteAPIBaseURL
        }
        return URL(string: rawValue)
    }()

    static var isRemoteMode: Bool {
        remoteAPIBaseURL != nil
    }

    static var webAccessURL: String {
        if let webBaseURL {
            return trimmedAbsoluteString(for: webBaseURL)
        }
        return "http://\(ProcessInfo.processInfo.hostName):\(WishServer.defaultPort)"
    }

    private static func trimmedAbsoluteString(for url: URL) -> String {
        let value = url.absoluteString
        guard value.count > 1, value.hasSuffix("/") else { return value }
        return String(value.dropLast())
    }
}
