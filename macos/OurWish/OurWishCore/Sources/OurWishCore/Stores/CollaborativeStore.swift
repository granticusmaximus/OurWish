import Foundation
#if canImport(Observation)
import Observation
#endif

/// Mirrors `WishListStore` for collaborative lists, backed by either local or remote
/// services depending on app configuration.
#if canImport(Observation)
@MainActor
@Observable
public final class CollaborativeStore: ErrorReporting {
    public private(set) var lists: [CollaborativeListWithPartner] = []
    public private(set) var partners: [User] = []
    public var selectedListId: Int64? {
        didSet {
            guard oldValue != selectedListId else { return }
            Task { await refreshItems() }
        }
    }
    public private(set) var items: [CollaborativeItem] = []
    public private(set) var purchasedItems: [CollaborativeItem] = []
    public var lastError: String?

    private let service: any CollaborativeStoreService
    private var userId: Int64?

    public init(service: any CollaborativeStoreService = LocalCollaborativeStoreService()) {
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
            partners = []
            lists = []
            return
        }
        Task {
            await refreshPartners()
            await refreshLists()
        }
    }

    public func refreshPartners() async {
        guard let userId else {
            partners = []
            return
        }
        await runCatching {
            partners = try await service.partners(excluding: userId)
        }
    }

    // MARK: Lists

    public func createList(partnerEmail: String, name: String) async throws {
        guard let userId else { return }
        let list = try await service.createCollaborativeList(currentUserId: userId, partnerEmail: partnerEmail, name: name)
        await refreshLists()
        selectedListId = list.id
    }

    public func deleteList(_ listId: Int64) async throws {
        guard let userId else { return }
        try await service.deleteCollaborativeList(listId: listId, userId: userId)
        await refreshLists()
        if selectedListId == listId {
            selectedListId = nil
        }
    }

    // MARK: Items

    public func addItem(
        productName: String, price: Double, quantity: Int, url: String?,
        imageData: Data? = nil, metadata: WishListItemMetadata = .empty
    ) async throws {
        guard let userId, let listId = selectedListId else {
            throw RepositoryError.collaborativeListNotFound
        }
        _ = try await service.addCollaborativeItem(
            listId: listId, userId: userId,
            productName: productName, price: price, quantity: quantity, url: url,
            imageData: imageData, metadata: metadata
        )
        await refreshItems()
    }

    public func updateItem(
        _ itemId: Int64, productName: String, price: Double, quantity: Int, url: String?,
        metadata: WishListItemMetadata = .empty
    ) async throws {
        guard let userId, let listId = selectedListId else { return }
        try await service.updateCollaborativeItem(
            itemId: itemId, listId: listId, userId: userId,
            productName: productName, price: price, quantity: quantity, url: url, metadata: metadata
        )
        await refreshItems()
    }

    public func setPurchased(_ itemId: Int64, isPurchased: Bool) async throws {
        guard let userId, let listId = selectedListId else { return }
        try await service.setCollaborativeItemPurchased(itemId: itemId, listId: listId, userId: userId, isPurchased: isPurchased)
        await refreshItems()
    }

    public func setHidden(_ itemId: Int64, isHidden: Bool) async throws {
        guard let userId, let listId = selectedListId else { return }
        try await service.setCollaborativeItemHidden(itemId: itemId, listId: listId, userId: userId, isHidden: isHidden)
        await refreshItems()
    }

    public func deleteItem(_ itemId: Int64) async throws {
        guard let userId, let listId = selectedListId else { return }
        try await service.deleteCollaborativeItem(itemId: itemId, listId: listId, userId: userId)
        await refreshItems()
    }

    // MARK: Refresh

    private func refreshLists() async {
        guard let userId else {
            lists = []
            return
        }

        await runCatching {
            let rows = try await service.collaborativeLists(for: userId)
            lists = rows
            if selectedListId == nil || !rows.contains(where: { $0.id == selectedListId }) {
                selectedListId = rows.first?.id
            }
        }
    }

    private func refreshItems() async {
        guard let listId = selectedListId else {
            items = []
            purchasedItems = []
            return
        }

        guard let userId else { return }
        await runCatching {
            async let active = service.collaborativeItems(listId: listId, userId: userId, purchased: false)
            async let purchased = service.collaborativeItems(listId: listId, userId: userId, purchased: true)
            items = try await active
            purchasedItems = try await purchased
        }
    }
}
#endif
