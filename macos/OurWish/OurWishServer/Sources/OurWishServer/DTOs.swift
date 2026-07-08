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

struct ItemDTO: Codable, ResponseEncodable {
    let id: Int64
    let productName: String
    let category: String?
    let manufacturer: String?
    let price: Double
    let msrp: Double?
    let quantity: Int
    let url: String?
    let officialProductURL: String?
    let bestRetailerURL: String?
    let primaryImageURL: String?
    let itemDescription: String?
    let specifications: String?
    let weight: String?
    let caliber: String?
    let compatibility: String?
    let purpose: String?
    let notes: String?
    let availabilityStatus: String?
    let dateRetrieved: Date?
    let isPurchased: Bool
    let isHidden: Bool
    let imageURL: String?

    init(_ item: WishListItem) {
        id = item.id!
        productName = item.productName
        category = item.category
        manufacturer = item.manufacturer
        price = item.price
        msrp = item.msrp
        quantity = item.quantity
        url = item.url
        officialProductURL = item.officialProductURL
        bestRetailerURL = item.bestRetailerURL
        primaryImageURL = item.primaryImageURL
        itemDescription = item.itemDescription
        specifications = item.specifications
        weight = item.weight
        caliber = item.caliber
        compatibility = item.compatibility
        purpose = item.purpose
        notes = item.notes
        availabilityStatus = item.availabilityStatus
        dateRetrieved = item.dateRetrieved
        isPurchased = item.isPurchased
        isHidden = item.isHidden
        imageURL = item.imageData != nil ? "/api/v1/items/\(item.id!)/image" : nil
    }

    init(_ item: CollaborativeItem) {
        id = item.id!
        productName = item.productName
        category = nil
        manufacturer = nil
        price = item.price
        msrp = nil
        quantity = item.quantity
        url = item.url
        officialProductURL = nil
        bestRetailerURL = nil
        primaryImageURL = nil
        itemDescription = nil
        specifications = nil
        weight = nil
        caliber = nil
        compatibility = nil
        purpose = nil
        notes = nil
        availabilityStatus = nil
        dateRetrieved = nil
        isPurchased = item.isPurchased
        isHidden = false
        imageURL = item.imageData != nil ? "/api/v1/collaborative-items/\(item.id!)/image" : nil
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
