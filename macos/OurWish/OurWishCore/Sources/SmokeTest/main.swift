import Foundation
import GRDB
import OurWishCore

var failureCount = 0

@MainActor
func check(_ name: String, _ condition: @autoclosure () throws -> Bool) rethrows {
    if try condition() {
        print("  ok   - \(name)")
    } else {
        print("  FAIL - \(name)")
        failureCount += 1
    }
}

@MainActor
func checkThrows(_ name: String, expected: RepositoryError, _ block: () throws -> Void) {
    do {
        try block()
        print("  FAIL - \(name) (expected \(expected), nothing thrown)")
        failureCount += 1
    } catch let error as RepositoryError where error == expected {
        print("  ok   - \(name)")
    } catch {
        print("  FAIL - \(name) (expected \(expected), got \(error))")
        failureCount += 1
    }
}

func section(_ title: String) {
    print("\n\(title)")
}

func freshDatabase() throws -> DatabaseQueue {
    let dbQueue = try DatabaseQueue()
    try AppDatabase.migrator.migrate(dbQueue)
    return dbQueue
}

@discardableResult
func insertUser(
    _ dbQueue: DatabaseQueue, firstName: String = "Test", email: String, password: String = "password123"
) throws -> User {
    try dbQueue.write { db in
        var user = User(
            firstName: firstName, lastName: "User", displayName: firstName,
            email: email, passwordHash: PasswordHasher.hash(password)
        )
        try user.insert(db)
        return user
    }
}

// MARK: - PasswordHasher

section("PasswordHasher")
do {
    let hash = PasswordHasher.hash("Wats#0529")
    check("verify succeeds for correct password", PasswordHasher.verify("Wats#0529", against: hash))
    check("verify fails for wrong password", !PasswordHasher.verify("wrong", against: hash))
    let hash2 = PasswordHasher.hash("Wats#0529")
    check("two hashes of the same password differ (salted)", hash != hash2)
    check("verify fails for malformed stored value", !PasswordHasher.verify("x", against: "not-a-hash"))
}

// MARK: - Migrations + seeding

section("Migrations + seeding")
do {
    let dbQueue = try freshDatabase()
    let tableNames = try dbQueue.read { db in
        try String.fetchSet(db, sql: "SELECT name FROM sqlite_master WHERE type = 'table'")
    }
    for table in ["users", "wish_lists", "wish_list_items", "collaborative_lists", "collaborative_items"] {
        check("migrator created table \(table)", tableNames.contains(table))
    }

    try AppDatabase.seedDefaultUserIfNeeded(dbQueue)
    let users = try dbQueue.read { try User.fetchAll($0) }
    check("seed creates exactly one user", users.count == 1)
    check("seed user has expected email", users.first?.email == "grant@gwsapp.net")
    check(
        "seed user password verifies",
        users.first.map { PasswordHasher.verify("Wats#0529", against: $0.passwordHash) } ?? false
    )

    let seededLists = try dbQueue.read { db in
        try WishList.filter(WishList.Columns.userId == users.first!.id!).fetchAll(db)
    }
    check("seed creates one default wish list", seededLists.count == 1 && seededLists.first?.name == "My Wish List")

    try AppDatabase.seedDefaultUserIfNeeded(dbQueue)
    let usersAfterReseed = try dbQueue.read { try User.fetchAll($0) }
    check("seeding twice does not duplicate the user", usersAfterReseed.count == 1)
}

// Anyone who already launched the app before this feature has a v1-only database on
// disk. Confirm the v2 migration adds the new columns to that existing data in place,
// without touching (or requiring) any existing rows.
section("Migration upgrade path (v1 -> v2)")
do {
    let dbQueue = try DatabaseQueue()
    try AppDatabase.migrator.migrate(dbQueue, upTo: "v1CreateSchema")

    try dbQueue.write { db in
        try db.execute(
            sql: """
                INSERT INTO users (first_name, last_name, display_name, email, password_hash)
                VALUES (?, ?, ?, ?, ?)
                """,
            arguments: ["Pat", "Nguyen", "Pat", "pat@example.com", PasswordHasher.hash("secret123")]
        )
    }

    let columnsBeforeUpgrade = try dbQueue.read { db in
        try Row.fetchAll(db, sql: "PRAGMA table_info(users)").map { $0["name"] as String }
    }
    check("v1-only schema has no bio column yet", !columnsBeforeUpgrade.contains("bio"))

    try AppDatabase.migrator.migrate(dbQueue)

    let usersAfterUpgrade = try dbQueue.read { try User.fetchAll($0) }
    check("existing user survives the v1 -> v2 upgrade", usersAfterUpgrade.count == 1)
    check("existing user's email is untouched", usersAfterUpgrade.first?.email == "pat@example.com")
    check("existing user's new bio column defaults to nil", usersAfterUpgrade.first?.bio == nil)
    check("existing user's new profile image column defaults to nil", usersAfterUpgrade.first?.profileImageData == nil)
}

// MARK: - UserRepository

section("UserRepository")
do {
    let dbQueue = try freshDatabase()
    try insertUser(dbQueue, email: "a@example.com", password: "secret123")
    let repo = UserRepository(dbWriter: dbQueue)

    try check("login succeeds with correct credentials", try repo.login(email: "a@example.com", password: "secret123").email == "a@example.com")
    try check("login is case-insensitive on email", try repo.login(email: "A@EXAMPLE.com", password: "secret123").email == "a@example.com")
    checkThrows("login fails with wrong password", expected: .invalidCredentials) {
        _ = try repo.login(email: "a@example.com", password: "wrong")
    }
    checkThrows("login fails for unknown email", expected: .invalidCredentials) {
        _ = try repo.login(email: "nobody@example.com", password: "secret123")
    }
}

do {
    let dbQueue = try freshDatabase()
    let repo = UserRepository(dbWriter: dbQueue)
    let user = try repo.createUser(firstName: "Jamie", lastName: "Lee", email: "jamie@example.com", password: "secret123")
    let lists = try dbQueue.read { db in try WishList.filter(WishList.Columns.userId == user.id!).fetchAll(db) }
    check("createUser seeds one default wish list", lists.count == 1 && lists.first?.name == "My Wish List")
}

do {
    let dbQueue = try freshDatabase()
    let repo = UserRepository(dbWriter: dbQueue)
    try repo.createUser(firstName: "One", lastName: "User", email: "one@example.com", password: "secret123")
    try repo.createUser(firstName: "Two", lastName: "User", email: "two@example.com", password: "secret123")
    checkThrows("createUser enforces max-2-users cap", expected: .userLimitReached(max: 2)) {
        try repo.createUser(firstName: "Three", lastName: "User", email: "three@example.com", password: "secret123")
    }
}

do {
    let dbQueue = try freshDatabase()
    let repo = UserRepository(dbWriter: dbQueue)
    try repo.createUser(firstName: "One", lastName: "User", email: "dup@example.com", password: "secret123")
    checkThrows("createUser rejects duplicate email case-insensitively", expected: .emailAlreadyExists) {
        try repo.createUser(firstName: "Two", lastName: "User", email: "DUP@example.com", password: "secret123")
    }
}

do {
    let dbQueue = try freshDatabase()
    let userA = try insertUser(dbQueue, email: "a@example.com")
    try insertUser(dbQueue, email: "b@example.com")
    let repo = UserRepository(dbWriter: dbQueue)
    let partners = try repo.partners(excluding: userA.id!)
    check("partners excludes self", partners.map(\.email) == ["b@example.com"])
}

do {
    let dbQueue = try freshDatabase()
    let user = try insertUser(dbQueue, firstName: "Jamie", email: "a@example.com", password: "secret123")
    let repo = UserRepository(dbWriter: dbQueue)
    let imageData = Data([0xFF, 0xD8, 0xFF, 0xD9])

    let updated = try repo.updateProfile(
        userId: user.id!, firstName: "Jamie", lastName: "Rivera", displayName: "Jam",
        bio: "Loves board games", profileImageData: imageData
    )
    check("updateProfile updates display name", updated.displayName == "Jam")
    check("updateProfile updates last name", updated.lastName == "Rivera")
    check("updateProfile updates bio", updated.bio == "Loves board games")
    check("updateProfile stores image data", updated.profileImageData == imageData)

    let reloaded = try repo.user(id: user.id!)
    try check("updateProfile persists to the database", reloaded?.displayName == "Jam")

    checkThrows("updateProfile rejects blank display name", expected: .invalidInput("First name, last name, and display name are required")) {
        try repo.updateProfile(userId: user.id!, firstName: "Jamie", lastName: "Rivera", displayName: "  ", bio: nil, profileImageData: nil)
    }
}

do {
    let dbQueue = try freshDatabase()
    let user = try insertUser(dbQueue, email: "a@example.com", password: "secret123")
    let repo = UserRepository(dbWriter: dbQueue)

    try repo.updatePassword(userId: user.id!, currentPassword: "secret123", newPassword: "newpass456")
    try check("changed password verifies", repo.user(id: user.id!).map { PasswordHasher.verify("newpass456", against: $0.passwordHash) } ?? false)
    try check("old password no longer works", !(repo.user(id: user.id!).map { PasswordHasher.verify("secret123", against: $0.passwordHash) } ?? true))

    checkThrows("updatePassword rejects wrong current password", expected: .incorrectCurrentPassword) {
        try repo.updatePassword(userId: user.id!, currentPassword: "wrong-current", newPassword: "whatever123")
    }
}

// MARK: - WishListRepository

section("WishListRepository")
do {
    let dbQueue = try freshDatabase()
    let user = try insertUser(dbQueue, email: "a@example.com")
    let repo = WishListRepository(dbWriter: dbQueue)
    let onlyList = try repo.createList(userId: user.id!, name: "My Wish List")
    checkThrows("cannot delete only wish list", expected: .cannotDeleteOnlyWishList) {
        try repo.deleteList(listId: onlyList.id!, userId: user.id!)
    }
}

do {
    let dbQueue = try freshDatabase()
    let user = try insertUser(dbQueue, email: "a@example.com")
    let repo = WishListRepository(dbWriter: dbQueue)
    let first = try repo.createList(userId: user.id!, name: "First")
    _ = try repo.createList(userId: user.id!, name: "Second")
    try repo.deleteList(listId: first.id!, userId: user.id!)
    let remaining = try repo.lists(for: user.id!)
    check("can delete a list when multiple exist", remaining.map(\.name) == ["Second"])
}

do {
    let dbQueue = try freshDatabase()
    let user = try insertUser(dbQueue, email: "a@example.com")
    let repo = WishListRepository(dbWriter: dbQueue)
    let list = try repo.createList(userId: user.id!, name: "My Wish List")
    let item = try repo.addItem(listId: list.id!, userId: user.id!, productName: "Widget", price: 9.99, quantity: 2, url: nil)
    try check("new item appears in active items", try repo.items(listId: list.id!, userId: user.id!, purchased: false).count == 1)
    try check("new item is not in purchased items", try repo.items(listId: list.id!, userId: user.id!, purchased: true).count == 0)
    try repo.setPurchased(itemId: item.id!, userId: user.id!, isPurchased: true)
    try check("purchased item moves out of active items", try repo.items(listId: list.id!, userId: user.id!, purchased: false).count == 0)
    try check("purchased item moves into purchased items", try repo.items(listId: list.id!, userId: user.id!, purchased: true).count == 1)
    try repo.deleteItem(itemId: item.id!, userId: user.id!)
    try check("deleted item disappears", try repo.items(listId: list.id!, userId: user.id!, purchased: true).count == 0)
}

do {
    let dbQueue = try freshDatabase()
    let userA = try insertUser(dbQueue, email: "a@example.com")
    let userB = try insertUser(dbQueue, email: "b@example.com")
    let repo = WishListRepository(dbWriter: dbQueue)
    let listA = try repo.createList(userId: userA.id!, name: "A's List")
    checkThrows("ownership is enforced across users", expected: .wishListNotFound) {
        try repo.addItem(listId: listA.id!, userId: userB.id!, productName: "Widget", price: 1, quantity: 1, url: nil)
    }
}

do {
    let dbQueue = try freshDatabase()
    let user = try insertUser(dbQueue, email: "a@example.com")
    let repo = WishListRepository(dbWriter: dbQueue)
    let list = try repo.createList(userId: user.id!, name: "My Wish List")
    let photoData = Data([0xFF, 0xD8, 0xFF, 0xD9])

    let item = try repo.addItem(
        listId: list.id!, userId: user.id!, productName: "Espresso Machine",
        price: 199, quantity: 1, url: "https://example.com/product", imageData: photoData
    )
    check("addItem stores the fetched product image", item.imageData == photoData)

    let refetched = try repo.items(listId: list.id!, userId: user.id!, purchased: false).first
    check("product image persists to the database", refetched?.imageData == photoData)

    try repo.updateItem(
        itemId: item.id!, userId: user.id!, productName: "Espresso Machine (Deluxe)",
        price: 219, quantity: 1, url: "https://example.com/product"
    )
    let afterEdit = try repo.items(listId: list.id!, userId: user.id!, purchased: false).first
    check("editing an item does not clear its existing product image", afterEdit?.imageData == photoData)
}

// MARK: - CollaborativeListRepository

section("CollaborativeListRepository")
do {
    let dbQueue = try freshDatabase()
    let user = try insertUser(dbQueue, email: "a@example.com")
    let repo = CollaborativeListRepository(dbWriter: dbQueue)
    checkThrows("createList rejects self-collaboration", expected: .cannotCollaborateWithSelf) {
        try repo.createList(currentUserId: user.id!, partnerEmail: "a@example.com", name: "Shared")
    }
}

do {
    let dbQueue = try freshDatabase()
    let user = try insertUser(dbQueue, email: "a@example.com")
    let repo = CollaborativeListRepository(dbWriter: dbQueue)
    checkThrows("createList fails when partner not found", expected: .partnerNotFound) {
        try repo.createList(currentUserId: user.id!, partnerEmail: "ghost@example.com", name: "Shared")
    }
}

do {
    let dbQueue = try freshDatabase()
    let userA = try insertUser(dbQueue, firstName: "Alex", email: "a@example.com")
    let userB = try insertUser(dbQueue, firstName: "Bailey", email: "b@example.com")
    let repo = CollaborativeListRepository(dbWriter: dbQueue)
    try repo.createList(currentUserId: userA.id!, partnerEmail: "b@example.com", name: "Vacation")
    let fromA = try repo.lists(for: userA.id!)
    let fromB = try repo.lists(for: userB.id!)
    check("list query shows partner's name to user A", fromA.map(\.partnerName) == ["Bailey"])
    check("list query shows partner's name to user B", fromB.map(\.partnerName) == ["Alex"])
}

do {
    let dbQueue = try freshDatabase()
    let userA = try insertUser(dbQueue, email: "a@example.com")
    try insertUser(dbQueue, email: "b@example.com")
    let repo = CollaborativeListRepository(dbWriter: dbQueue)
    let list = try repo.createList(currentUserId: userA.id!, partnerEmail: "b@example.com", name: "Vacation")
    let item = try repo.addItem(listId: list.id!, userId: userA.id!, productName: "Sunscreen", price: 12.5, quantity: 2, url: nil)
    try check("collaborative item CRUD: add", try repo.items(listId: list.id!, userId: userA.id!, purchased: false).count == 1)
    try repo.setPurchased(itemId: item.id!, listId: list.id!, userId: userA.id!, isPurchased: true)
    try check("collaborative item CRUD: mark purchased", try repo.items(listId: list.id!, userId: userA.id!, purchased: true).count == 1)
    try repo.deleteItem(itemId: item.id!, listId: list.id!, userId: userA.id!)
    try check("collaborative item CRUD: delete", try repo.items(listId: list.id!, userId: userA.id!, purchased: true).count == 0)
}

do {
    let dbQueue = try freshDatabase()
    let userA = try insertUser(dbQueue, email: "a@example.com")
    try insertUser(dbQueue, email: "b@example.com")
    let repo = CollaborativeListRepository(dbWriter: dbQueue)
    let list = try repo.createList(currentUserId: userA.id!, partnerEmail: "b@example.com", name: "Vacation")
    try repo.addItem(listId: list.id!, userId: userA.id!, productName: "Sunscreen", price: 12.5, quantity: 1, url: nil)
    try repo.deleteList(listId: list.id!, userId: userA.id!)
    let remainingItemCount = try dbQueue.read { db in
        try CollaborativeItem.filter(CollaborativeItem.Columns.listId == list.id!).fetchCount(db)
    }
    check("deleting a collaborative list cascades its items", remainingItemCount == 0)
}

do {
    let dbQueue = try freshDatabase()
    let userA = try insertUser(dbQueue, email: "a@example.com")
    try insertUser(dbQueue, email: "b@example.com")
    let repo = CollaborativeListRepository(dbWriter: dbQueue)
    let list = try repo.createList(currentUserId: userA.id!, partnerEmail: "b@example.com", name: "Vacation")
    let photoData = Data([0xFF, 0xD8, 0xFF, 0xD9])

    let item = try repo.addItem(
        listId: list.id!, userId: userA.id!, productName: "Sunscreen",
        price: 12.5, quantity: 2, url: "https://example.com/sunscreen", imageData: photoData
    )
    check("collaborative addItem stores the fetched product image", item.imageData == photoData)

    let refetched = try repo.items(listId: list.id!, userId: userA.id!, purchased: false).first
    check("collaborative product image persists to the database", refetched?.imageData == photoData)
}

// MARK: - DatabaseManager path resolution

section("DatabaseManager")
do {
    let overridePath = FileManager.default.temporaryDirectory
        .appendingPathComponent("ourwish-smoketest-\(UUID().uuidString).db").path
    let resolved = try DatabaseManager.resolveDatabaseURL(environment: ["OURWISH_DB_PATH": overridePath])
    check("OURWISH_DB_PATH override is respected", resolved.path == overridePath)

    let resolvedDefault = try DatabaseManager.resolveDatabaseURL(environment: [:])
    check(
        "default path lives under Application Support/OurWish/ourwish.db",
        resolvedDefault.path.hasSuffix("Application Support/OurWish/ourwish.db")
    )
}

// MARK: - AuthStore

section("AuthStore")
do {
    let service = FakeAuthStoreService()
    await service.seedUser(email: "a@example.com", password: "secret123")
    let store = AuthStore(service: service)

    try await store.login(email: "a@example.com", password: "secret123")
    check("login sets currentUser", store.currentUser?.email == "a@example.com")

    var wrongPasswordThrew = false
    do {
        try await store.login(email: "a@example.com", password: "wrong")
    } catch {
        wrongPasswordThrew = true
    }
    check("login throws on wrong password", wrongPasswordThrew)

    try await store.register(firstName: "Jamie", lastName: "Lee", email: "b@example.com", password: "secret123")
    let userCountAfterRegister = try await service.userCount()
    check("register adds a new user", userCountAfterRegister == 2)

    await store.logout()
    check("logout clears currentUser", store.currentUser == nil)
    let logoutCallCount = await service.logoutCallCount
    check("logout calls the service", logoutCallCount == 1)
}

// MARK: - WishListStore

section("WishListStore")
do {
    let service = FakeWishListStoreService()
    let store = WishListStore(service: service)

    store.setCurrentUser(1)
    try await store.createList(name: "Groceries")
    check(
        "createList adds and selects the new list",
        store.wishLists.map(\.name) == ["Groceries"] && store.selectedListId == store.wishLists.first?.id
    )

    try await store.addItem(productName: "Milk", price: 3.5, quantity: 2, url: nil)
    check("addItem appears in items", store.items.map(\.productName) == ["Milk"])

    if let itemId = store.items.first?.id {
        try await store.setPurchased(itemId, isPurchased: true)
        check(
            "setPurchased moves the item to purchasedItems",
            store.items.isEmpty && store.purchasedItems.count == 1
        )

        try await store.deleteItem(itemId)
        check("deleteItem removes it", store.purchasedItems.isEmpty)
    } else {
        check("addItem produced an item to continue testing with", false)
    }

    await service.setError(FakeServiceError(message: "boom"))
    store.setCurrentUser(2)
    try? await Task.sleep(for: .milliseconds(100))
    check("service failures during refresh surface via lastError", store.lastError == "boom")
}

// MARK: - CollaborativeStore

section("CollaborativeStore")
do {
    let service = FakeCollaborativeStoreService()
    await service.seedPartner(
        User(id: 2, firstName: "Bailey", lastName: "User", displayName: "Bailey", email: "b@example.com", passwordHash: "")
    )
    let store = CollaborativeStore(service: service)

    store.setCurrentUser(1)
    try await store.createList(partnerEmail: "b@example.com", name: "Vacation")
    check(
        "createList adds and selects the new list",
        store.lists.map(\.name) == ["Vacation"] && store.selectedListId == store.lists.first?.id
    )

    try await store.addItem(productName: "Sunscreen", price: 12.5, quantity: 1, url: nil)
    check("addItem appears in items", store.items.map(\.productName) == ["Sunscreen"])

    if let itemId = store.items.first?.id {
        try await store.setPurchased(itemId, isPurchased: true)
        check(
            "setPurchased moves the item to purchasedItems",
            store.items.isEmpty && store.purchasedItems.count == 1
        )
    } else {
        check("addItem produced an item to continue testing with", false)
    }

    await service.setError(FakeServiceError(message: "boom"))
    store.setCurrentUser(3)
    try? await Task.sleep(for: .milliseconds(100))
    check("service failures during refresh surface via lastError", store.lastError == "boom")
}

// MARK: - Summary

print("\n---")
if failureCount == 0 {
    print("All checks passed.")
} else {
    print("\(failureCount) check(s) FAILED.")
    exit(1)
}
