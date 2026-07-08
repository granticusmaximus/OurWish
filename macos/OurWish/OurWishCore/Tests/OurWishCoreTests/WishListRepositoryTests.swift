import GRDB
import Testing
@testable import OurWishCore

struct WishListRepositoryTests {
    @Test func cannotDeleteOnlyWishList() throws {
        let dbQueue = try TestSupport.makeMigratedDatabase()
        let user = try TestSupport.insertUser(dbQueue, email: "a@example.com")
        let repository = WishListRepository(dbWriter: dbQueue)
        let onlyList = try repository.createList(userId: user.id!, name: "My Wish List")

        #expect(throws: RepositoryError.cannotDeleteOnlyWishList) {
            try repository.deleteList(listId: onlyList.id!, userId: user.id!)
        }
    }

    @Test func canDeleteWishListWhenMultipleExist() throws {
        let dbQueue = try TestSupport.makeMigratedDatabase()
        let user = try TestSupport.insertUser(dbQueue, email: "a@example.com")
        let repository = WishListRepository(dbWriter: dbQueue)
        let first = try repository.createList(userId: user.id!, name: "First")
        _ = try repository.createList(userId: user.id!, name: "Second")

        try repository.deleteList(listId: first.id!, userId: user.id!)

        let remaining = try repository.lists(for: user.id!)
        #expect(remaining.map(\.name) == ["Second"])
    }

    @Test func addItemRejectsEmptyProductName() throws {
        let dbQueue = try TestSupport.makeMigratedDatabase()
        let user = try TestSupport.insertUser(dbQueue, email: "a@example.com")
        let repository = WishListRepository(dbWriter: dbQueue)
        let list = try repository.createList(userId: user.id!, name: "My Wish List")

        #expect(throws: (any Error).self) {
            try repository.addItem(listId: list.id!, userId: user.id!, productName: "  ", price: 10, quantity: 1, url: nil)
        }
    }

    @Test func addItemRejectsQuantityBelowOne() throws {
        let dbQueue = try TestSupport.makeMigratedDatabase()
        let user = try TestSupport.insertUser(dbQueue, email: "a@example.com")
        let repository = WishListRepository(dbWriter: dbQueue)
        let list = try repository.createList(userId: user.id!, name: "My Wish List")

        #expect(throws: (any Error).self) {
            try repository.addItem(listId: list.id!, userId: user.id!, productName: "Widget", price: 10, quantity: 0, url: nil)
        }
    }

    @Test func markPurchasedMovesItemBetweenActiveAndPurchasedQueries() throws {
        let dbQueue = try TestSupport.makeMigratedDatabase()
        let user = try TestSupport.insertUser(dbQueue, email: "a@example.com")
        let repository = WishListRepository(dbWriter: dbQueue)
        let list = try repository.createList(userId: user.id!, name: "My Wish List")
        let item = try repository.addItem(
            listId: list.id!, userId: user.id!, productName: "Widget", price: 9.99, quantity: 2, url: nil
        )

        #expect(try repository.items(listId: list.id!, userId: user.id!, purchased: false).count == 1)
        #expect(try repository.items(listId: list.id!, userId: user.id!, purchased: true).count == 0)

        try repository.setPurchased(itemId: item.id!, userId: user.id!, isPurchased: true)

        #expect(try repository.items(listId: list.id!, userId: user.id!, purchased: false).count == 0)
        #expect(try repository.items(listId: list.id!, userId: user.id!, purchased: true).count == 1)
    }

    @Test func ownershipIsEnforcedAcrossUsers() throws {
        let dbQueue = try TestSupport.makeMigratedDatabase()
        let userA = try TestSupport.insertUser(dbQueue, email: "a@example.com")
        let userB = try TestSupport.insertUser(dbQueue, email: "b@example.com")
        let repository = WishListRepository(dbWriter: dbQueue)
        let listA = try repository.createList(userId: userA.id!, name: "A's List")

        #expect(throws: RepositoryError.wishListNotFound) {
            try repository.addItem(listId: listA.id!, userId: userB.id!, productName: "Widget", price: 1, quantity: 1, url: nil)
        }
    }

    @Test func deleteItemRemovesIt() throws {
        let dbQueue = try TestSupport.makeMigratedDatabase()
        let user = try TestSupport.insertUser(dbQueue, email: "a@example.com")
        let repository = WishListRepository(dbWriter: dbQueue)
        let list = try repository.createList(userId: user.id!, name: "My Wish List")
        let item = try repository.addItem(
            listId: list.id!, userId: user.id!, productName: "Widget", price: 5, quantity: 1, url: nil
        )

        try repository.deleteItem(itemId: item.id!, userId: user.id!)

        #expect(try repository.items(listId: list.id!, userId: user.id!, purchased: false).count == 0)
    }
}
