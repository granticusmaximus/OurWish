import Foundation
import GRDB

public struct LocalAuthStoreService: AuthStoreService {
    private let repository: UserRepository

    public init(dbWriter: any DatabaseWriter = DatabaseManager.shared) {
        self.repository = UserRepository(dbWriter: dbWriter)
    }

    public func userCount() async throws -> Int {
        try repository.count()
    }

    public func login(email: String, password: String) async throws -> User {
        try repository.login(email: email, password: password)
    }

    public func logout() async throws {}

    public func register(firstName: String, lastName: String, email: String, password: String) async throws {
        _ = try repository.createUser(firstName: firstName, lastName: lastName, email: email, password: password)
    }

    public func updateProfile(
        userId: Int64,
        firstName: String,
        lastName: String,
        displayName: String,
        email: String,
        bio: String?,
        profileImageData: Data?
    ) async throws -> User {
        try repository.updateProfile(
            userId: userId,
            firstName: firstName,
            lastName: lastName,
            displayName: displayName,
            email: email,
            bio: bio,
            profileImageData: profileImageData
        )
    }

    public func changePassword(userId: Int64, currentPassword: String, newPassword: String) async throws {
        try repository.updatePassword(userId: userId, currentPassword: currentPassword, newPassword: newPassword)
    }

    public func deleteAccount(userId: Int64) async throws {
        try repository.deleteUser(userId: userId)
    }
}

public struct LocalWishListStoreService: WishListStoreService {
    private let repository: WishListRepository

    public init(dbWriter: any DatabaseWriter = DatabaseManager.shared) {
        self.repository = WishListRepository(dbWriter: dbWriter)
    }

    public func wishLists(for userId: Int64) async throws -> [WishList] {
        try repository.lists(for: userId)
    }

    public func createWishList(userId: Int64, name: String) async throws -> WishList {
        try repository.createList(userId: userId, name: name)
    }

    public func renameWishList(listId: Int64, userId: Int64, name: String) async throws {
        try repository.renameList(listId: listId, userId: userId, name: name)
    }

    public func deleteWishList(listId: Int64, userId: Int64) async throws {
        try repository.deleteList(listId: listId, userId: userId)
    }

    public func wishListItems(listId: Int64, userId: Int64, purchased: Bool) async throws -> [WishListItem] {
        try repository.items(listId: listId, userId: userId, purchased: purchased)
    }

    public func addWishListItem(
        listId: Int64,
        userId: Int64,
        productName: String,
        price: Double,
        quantity: Int,
        url: String?,
        imageData: Data?,
        metadata: WishListItemMetadata
    ) async throws -> WishListItem {
        try repository.addItem(
            listId: listId,
            userId: userId,
            productName: productName,
            price: price,
            quantity: quantity,
            url: url,
            imageData: imageData,
            metadata: metadata
        )
    }

    public func updateWishListItem(
        itemId: Int64,
        userId: Int64,
        productName: String,
        price: Double,
        quantity: Int,
        url: String?,
        metadata: WishListItemMetadata
    ) async throws {
        try repository.updateItem(
            itemId: itemId,
            userId: userId,
            productName: productName,
            price: price,
            quantity: quantity,
            url: url,
            metadata: metadata
        )
    }

    public func setWishListItemPurchased(itemId: Int64, userId: Int64, isPurchased: Bool) async throws {
        try repository.setPurchased(itemId: itemId, userId: userId, isPurchased: isPurchased)
    }

    public func setWishListItemHidden(itemId: Int64, userId: Int64, isHidden: Bool) async throws {
        try repository.setHidden(itemId: itemId, userId: userId, isHidden: isHidden)
    }

    public func deleteWishListItem(itemId: Int64, userId: Int64) async throws {
        try repository.deleteItem(itemId: itemId, userId: userId)
    }
}

public struct LocalCollaborativeStoreService: CollaborativeStoreService {
    private let repository: CollaborativeListRepository
    private let userRepository: UserRepository

    public init(dbWriter: any DatabaseWriter = DatabaseManager.shared) {
        self.repository = CollaborativeListRepository(dbWriter: dbWriter)
        self.userRepository = UserRepository(dbWriter: dbWriter)
    }

    public func partners(excluding userId: Int64) async throws -> [User] {
        try userRepository.partners(excluding: userId)
    }

    public func collaborativeLists(for userId: Int64) async throws -> [CollaborativeListWithPartner] {
        try repository.lists(for: userId)
    }

    public func createCollaborativeList(currentUserId: Int64, partnerEmail: String, name: String) async throws -> CollaborativeList {
        try repository.createList(currentUserId: currentUserId, partnerEmail: partnerEmail, name: name)
    }

    public func deleteCollaborativeList(listId: Int64, userId: Int64) async throws {
        try repository.deleteList(listId: listId, userId: userId)
    }

    public func collaborativeItems(listId: Int64, userId: Int64, purchased: Bool) async throws -> [CollaborativeItem] {
        try repository.items(listId: listId, userId: userId, purchased: purchased)
    }

    public func addCollaborativeItem(
        listId: Int64,
        userId: Int64,
        productName: String,
        price: Double,
        quantity: Int,
        url: String?,
        imageData: Data?,
        metadata: WishListItemMetadata
    ) async throws -> CollaborativeItem {
        try repository.addItem(
            listId: listId,
            userId: userId,
            productName: productName,
            price: price,
            quantity: quantity,
            url: url,
            imageData: imageData,
            metadata: metadata
        )
    }

    public func updateCollaborativeItem(
        itemId: Int64,
        listId: Int64,
        userId: Int64,
        productName: String,
        price: Double,
        quantity: Int,
        url: String?,
        metadata: WishListItemMetadata
    ) async throws {
        try repository.updateItem(
            itemId: itemId,
            listId: listId,
            userId: userId,
            productName: productName,
            price: price,
            quantity: quantity,
            url: url,
            metadata: metadata
        )
    }

    public func setCollaborativeItemPurchased(itemId: Int64, listId: Int64, userId: Int64, isPurchased: Bool) async throws {
        try repository.setPurchased(itemId: itemId, listId: listId, userId: userId, isPurchased: isPurchased)
    }

    public func setCollaborativeItemHidden(itemId: Int64, listId: Int64, userId: Int64, isHidden: Bool) async throws {
        try repository.setHidden(itemId: itemId, listId: listId, userId: userId, isHidden: isHidden)
    }

    public func deleteCollaborativeItem(itemId: Int64, listId: Int64, userId: Int64) async throws {
        try repository.deleteItem(itemId: itemId, listId: listId, userId: userId)
    }
}
