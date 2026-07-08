import Foundation
import GRDB

public struct WishList: Codable, Identifiable, Equatable, Sendable {
    public var id: Int64?
    public var userId: Int64
    public var name: String
    public var createdAt: Date

    public init(id: Int64? = nil, userId: Int64, name: String, createdAt: Date = Date()) {
        self.id = id
        self.userId = userId
        self.name = name
        self.createdAt = createdAt
    }
}

extension WishList {
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case createdAt = "created_at"
    }
}

extension WishList: FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "wish_lists"

    public enum Columns {
        public static let id = Column(CodingKeys.id)
        public static let userId = Column(CodingKeys.userId)
    }

    public mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
