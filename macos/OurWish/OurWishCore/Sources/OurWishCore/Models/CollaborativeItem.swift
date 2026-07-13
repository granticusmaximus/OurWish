import Foundation
import GRDB

public struct CollaborativeItem: Codable, Identifiable, Equatable, Sendable {
    public var id: Int64?
    public var listId: Int64
    public var productName: String
    public var price: Double
    public var quantity: Int
    public var url: String?
    public var isPurchased: Bool
    public var isHidden: Bool
    public var imageData: Data?
    public var category: String?
    public var manufacturer: String?
    public var msrp: Double?
    public var officialProductURL: String?
    public var bestRetailerURL: String?
    public var primaryImageURL: String?
    public var itemDescription: String?
    public var specifications: String?
    public var weight: String?
    public var caliber: String?
    public var compatibility: String?
    public var purpose: String?
    public var notes: String?
    public var availabilityStatus: String?
    public var dateRetrieved: Date?
    /// Explicit manual ordering within the list, ascending. Deliberately never
    /// surfaced over the wire (no DTO/PWA field) — order is implicit in the array
    /// position of a `GET .../items` response instead. See
    /// `CollaborativeListRepository`'s `reorderItems`.
    public var sortOrder: Int64
    public var createdAt: Date

    public init(
        id: Int64? = nil,
        listId: Int64,
        productName: String,
        price: Double,
        quantity: Int = 1,
        url: String? = nil,
        isPurchased: Bool = false,
        isHidden: Bool = false,
        imageData: Data? = nil,
        metadata: WishListItemMetadata = .empty,
        sortOrder: Int64 = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.listId = listId
        self.productName = productName
        self.price = price
        self.quantity = quantity
        self.url = url
        self.isPurchased = isPurchased
        self.isHidden = isHidden
        self.imageData = imageData
        self.sortOrder = sortOrder
        self.category = metadata.category
        self.manufacturer = metadata.manufacturer
        self.msrp = metadata.msrp
        self.officialProductURL = metadata.officialProductURL
        self.bestRetailerURL = metadata.bestRetailerURL
        self.primaryImageURL = metadata.primaryImageURL
        self.itemDescription = metadata.itemDescription
        self.specifications = metadata.specifications
        self.weight = metadata.weight
        self.caliber = metadata.caliber
        self.compatibility = metadata.compatibility
        self.purpose = metadata.purpose
        self.notes = metadata.notes
        self.availabilityStatus = metadata.availabilityStatus
        self.dateRetrieved = metadata.dateRetrieved
        self.createdAt = createdAt
    }

    public var lineTotal: Double { price * Double(quantity) }

    public var metadata: WishListItemMetadata {
        WishListItemMetadata(
            category: category,
            manufacturer: manufacturer,
            msrp: msrp,
            officialProductURL: officialProductURL,
            bestRetailerURL: bestRetailerURL,
            primaryImageURL: primaryImageURL,
            itemDescription: itemDescription,
            specifications: specifications,
            weight: weight,
            caliber: caliber,
            compatibility: compatibility,
            purpose: purpose,
            notes: notes,
            availabilityStatus: availabilityStatus,
            dateRetrieved: dateRetrieved
        )
    }
}

extension CollaborativeItem {
    enum CodingKeys: String, CodingKey {
        case id
        case listId = "list_id"
        case productName = "product_name"
        case price
        case quantity
        case url
        case isPurchased = "is_purchased"
        case isHidden = "is_hidden"
        case imageData = "image_data"
        case category
        case manufacturer
        case msrp
        case officialProductURL = "official_product_url"
        case bestRetailerURL = "best_retailer_url"
        case primaryImageURL = "primary_image_url"
        case itemDescription = "item_description"
        case specifications
        case weight
        case caliber
        case compatibility
        case purpose
        case notes
        case availabilityStatus = "availability_status"
        case dateRetrieved = "date_retrieved"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
    }
}

extension CollaborativeItem: FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "collaborative_items"

    public enum Columns {
        public static let id = Column(CodingKeys.id)
        public static let listId = Column(CodingKeys.listId)
        public static let isPurchased = Column(CodingKeys.isPurchased)
    }

    public mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
