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
    let price: Double
    let quantity: Int
    let url: String?
    let isPurchased: Bool
    let isHidden: Bool
    let imageURL: String?

    init(_ item: WishListItem) {
        id = item.id!
        productName = item.productName
        price = item.price
        quantity = item.quantity
        url = item.url
        isPurchased = item.isPurchased
        isHidden = item.isHidden
        imageURL = item.imageData != nil ? "/api/v1/items/\(item.id!)/image" : nil
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
