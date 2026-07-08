import Foundation
import GRDB

public struct User: Codable, Identifiable, Equatable, Sendable {
    public var id: Int64?
    public var firstName: String
    public var lastName: String
    public var displayName: String
    public var email: String
    public var passwordHash: String
    public var wishListName: String
    public var createdAt: Date

    public init(
        id: Int64? = nil,
        firstName: String,
        lastName: String,
        displayName: String,
        email: String,
        passwordHash: String,
        wishListName: String = "My Wish List",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.displayName = displayName
        self.email = email
        self.passwordHash = passwordHash
        self.wishListName = wishListName
        self.createdAt = createdAt
    }
}

extension User {
    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case displayName = "display_name"
        case email
        case passwordHash = "password_hash"
        case wishListName = "wish_list_name"
        case createdAt = "created_at"
    }
}

extension User: FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "users"

    public enum Columns {
        public static let id = Column(CodingKeys.id)
        public static let email = Column(CodingKeys.email)
    }

    public mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
