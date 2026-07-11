import Foundation
import GRDB

public struct WishListItemMetadata: Equatable, Sendable {
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

    public static let empty = WishListItemMetadata()

    public init(
        category: String? = nil,
        manufacturer: String? = nil,
        msrp: Double? = nil,
        officialProductURL: String? = nil,
        bestRetailerURL: String? = nil,
        primaryImageURL: String? = nil,
        itemDescription: String? = nil,
        specifications: String? = nil,
        weight: String? = nil,
        caliber: String? = nil,
        compatibility: String? = nil,
        purpose: String? = nil,
        notes: String? = nil,
        availabilityStatus: String? = nil,
        dateRetrieved: Date? = nil
    ) {
        self.category = category
        self.manufacturer = manufacturer
        self.msrp = msrp
        self.officialProductURL = officialProductURL
        self.bestRetailerURL = bestRetailerURL
        self.primaryImageURL = primaryImageURL
        self.itemDescription = itemDescription
        self.specifications = specifications
        self.weight = weight
        self.caliber = caliber
        self.compatibility = compatibility
        self.purpose = purpose
        self.notes = notes
        self.availabilityStatus = availabilityStatus
        self.dateRetrieved = dateRetrieved
    }
}

/// `WishListItemMetadata` is deliberately the single place that knows how these fields
/// are represented as flat JSON — the server's `ItemDTO`/`CreateItemRequest`/
/// `UpdateItemRequest` and the remote client's item type all hold a `metadata` property
/// and delegate to this conformance (decoding/encoding it against the *same* top-level
/// decoder/encoder as their own scalar fields) instead of each re-declaring all 15
/// fields themselves.
extension WishListItemMetadata: Codable {
    /// Canonical "yyyy-MM-dd" formatter for `dateRetrieved` on the wire — shared so the
    /// client and server don't each keep a private copy that can drift. Decoding also
    /// tolerates ISO 8601 for values a previous encoding produced.
    public static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private enum CodingKeys: String, CodingKey {
        case category, manufacturer, msrp, officialProductURL, bestRetailerURL, primaryImageURL
        case itemDescription, specifications, weight, caliber, compatibility, purpose, notes
        case availabilityStatus, dateRetrieved
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        manufacturer = try container.decodeIfPresent(String.self, forKey: .manufacturer)
        msrp = try container.decodeIfPresent(Double.self, forKey: .msrp)
        officialProductURL = try container.decodeIfPresent(String.self, forKey: .officialProductURL)
        bestRetailerURL = try container.decodeIfPresent(String.self, forKey: .bestRetailerURL)
        primaryImageURL = try container.decodeIfPresent(String.self, forKey: .primaryImageURL)
        itemDescription = try container.decodeIfPresent(String.self, forKey: .itemDescription)
        specifications = try container.decodeIfPresent(String.self, forKey: .specifications)
        weight = try container.decodeIfPresent(String.self, forKey: .weight)
        caliber = try container.decodeIfPresent(String.self, forKey: .caliber)
        compatibility = try container.decodeIfPresent(String.self, forKey: .compatibility)
        purpose = try container.decodeIfPresent(String.self, forKey: .purpose)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        availabilityStatus = try container.decodeIfPresent(String.self, forKey: .availabilityStatus)
        if let raw = try container.decodeIfPresent(String.self, forKey: .dateRetrieved) {
            dateRetrieved = Self.dateOnlyFormatter.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
        } else {
            dateRetrieved = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(category, forKey: .category)
        try container.encodeIfPresent(manufacturer, forKey: .manufacturer)
        try container.encodeIfPresent(msrp, forKey: .msrp)
        try container.encodeIfPresent(officialProductURL, forKey: .officialProductURL)
        try container.encodeIfPresent(bestRetailerURL, forKey: .bestRetailerURL)
        try container.encodeIfPresent(primaryImageURL, forKey: .primaryImageURL)
        try container.encodeIfPresent(itemDescription, forKey: .itemDescription)
        try container.encodeIfPresent(specifications, forKey: .specifications)
        try container.encodeIfPresent(weight, forKey: .weight)
        try container.encodeIfPresent(caliber, forKey: .caliber)
        try container.encodeIfPresent(compatibility, forKey: .compatibility)
        try container.encodeIfPresent(purpose, forKey: .purpose)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(availabilityStatus, forKey: .availabilityStatus)
        try container.encodeIfPresent(dateRetrieved.map { Self.dateOnlyFormatter.string(from: $0) }, forKey: .dateRetrieved)
    }
}

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
        metadata: WishListItemMetadata = .empty,
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
