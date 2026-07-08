import CryptoKit
import Foundation

/// Salted PBKDF2-HMAC-SHA256 password hashing, hand-rolled on top of CryptoKit's
/// `HMAC<SHA256>` since CryptoKit has no built-in PBKDF2. Replaces the original app's
/// plaintext `password` column with a `password_hash` column storing
/// `pbkdf2-sha256$iterations$salt$hash` (salt/hash base64-encoded).
public enum PasswordHasher {
    private static let saltByteCount = 16

    public static func hash(_ password: String, iterations: Int = 100_000) -> String {
        let salt = randomBytes(count: saltByteCount)
        let derived = pbkdf2(password: password, salt: salt, iterations: iterations)
        return [
            "pbkdf2-sha256",
            String(iterations),
            Data(salt).base64EncodedString(),
            Data(derived).base64EncodedString()
        ].joined(separator: "$")
    }

    public static func verify(_ password: String, against stored: String) -> Bool {
        let parts = stored.split(separator: "$").map(String.init)
        guard parts.count == 4,
              parts[0] == "pbkdf2-sha256",
              let iterations = Int(parts[1]),
              let salt = Data(base64Encoded: parts[2]),
              let expected = Data(base64Encoded: parts[3]) else {
            return false
        }

        let derived = Data(pbkdf2(password: password, salt: [UInt8](salt), iterations: iterations))
        return constantTimeEquals(derived, expected)
    }

    private static func randomBytes(count: Int) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: count)
        let result = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        precondition(result == errSecSuccess, "Failed to generate random bytes for password salt")
        return bytes
    }

    /// PBKDF2-HMAC-SHA256, single block (dkLen == hLen == 32 bytes), per RFC 8018.
    private static func pbkdf2(password: String, salt: [UInt8], iterations: Int) -> [UInt8] {
        let key = SymmetricKey(data: Data(password.utf8))
        let blockIndex: [UInt8] = [0, 0, 0, 1]

        var u = Data(HMAC<SHA256>.authenticationCode(for: Data(salt) + blockIndex, using: key))
        var result = u

        guard iterations > 1 else { return [UInt8](result) }

        for _ in 1..<iterations {
            u = Data(HMAC<SHA256>.authenticationCode(for: u, using: key))
            result = xor(result, u)
        }

        return [UInt8](result)
    }

    private static func xor(_ lhs: Data, _ rhs: Data) -> Data {
        Data(zip(lhs, rhs).map(^))
    }

    private static func constantTimeEquals(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var diff: UInt8 = 0
        for (a, b) in zip(lhs, rhs) {
            diff |= a ^ b
        }
        return diff == 0
    }
}
