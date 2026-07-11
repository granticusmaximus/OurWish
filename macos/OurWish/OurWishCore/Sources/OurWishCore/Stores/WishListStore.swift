import Foundation
#if canImport(Observation)
import Observation
#endif

/// Owns personal wish-list state for the currently logged-in user. The backing
/// service can be local-repository or remote-HTTP based.
#if canImport(Observation)
@MainActor
@Observable
public final class WishListStore: ErrorReporting {
    public private(set) var wishLists: [WishList] = []
    public var selectedListId: Int64? {
        didSet {
            guard oldValue != selectedListId else { return }
            Task { await refreshItems() }
        }
    }
    public private(set) var items: [WishListItem] = []
    public private(set) var purchasedItems: [WishListItem] = []
    public var lastError: String?

    private let service: any WishListStoreService
    private var userId: Int64?

    public init(service: any WishListStoreService = LocalWishListStoreService()) {
        self.service = service
    }

    /// Call on login/logout to reload state scoped to the active user.
    public func setCurrentUser(_ userId: Int64?) {
        guard self.userId != userId else { return }
        self.userId = userId
        selectedListId = nil
        items = []
        purchasedItems = []
        if userId == nil {
            wishLists = []
            return
        }
        Task { await refreshLists() }
    }

    // MARK: Lists

    public func createList(name: String) async throws {
        guard let userId else { return }
        let list = try await service.createWishList(userId: userId, name: name)
        await refreshLists()
        selectedListId = list.id
    }

    public func renameList(_ listId: Int64, name: String) async throws {
        guard let userId else { return }
        try await service.renameWishList(listId: listId, userId: userId, name: name)
        await refreshLists()
    }

    public func deleteList(_ listId: Int64) async throws {
        guard let userId else { return }
        try await service.deleteWishList(listId: listId, userId: userId)
        await refreshLists()
        if selectedListId == listId {
            selectedListId = wishLists.first(where: { $0.id != listId })?.id
        }
    }

    // MARK: Items

    public func addItem(
        productName: String, price: Double, quantity: Int, url: String?,
        listId: Int64? = nil, imageData: Data? = nil,
        metadata: WishListItemMetadata = .empty
    ) async throws {
        guard let userId else { return }
        guard let targetListId = listId ?? selectedListId else {
            throw RepositoryError.wishListNotFound
        }
        _ = try await service.addWishListItem(
            listId: targetListId, userId: userId,
            productName: productName, price: price, quantity: quantity, url: url,
            imageData: imageData, metadata: metadata
        )
        await refreshItems()
    }

    public func updateItem(
        _ itemId: Int64,
        productName: String,
        price: Double,
        quantity: Int,
        url: String?,
        metadata: WishListItemMetadata = .empty
    ) async throws {
        guard let userId else { return }
        try await service.updateWishListItem(
            itemId: itemId, userId: userId,
            productName: productName, price: price, quantity: quantity, url: url,
            metadata: metadata
        )
        await refreshItems()
    }

    public func setPurchased(_ itemId: Int64, isPurchased: Bool) async throws {
        guard let userId else { return }
        try await service.setWishListItemPurchased(itemId: itemId, userId: userId, isPurchased: isPurchased)
        await refreshItems()
    }

    public func setHidden(_ itemId: Int64, isHidden: Bool) async throws {
        guard let userId else { return }
        try await service.setWishListItemHidden(itemId: itemId, userId: userId, isHidden: isHidden)
        await refreshItems()
    }

    public func deleteItem(_ itemId: Int64) async throws {
        guard let userId else { return }
        try await service.deleteWishListItem(itemId: itemId, userId: userId)
        await refreshItems()
    }

    // MARK: Refresh

    private func refreshLists() async {
        guard let userId else {
            wishLists = []
            return
        }

        await runCatching {
            let lists = try await service.wishLists(for: userId)
            wishLists = lists
            if selectedListId == nil || !lists.contains(where: { $0.id == selectedListId }) {
                selectedListId = lists.first?.id
            }
        }
    }

    private func refreshItems() async {
        guard let userId, let listId = selectedListId else {
            items = []
            purchasedItems = []
            return
        }

        await runCatching {
            async let active = service.wishListItems(listId: listId, userId: userId, purchased: false)
            async let purchased = service.wishListItems(listId: listId, userId: userId, purchased: true)
            items = try await active
            purchasedItems = try await purchased
        }
    }
}
#endif
