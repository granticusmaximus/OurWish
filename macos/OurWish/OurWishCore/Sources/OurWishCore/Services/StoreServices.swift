import Foundation

public protocol AuthStoreService: Sendable {
    func userCount() async throws -> Int
    func login(email: String, password: String) async throws -> User
    func logout() async throws
    func register(firstName: String, lastName: String, email: String, password: String) async throws
    func updateProfile(
        userId: Int64,
        firstName: String,
        lastName: String,
        displayName: String,
        bio: String?,
        profileImageData: Data?
    ) async throws -> User
    func changePassword(userId: Int64, currentPassword: String, newPassword: String) async throws
}

public protocol WishListStoreService: Sendable {
    func wishLists(for userId: Int64) async throws -> [WishList]
    func createWishList(userId: Int64, name: String) async throws -> WishList
    func renameWishList(listId: Int64, userId: Int64, name: String) async throws
    func deleteWishList(listId: Int64, userId: Int64) async throws
    func wishListItems(listId: Int64, userId: Int64, purchased: Bool) async throws -> [WishListItem]
    func addWishListItem(
        listId: Int64,
        userId: Int64,
        productName: String,
        price: Double,
        quantity: Int,
        url: String?,
        imageData: Data?,
        metadata: WishListItemMetadata
    ) async throws -> WishListItem
    func updateWishListItem(
        itemId: Int64,
        userId: Int64,
        productName: String,
        price: Double,
        quantity: Int,
        url: String?,
        metadata: WishListItemMetadata
    ) async throws
    func setWishListItemPurchased(itemId: Int64, userId: Int64, isPurchased: Bool) async throws
    func setWishListItemHidden(itemId: Int64, userId: Int64, isHidden: Bool) async throws
    func deleteWishListItem(itemId: Int64, userId: Int64) async throws
}

public protocol CollaborativeStoreService: Sendable {
    func partners(excluding userId: Int64) async throws -> [User]
    func collaborativeLists(for userId: Int64) async throws -> [CollaborativeListWithPartner]
    func createCollaborativeList(currentUserId: Int64, partnerEmail: String, name: String) async throws -> CollaborativeList
    func deleteCollaborativeList(listId: Int64, userId: Int64) async throws
    func collaborativeItems(listId: Int64, userId: Int64, purchased: Bool) async throws -> [CollaborativeItem]
    func addCollaborativeItem(
        listId: Int64,
        userId: Int64,
        productName: String,
        price: Double,
        quantity: Int,
        url: String?,
        imageData: Data?
    ) async throws -> CollaborativeItem
    func updateCollaborativeItem(
        itemId: Int64,
        listId: Int64,
        userId: Int64,
        productName: String,
        price: Double,
        quantity: Int,
        url: String?
    ) async throws
    func setCollaborativeItemPurchased(itemId: Int64, listId: Int64, userId: Int64, isPurchased: Bool) async throws
    func deleteCollaborativeItem(itemId: Int64, listId: Int64, userId: Int64) async throws
}
