import Foundation
import GRDB

public struct CollaborativeList: Codable, Identifiable, Equatable, Sendable {
    public var id: Int64?
    public var name: String
    public var user1Id: Int64
    public var user2Id: Int64
    public var createdAt: Date

    public init(
        id: Int64? = nil,
        name: String,
        user1Id: Int64,
        user2Id: Int64,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.user1Id = user1Id
        self.user2Id = user2Id
        self.createdAt = createdAt
    }
}

extension CollaborativeList {
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case user1Id = "user1_id"
        case user2Id = "user2_id"
        case createdAt = "created_at"
    }
}

extension CollaborativeList: FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "collaborative_lists"

    public enum Columns {
        public static let id = Column(CodingKeys.id)
        public static let user1Id = Column(CodingKeys.user1Id)
        public static let user2Id = Column(CodingKeys.user2Id)
    }

    public mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

/// Read-only join of a collaborative list with the *other* participant's display name,
/// mirroring the `CASE WHEN cl.user1_id = ? THEN u2.display_name ELSE u1.display_name END`
/// query in the original server's `/collaborative/lists` handler.
public struct CollaborativeListWithPartner: Codable, Identifiable, Equatable, Sendable, FetchableRecord {
    public var id: Int64
    public var name: String
    public var user1Id: Int64
    public var user2Id: Int64
    public var partnerName: String

    public init(id: Int64, name: String, user1Id: Int64, user2Id: Int64, partnerName: String) {
        self.id = id
        self.name = name
        self.user1Id = user1Id
        self.user2Id = user2Id
        self.partnerName = partnerName
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case user1Id = "user1_id"
        case user2Id = "user2_id"
        case partnerName = "partner_name"
    }
}
