import Foundation
import Hummingbird
import OurWishCore

/// Explicit `Codable` response types mapping from `OurWishCore` models. Deliberately
/// never carry `passwordHash` or raw `imageData` — the models could stay entirely
/// in-process when only the SwiftUI app read them, but the server is a real trust
/// boundary now (see the plan's note on LAN reachability).

struct UserDTO: Codable, ResponseEncodable {
    let id: Int64
    let firstName: String
    let lastName: String
    let displayName: String
    let email: String
    let bio: String?
    let imageURL: String?

    init(_ user: User) {
        id = user.id!
        firstName = user.firstName
        lastName = user.lastName
        displayName = user.displayName
        email = user.email
        bio = user.bio
        imageURL = user.profileImageData != nil ? "/api/v1/users/\(user.id!)/image" : nil
    }
}

struct LoginResponseDTO: Codable, ResponseEncodable {
    let token: String
    let user: UserDTO
}

struct UserCountDTO: Codable, ResponseEncodable {
    let count: Int
}

struct WishListDTO: Codable, ResponseEncodable {
    let id: Int64
    let name: String

    init(_ list: WishList) {
        id = list.id!
        name = list.name
    }
}

/// Holds the item's metadata fields as a single `WishListItemMetadata` rather than 15
/// loose properties, flattened into the same JSON object on encode (see
/// `WishListItemMetadata`'s own `Codable` conformance) — one field list to maintain,
/// shared with `CreateItemRequest`/`UpdateItemRequest`, with no change to the wire
/// format. Only `Encodable` since nothing ever decodes a response DTO.
struct ItemDTO: Encodable, ResponseEncodable {
    let id: Int64
    let productName: String
    let price: Double
    let quantity: Int
    let url: String?
    let isPurchased: Bool
    let isHidden: Bool
    let imageURL: String?
    let metadata: WishListItemMetadata

    private enum CodingKeys: String, CodingKey {
        case id, productName, price, quantity, url, isPurchased, isHidden, imageURL
    }

    init(_ item: WishListItem) {
        id = item.id!
        productName = item.productName
        price = item.price
        quantity = item.quantity
        url = item.url
        isPurchased = item.isPurchased
        isHidden = item.isHidden
        imageURL = item.imageData != nil ? "/api/v1/items/\(item.id!)/image" : nil
        metadata = item.metadata
    }

    init(_ item: CollaborativeItem) {
        id = item.id!
        productName = item.productName
        price = item.price
        quantity = item.quantity
        url = item.url
        isPurchased = item.isPurchased
        isHidden = false
        imageURL = item.imageData != nil ? "/api/v1/collaborative-items/\(item.id!)/image" : nil
        metadata = .empty
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(productName, forKey: .productName)
        try container.encode(price, forKey: .price)
        try container.encode(quantity, forKey: .quantity)
        try container.encodeIfPresent(url, forKey: .url)
        try container.encode(isPurchased, forKey: .isPurchased)
        try container.encode(isHidden, forKey: .isHidden)
        try container.encodeIfPresent(imageURL, forKey: .imageURL)
        try metadata.encode(to: encoder)
    }
}

struct CollaborativeListDTO: Codable, ResponseEncodable {
    let id: Int64
    let name: String
    let partnerName: String

    init(_ list: CollaborativeListWithPartner) {
        id = list.id
        name = list.name
        partnerName = list.partnerName
    }
}

struct PartnerDTO: Codable, ResponseEncodable {
    let email: String
    let displayName: String

    init(_ user: User) {
        email = user.email
        displayName = user.displayName
    }
}
