import Foundation
import GRDB

public struct WishListItem: Codable, Identifiable, Equatable, Sendable {
    public var id: Int64?
    public var userId: Int64
    public var listId: Int64
    public var productName: String
    public var price: Double
    public var quantity: Int
    public var url: String?
    public var isPurchased: Bool
    public var isHidden: Bool
    public var imageData: Data?
    public var createdAt: Date

    public init(
        id: Int64? = nil,
        userId: Int64,
        listId: Int64,
        productName: String,
        price: Double,
        quantity: Int = 1,
        url: String? = nil,
        isPurchased: Bool = false,
        isHidden: Bool = false,
        imageData: Data? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.listId = listId
        self.productName = productName
        self.price = price
        self.quantity = quantity
        self.url = url
        self.isPurchased = isPurchased
        self.isHidden = isHidden
        self.imageData = imageData
        self.createdAt = createdAt
    }

    public var lineTotal: Double { price * Double(quantity) }
}

extension WishListItem {
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case listId = "list_id"
        case productName = "product_name"
        case price
        case quantity
        case url
        case isPurchased = "is_purchased"
        case isHidden = "is_hidden"
        case imageData = "image_data"
        case createdAt = "created_at"
    }
}

extension WishListItem: FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "wish_list_items"

    public enum Columns {
        public static let id = Column(CodingKeys.id)
        public static let userId = Column(CodingKeys.userId)
        public static let listId = Column(CodingKeys.listId)
        public static let isPurchased = Column(CodingKeys.isPurchased)
    }

    public mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
