import GRDB
import Testing
@testable import OurWishCore

struct CollaborativeListRepositoryTests {
    @Test func createListRejectsSelfCollaboration() throws {
        let dbQueue = try TestSupport.makeMigratedDatabase()
        let user = try TestSupport.insertUser(dbQueue, email: "a@example.com")
        let repository = CollaborativeListRepository(dbWriter: dbQueue)

        #expect(throws: RepositoryError.cannotCollaborateWithSelf) {
            try repository.createList(currentUserId: user.id!, partnerEmail: "a@example.com", name: "Shared")
        }
    }

    @Test func createListFailsWhenPartnerNotFound() throws {
        let dbQueue = try TestSupport.makeMigratedDatabase()
        let user = try TestSupport.insertUser(dbQueue, email: "a@example.com")
        let repository = CollaborativeListRepository(dbWriter: dbQueue)

        #expect(throws: RepositoryError.partnerNotFound) {
            try repository.createList(currentUserId: user.id!, partnerEmail: "ghost@example.com", name: "Shared")
        }
    }

    @Test func listsQueryReturnsPartnerNameForBothParticipants() throws {
        let dbQueue = try TestSupport.makeMigratedDatabase()
        let userA = try TestSupport.insertUser(dbQueue, firstName: "Alex", email: "a@example.com")
        let userB = try TestSupport.insertUser(dbQueue, firstName: "Bailey", email: "b@example.com")
        let repository = CollaborativeListRepository(dbWriter: dbQueue)

        try repository.createList(currentUserId: userA.id!, partnerEmail: "b@example.com", name: "Vacation")

        let fromA = try repository.lists(for: userA.id!)
        #expect(fromA.map(\.partnerName) == ["Bailey"])

        let fromB = try repository.lists(for: userB.id!)
        #expect(fromB.map(\.partnerName) == ["Alex"])
    }

    @Test func itemCrudRoundTrips() throws {
        let dbQueue = try TestSupport.makeMigratedDatabase()
        let userA = try TestSupport.insertUser(dbQueue, email: "a@example.com")
        try TestSupport.insertUser(dbQueue, email: "b@example.com")
        let repository = CollaborativeListRepository(dbWriter: dbQueue)
        let list = try repository.createList(currentUserId: userA.id!, partnerEmail: "b@example.com", name: "Vacation")

        let item = try repository.addItem(
            listId: list.id!, userId: userA.id!, productName: "Sunscreen", price: 12.5, quantity: 2, url: nil
        )
        #expect(try repository.items(listId: list.id!, userId: userA.id!, purchased: false).count == 1)

        try repository.setPurchased(itemId: item.id!, listId: list.id!, userId: userA.id!, isPurchased: true)
        #expect(try repository.items(listId: list.id!, userId: userA.id!, purchased: true).count == 1)

        try repository.deleteItem(itemId: item.id!, listId: list.id!, userId: userA.id!)
        #expect(try repository.items(listId: list.id!, userId: userA.id!, purchased: true).count == 0)
    }

    @Test func deletingListCascadesItems() throws {
        let dbQueue = try TestSupport.makeMigratedDatabase()
        let userA = try TestSupport.insertUser(dbQueue, email: "a@example.com")
        try TestSupport.insertUser(dbQueue, email: "b@example.com")
        let repository = CollaborativeListRepository(dbWriter: dbQueue)
        let list = try repository.createList(currentUserId: userA.id!, partnerEmail: "b@example.com", name: "Vacation")
        try repository.addItem(listId: list.id!, userId: userA.id!, productName: "Sunscreen", price: 12.5, quantity: 1, url: nil)

        try repository.deleteList(listId: list.id!, userId: userA.id!)

        let remainingItemCount = try dbQueue.read { db in
            try CollaborativeItem.filter(CollaborativeItem.Columns.listId == list.id!).fetchCount(db)
        }
        #expect(remainingItemCount == 0)
    }
}
