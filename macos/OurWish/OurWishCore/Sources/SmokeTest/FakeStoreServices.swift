import Foundation
import OurWishCore

/// Minimal in-memory fakes for the `AuthStoreService`/`WishListStoreService`/
/// `CollaborativeStoreService` protocols, used only by the "Stores" section below. The
/// same protocol seam that lets the app swap `Local*`/`RemoteOurWishAPI` implementations
/// doubles as the seam for testing the `@Observable` stores without a real database or
/// HTTP server. Password fields here are stored raw (not hashed) — these are doubles,
/// not a security boundary; real hashing is covered by `UserRepositoryTests`.

struct FakeServiceError: LocalizedError, Equatable {
    let message: String
    var errorDescription: String? { message }
}

actor FakeAuthStoreService: AuthStoreService {
    private var users: [User] = []
    private var nextId: Int64 = 1
    private(set) var logoutCallCount = 0
    var errorToThrow: FakeServiceError?

    @discardableResult
    func seedUser(email: String, password: String, firstName: String = "Test") -> User {
        let user = User(id: nextId, firstName: firstName, lastName: "User", displayName: firstName, email: email, passwordHash: password)
        nextId += 1
        users.append(user)
        return user
    }

    func setError(_ error: FakeServiceError?) {
        errorToThrow = error
    }

    func userCount() async throws -> Int {
        if let errorToThrow { throw errorToThrow }
        return users.count
    }

    func login(email: String, password: String) async throws -> User {
        if let errorToThrow { throw errorToThrow }
        guard let user = users.first(where: { $0.email == email && $0.passwordHash == password }) else {
            throw FakeServiceError(message: "Invalid email or password")
        }
        return user
    }

    func logout() async throws {
        if let errorToThrow { throw errorToThrow }
        logoutCallCount += 1
    }

    func register(firstName: String, lastName: String, email: String, password: String) async throws {
        if let errorToThrow { throw errorToThrow }
        users.append(User(id: nextId, firstName: firstName, lastName: lastName, displayName: firstName, email: email, passwordHash: password))
        nextId += 1
    }

    func updateProfile(
        userId: Int64, firstName: String, lastName: String, displayName: String, email: String,
        bio: String?, profileImageData: Data?
    ) async throws -> User {
        if let errorToThrow { throw errorToThrow }
        guard let index = users.firstIndex(where: { $0.id == userId }) else {
            throw FakeServiceError(message: "User not found")
        }
        users[index].firstName = firstName
        users[index].lastName = lastName
        users[index].displayName = displayName
        users[index].email = email
        users[index].bio = bio
        users[index].profileImageData = profileImageData
        return users[index]
    }

    func changePassword(userId: Int64, currentPassword: String, newPassword: String) async throws {
        if let errorToThrow { throw errorToThrow }
    }

    func deleteAccount(userId: Int64) async throws {
        if let errorToThrow { throw errorToThrow }
        users.removeAll { $0.id == userId }
    }
}

actor FakeWishListStoreService: WishListStoreService {
    private var lists: [WishList] = []
    private var items: [WishListItem] = []
    private var nextListId: Int64 = 1
    private var nextItemId: Int64 = 1
    var errorToThrow: FakeServiceError?

    func setError(_ error: FakeServiceError?) {
        errorToThrow = error
    }

    func wishLists(for userId: Int64) async throws -> [WishList] {
        if let errorToThrow { throw errorToThrow }
        return lists.filter { $0.userId == userId }
    }

    func createWishList(userId: Int64, name: String) async throws -> WishList {
        if let errorToThrow { throw errorToThrow }
        let list = WishList(id: nextListId, userId: userId, name: name)
        nextListId += 1
        lists.append(list)
        return list
    }

    func renameWishList(listId: Int64, userId: Int64, name: String) async throws {
        if let errorToThrow { throw errorToThrow }
        guard let index = lists.firstIndex(where: { $0.id == listId }) else { return }
        lists[index].name = name
    }

    func deleteWishList(listId: Int64, userId: Int64) async throws {
        if let errorToThrow { throw errorToThrow }
        lists.removeAll { $0.id == listId }
        items.removeAll { $0.listId == listId }
    }

    func wishListItems(listId: Int64, userId: Int64, purchased: Bool) async throws -> [WishListItem] {
        if let errorToThrow { throw errorToThrow }
        return items.filter { $0.listId == listId && $0.isPurchased == purchased }
    }

    func addWishListItem(
        listId: Int64, userId: Int64, productName: String, price: Double, quantity: Int,
        url: String?, imageData: Data?, metadata: WishListItemMetadata
    ) async throws -> WishListItem {
        if let errorToThrow { throw errorToThrow }
        let item = WishListItem(
            id: nextItemId, userId: userId, listId: listId, productName: productName,
            price: price, quantity: quantity, url: url, imageData: imageData, metadata: metadata
        )
        nextItemId += 1
        items.append(item)
        return item
    }

    func updateWishListItem(
        itemId: Int64, userId: Int64, productName: String, price: Double, quantity: Int,
        url: String?, imageData: Data?, metadata: WishListItemMetadata
    ) async throws {
        if let errorToThrow { throw errorToThrow }
        guard let index = items.firstIndex(where: { $0.id == itemId }) else { return }
        items[index] = WishListItem(
            id: itemId, userId: userId, listId: items[index].listId, productName: productName,
            price: price, quantity: quantity, url: url, isPurchased: items[index].isPurchased,
            isHidden: items[index].isHidden, imageData: imageData, metadata: metadata
        )
    }

    func setWishListItemPurchased(itemId: Int64, userId: Int64, isPurchased: Bool) async throws {
        if let errorToThrow { throw errorToThrow }
        guard let index = items.firstIndex(where: { $0.id == itemId }) else { return }
        items[index].isPurchased = isPurchased
    }

    func setWishListItemHidden(itemId: Int64, userId: Int64, isHidden: Bool) async throws {
        if let errorToThrow { throw errorToThrow }
        guard let index = items.firstIndex(where: { $0.id == itemId }) else { return }
        items[index].isHidden = isHidden
    }

    func deleteWishListItem(itemId: Int64, userId: Int64) async throws {
        if let errorToThrow { throw errorToThrow }
        items.removeAll { $0.id == itemId }
    }
}

actor FakeCollaborativeStoreService: CollaborativeStoreService {
    private var lists: [CollaborativeListWithPartner] = []
    private var items: [CollaborativeItem] = []
    private var partnerUsers: [User] = []
    private var nextListId: Int64 = 1
    private var nextItemId: Int64 = 1
    var errorToThrow: FakeServiceError?

    func setError(_ error: FakeServiceError?) {
        errorToThrow = error
    }

    func seedPartner(_ user: User) {
        partnerUsers.append(user)
    }

    func partners(excluding userId: Int64) async throws -> [User] {
        if let errorToThrow { throw errorToThrow }
        return partnerUsers.filter { $0.id != userId }
    }

    func collaborativeLists(for userId: Int64) async throws -> [CollaborativeListWithPartner] {
        if let errorToThrow { throw errorToThrow }
        return lists.filter { $0.user1Id == userId || $0.user2Id == userId }
    }

    func createCollaborativeList(currentUserId: Int64, partnerEmail: String, name: String) async throws -> CollaborativeList {
        if let errorToThrow { throw errorToThrow }
        guard let partner = partnerUsers.first(where: { $0.email == partnerEmail }) else {
            throw FakeServiceError(message: "Partner user not found")
        }
        let list = CollaborativeListWithPartner(
            id: nextListId, name: name, user1Id: currentUserId, user2Id: partner.id ?? 0, partnerName: partner.displayName
        )
        nextListId += 1
        lists.append(list)
        return CollaborativeList(id: list.id, name: list.name, user1Id: list.user1Id, user2Id: list.user2Id)
    }

    func deleteCollaborativeList(listId: Int64, userId: Int64) async throws {
        if let errorToThrow { throw errorToThrow }
        lists.removeAll { $0.id == listId }
        items.removeAll { $0.listId == listId }
    }

    func collaborativeItems(listId: Int64, userId: Int64, purchased: Bool) async throws -> [CollaborativeItem] {
        if let errorToThrow { throw errorToThrow }
        return items.filter { $0.listId == listId && $0.isPurchased == purchased }
    }

    func addCollaborativeItem(
        listId: Int64, userId: Int64, productName: String, price: Double, quantity: Int, url: String?,
        imageData: Data?, metadata: WishListItemMetadata
    ) async throws -> CollaborativeItem {
        if let errorToThrow { throw errorToThrow }
        let item = CollaborativeItem(
            id: nextItemId, listId: listId, productName: productName, price: price, quantity: quantity,
            url: url, imageData: imageData, metadata: metadata
        )
        nextItemId += 1
        items.append(item)
        return item
    }

    func updateCollaborativeItem(
        itemId: Int64, listId: Int64, userId: Int64, productName: String, price: Double, quantity: Int, url: String?,
        imageData: Data?, metadata: WishListItemMetadata
    ) async throws {
        if let errorToThrow { throw errorToThrow }
        guard let index = items.firstIndex(where: { $0.id == itemId }) else { return }
        items[index].productName = productName
        items[index].price = price
        items[index].quantity = quantity
        items[index].url = url
        items[index].imageData = imageData
        items[index].category = metadata.category
        items[index].manufacturer = metadata.manufacturer
        items[index].msrp = metadata.msrp
        items[index].officialProductURL = metadata.officialProductURL
        items[index].bestRetailerURL = metadata.bestRetailerURL
        items[index].primaryImageURL = metadata.primaryImageURL
        items[index].itemDescription = metadata.itemDescription
        items[index].specifications = metadata.specifications
        items[index].weight = metadata.weight
        items[index].caliber = metadata.caliber
        items[index].compatibility = metadata.compatibility
        items[index].purpose = metadata.purpose
        items[index].notes = metadata.notes
        items[index].availabilityStatus = metadata.availabilityStatus
        items[index].dateRetrieved = metadata.dateRetrieved
    }

    func setCollaborativeItemPurchased(itemId: Int64, listId: Int64, userId: Int64, isPurchased: Bool) async throws {
        if let errorToThrow { throw errorToThrow }
        guard let index = items.firstIndex(where: { $0.id == itemId }) else { return }
        items[index].isPurchased = isPurchased
    }

    func setCollaborativeItemHidden(itemId: Int64, listId: Int64, userId: Int64, isHidden: Bool) async throws {
        if let errorToThrow { throw errorToThrow }
        guard let index = items.firstIndex(where: { $0.id == itemId }) else { return }
        items[index].isHidden = isHidden
    }

    func deleteCollaborativeItem(itemId: Int64, listId: Int64, userId: Int64) async throws {
        if let errorToThrow { throw errorToThrow }
        items.removeAll { $0.id == itemId }
    }
}
