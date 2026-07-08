import Foundation
import GRDB

/// Persists opaque bearer tokens in the database so sessions survive backend restarts.
actor TokenStore {
    private let dbWriter: any DatabaseWriter

    init(dbWriter: any DatabaseWriter) {
        self.dbWriter = dbWriter
    }

    func issueToken(for userId: Int64) throws -> String {
        let token = Self.generateToken()
        try dbWriter.write { db in
            try db.execute(
                sql: """
                    INSERT INTO auth_tokens (token, user_id)
                    VALUES (?, ?)
                    """,
                arguments: [token, userId]
            )
        }
        return token
    }

    func userId(for token: String) throws -> Int64? {
        try dbWriter.read { db in
            try Int64.fetchOne(
                db,
                sql: """
                    SELECT user_id
                    FROM auth_tokens
                    WHERE token = ?
                    """,
                arguments: [token]
            )
        }
    }

    func revoke(_ token: String) throws {
        try dbWriter.write { db in
            try db.execute(
                sql: "DELETE FROM auth_tokens WHERE token = ?",
                arguments: [token]
            )
        }
    }

    private static func generateToken() -> String {
        let bytes = (0..<32).map { _ in UInt8.random(in: .min ... .max) }
        return Data(bytes)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
