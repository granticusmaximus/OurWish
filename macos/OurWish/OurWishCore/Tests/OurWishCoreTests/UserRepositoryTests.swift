import GRDB
import Testing
@testable import OurWishCore

struct UserRepositoryTests {
    @Test func loginSucceedsWithCorrectCredentials() throws {
        let dbQueue = try TestSupport.makeMigratedDatabase()
        try TestSupport.insertUser(dbQueue, email: "a@example.com", password: "secret123")
        let repository = UserRepository(dbWriter: dbQueue)

        let user = try repository.login(email: "a@example.com", password: "secret123")
        #expect(user.email == "a@example.com")
    }

    @Test func loginIsCaseInsensitiveOnEmail() throws {
        let dbQueue = try TestSupport.makeMigratedDatabase()
        try TestSupport.insertUser(dbQueue, email: "a@example.com", password: "secret123")
        let repository = UserRepository(dbWriter: dbQueue)

        let user = try repository.login(email: "A@EXAMPLE.com", password: "secret123")
        #expect(user.email == "a@example.com")
    }

    @Test func loginFailsWithWrongPassword() throws {
        let dbQueue = try TestSupport.makeMigratedDatabase()
        try TestSupport.insertUser(dbQueue, email: "a@example.com", password: "secret123")
        let repository = UserRepository(dbWriter: dbQueue)

        #expect(throws: RepositoryError.invalidCredentials) {
            try repository.login(email: "a@example.com", password: "wrong")
        }
    }

    @Test func loginFailsForUnknownEmail() throws {
        let dbQueue = try TestSupport.makeMigratedDatabase()
        let repository = UserRepository(dbWriter: dbQueue)

        #expect(throws: RepositoryError.invalidCredentials) {
            try repository.login(email: "nobody@example.com", password: "secret123")
        }
    }

    @Test func createUserSeedsDefaultWishList() throws {
        let dbQueue = try TestSupport.makeMigratedDatabase()
        let repository = UserRepository(dbWriter: dbQueue)

        let user = try repository.createUser(
            firstName: "Jamie", lastName: "Lee", email: "jamie@example.com", password: "secret123"
        )

        let lists = try dbQueue.read { db in
            try WishList.filter(WishList.Columns.userId == user.id!).fetchAll(db)
        }
        #expect(lists.count == 1)
        #expect(lists.first?.name == "My Wish List")
    }

    @Test func createUserEnforcesMaxUsersCap() throws {
        let dbQueue = try TestSupport.makeMigratedDatabase()
        let repository = UserRepository(dbWriter: dbQueue)

        try repository.createUser(firstName: "One", lastName: "User", email: "one@example.com", password: "secret123")
        try repository.createUser(firstName: "Two", lastName: "User", email: "two@example.com", password: "secret123")

        #expect(throws: RepositoryError.userLimitReached(max: 2)) {
            try repository.createUser(firstName: "Three", lastName: "User", email: "three@example.com", password: "secret123")
        }
    }

    @Test func createUserRejectsDuplicateEmailCaseInsensitive() throws {
        let dbQueue = try TestSupport.makeMigratedDatabase()
        let repository = UserRepository(dbWriter: dbQueue)

        try repository.createUser(firstName: "One", lastName: "User", email: "dup@example.com", password: "secret123")

        #expect(throws: RepositoryError.emailAlreadyExists) {
            try repository.createUser(firstName: "Two", lastName: "User", email: "DUP@example.com", password: "secret123")
        }
    }

    @Test func partnersExcludesSelf() throws {
        let dbQueue = try TestSupport.makeMigratedDatabase()
        let userA = try TestSupport.insertUser(dbQueue, email: "a@example.com")
        try TestSupport.insertUser(dbQueue, email: "b@example.com")
        let repository = UserRepository(dbWriter: dbQueue)

        let partners = try repository.partners(excluding: userA.id!)
        #expect(partners.map(\.email) == ["b@example.com"])
    }
}
