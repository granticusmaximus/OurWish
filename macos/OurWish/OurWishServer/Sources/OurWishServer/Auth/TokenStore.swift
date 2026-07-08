import Foundation
import Security

/// Maps opaque bearer tokens to a `userId`. In-memory only — restarting the app (and
/// therefore the embedded server) invalidates every session, which is an acceptable
/// simplification for a household app rather than adding a persisted-session table.
actor TokenStore {
    private var tokensToUserId: [String: Int64] = [:]

    func issueToken(for userId: Int64) -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let result = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        precondition(result == errSecSuccess, "Failed to generate a random session token")
        let token = Data(bytes).base64EncodedString()
        tokensToUserId[token] = userId
        return token
    }

    func userId(for token: String) -> Int64? {
        tokensToUserId[token]
    }

    func revoke(_ token: String) {
        tokensToUserId[token] = nil
    }
}
