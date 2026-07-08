import Foundation
import GRDB

/// Local equivalent of `server/routes/auth.ts`. No network/session layer — every method
/// talks to the database directly, and the caller (`AuthStore`) holds the "who's logged
/// in right now" concept in memory.
public final class UserRepository: Sendable {
    /// The original app hardcodes a 2-user cap (built for exactly two partners sharing
    /// the app); kept as a hardcoded constant here for the same reason.
    public static let maxUsers = 2

    private let dbWriter: any DatabaseWriter

    public init(dbWriter: any DatabaseWriter) {
        self.dbWriter = dbWriter
    }

    public func login(email: String, password: String) throws -> User {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        let user = try dbWriter.read { db in
            try User.filter(sql: "LOWER(email) = LOWER(?)", arguments: [normalizedEmail]).fetchOne(db)
        }

        guard let user, PasswordHasher.verify(password, against: user.passwordHash) else {
            throw RepositoryError.invalidCredentials
        }

        return user
    }

    public func count() throws -> Int {
        try dbWriter.read { db in try User.fetchCount(db) }
    }

    @discardableResult
    public func createUser(firstName: String, lastName: String, email: String, password: String) throws -> User {
        let trimmedFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedFirstName.isEmpty, !trimmedLastName.isEmpty, !normalizedEmail.isEmpty, !password.isEmpty else {
            throw RepositoryError.invalidInput("All fields required")
        }

        return try dbWriter.write { db in
            let existingCount = try User.fetchCount(db)
            guard existingCount < Self.maxUsers else {
                throw RepositoryError.userLimitReached(max: Self.maxUsers)
            }

            let existingEmail = try User
                .filter(sql: "LOWER(email) = LOWER(?)", arguments: [normalizedEmail])
                .fetchOne(db)
            guard existingEmail == nil else {
                throw RepositoryError.emailAlreadyExists
            }

            var user = User(
                firstName: trimmedFirstName,
                lastName: trimmedLastName,
                displayName: trimmedFirstName,
                email: normalizedEmail,
                passwordHash: PasswordHasher.hash(password)
            )
            try user.insert(db)

            var defaultList = WishList(userId: user.id!, name: "My Wish List")
            try defaultList.insert(db)

            return user
        }
    }

    public func partners(excluding userId: Int64) throws -> [User] {
        try dbWriter.read { db in
            try User
                .filter(User.Columns.id != userId)
                .order(User.Columns.email)
                .fetchAll(db)
        }
    }

    public func user(id: Int64) throws -> User? {
        try dbWriter.read { db in try User.fetchOne(db, key: id) }
    }
}
