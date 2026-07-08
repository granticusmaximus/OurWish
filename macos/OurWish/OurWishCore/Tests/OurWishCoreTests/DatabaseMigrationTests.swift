import GRDB
import Testing
@testable import OurWishCore

struct DatabaseMigrationTests {
    @Test func migratorCreatesAllTables() throws {
        let dbQueue = try DatabaseQueue()
        try AppDatabase.migrator.migrate(dbQueue)

        let tableNames = try dbQueue.read { db in
            try String.fetchSet(db, sql: "SELECT name FROM sqlite_master WHERE type = 'table'")
        }

        for expected in ["users", "wish_lists", "wish_list_items", "collaborative_lists", "collaborative_items"] {
            #expect(tableNames.contains(expected), "missing table \(expected)")
        }
    }

    @Test func seedCreatesDefaultUserAndWishListOnlyOnce() throws {
        let dbQueue = try DatabaseQueue()
        try AppDatabase.migrator.migrate(dbQueue)

        try AppDatabase.seedDefaultUserIfNeeded(dbQueue)
        let firstUsers = try dbQueue.read { try User.fetchAll($0) }
        #expect(firstUsers.count == 1)
        #expect(firstUsers.first?.email == "grant@gwsapp.net")
        #expect(PasswordHasher.verify("Wats#0529", against: firstUsers.first!.passwordHash))

        let seededLists = try dbQueue.read {
            try WishList.filter(WishList.Columns.userId == firstUsers.first!.id!).fetchAll($0)
        }
        #expect(seededLists.count == 1)
        #expect(seededLists.first?.name == "My Wish List")

        // Seeding again (e.g. a second app launch) must not duplicate the user.
        try AppDatabase.seedDefaultUserIfNeeded(dbQueue)
        let usersAfterSecondSeed = try dbQueue.read { try User.fetchAll($0) }
        #expect(usersAfterSecondSeed.count == 1)
    }
}
