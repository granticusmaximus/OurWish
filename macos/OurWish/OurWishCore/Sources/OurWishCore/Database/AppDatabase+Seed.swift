import GRDB

extension AppDatabase {
    /// Seeds the original app's default first user (with a default wish list) the first
    /// time the app runs against an empty database, matching the original server's
    /// `INSERT OR IGNORE` default-user behavior in `server/database.ts`. Runs as a
    /// runtime check after migration (not as a one-time migration step) so it still
    /// applies if the users table is ever emptied out.
    public static func seedDefaultUserIfNeeded(_ dbWriter: some DatabaseWriter) throws {
        try dbWriter.write { db in
            guard try User.fetchCount(db) == 0 else { return }

            var user = User(
                firstName: "Grant",
                lastName: "Watson",
                displayName: "Grant",
                email: "grant@gwsapp.net",
                passwordHash: PasswordHasher.hash("Wats#0529")
            )
            try user.insert(db)

            var defaultList = WishList(userId: user.id!, name: "My Wish List")
            try defaultList.insert(db)
        }
    }
}
