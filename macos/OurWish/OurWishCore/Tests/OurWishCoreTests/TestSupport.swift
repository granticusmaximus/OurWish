import GRDB
@testable import OurWishCore

enum TestSupport {
    /// A freshly migrated, empty, in-memory database — no seed data, so tests control
    /// their own fixtures.
    static func makeMigratedDatabase() throws -> DatabaseQueue {
        let dbQueue = try DatabaseQueue()
        try AppDatabase.migrator.migrate(dbQueue)
        return dbQueue
    }

    @discardableResult
    static func insertUser(
        _ dbQueue: DatabaseQueue,
        firstName: String = "Test",
        lastName: String = "User",
        email: String,
        password: String = "password123"
    ) throws -> User {
        try dbQueue.write { db in
            var user = User(
                firstName: firstName,
                lastName: lastName,
                displayName: firstName,
                email: email,
                passwordHash: PasswordHasher.hash(password)
            )
            try user.insert(db)
            return user
        }
    }
}
