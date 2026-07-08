import Foundation
import GRDB
import Observation

/// Owns personal wish-list state for the currently logged-in user. Unlike the original
/// React app (which manually refetches after every mutation because it has no other way
/// to stay in sync with the server), this store subscribes once via GRDB
/// `ValueObservation` — repository writes just hit the database, and every observed
/// property updates on its own, so a view can never go stale from a missed refetch call.
///
/// Uses GRDB's callback-based `.start(in:scheduling:onError:onChange:)` observation API
/// rather than the newer `.values(in:)` async sequence: the latter hit a GRDB internal
/// assertion ("Fetching in a non-isolated way is illegal") on newer toolchains, while
/// `.start` is GRDB's long-standing, more battle-tested observation entry point.
@MainActor
@Observable
public final class WishListStore {
    public private(set) var wishLists: [WishList] = []
    public var selectedListId: Int64? {
        didSet {
            guard oldValue != selectedListId else { return }
            observeItems()
        }
    }
    public private(set) var items: [WishListItem] = []
    public private(set) var purchasedItems: [WishListItem] = []
    public var lastError: String?

    public let repository: WishListRepository
    private let dbWriter: any DatabaseWriter
    private var userId: Int64?

    private var listsCancellable: DatabaseCancellable?
    private var itemsCancellable: DatabaseCancellable?
    private var purchasedCancellable: DatabaseCancellable?

    public init(dbWriter: any DatabaseWriter = DatabaseManager.shared) {
        self.dbWriter = dbWriter
        self.repository = WishListRepository(dbWriter: dbWriter)
    }

    /// Call on login/logout to (re)start observations scoped to the new user.
    public func setCurrentUser(_ userId: Int64?) {
        guard self.userId != userId else { return }
        self.userId = userId
        selectedListId = nil
        items = []
        purchasedItems = []
        observeLists()
    }

    // MARK: Lists

    public func createList(name: String) throws {
        guard let userId else { return }
        let list = try repository.createList(userId: userId, name: name)
        selectedListId = list.id
    }

    public func renameList(_ listId: Int64, name: String) throws {
        guard let userId else { return }
        try repository.renameList(listId: listId, userId: userId, name: name)
    }

    public func deleteList(_ listId: Int64) throws {
        guard let userId else { return }
        try repository.deleteList(listId: listId, userId: userId)
        if selectedListId == listId {
            selectedListId = wishLists.first(where: { $0.id != listId })?.id
        }
    }

    // MARK: Items

    public func addItem(
        productName: String, price: Double, quantity: Int, url: String?,
        listId: Int64? = nil, imageData: Data? = nil
    ) throws {
        guard let userId else { return }
        guard let targetListId = listId ?? selectedListId else {
            throw RepositoryError.wishListNotFound
        }
        try repository.addItem(
            listId: targetListId, userId: userId,
            productName: productName, price: price, quantity: quantity, url: url, imageData: imageData
        )
    }

    public func updateItem(_ itemId: Int64, productName: String, price: Double, quantity: Int, url: String?) throws {
        guard let userId else { return }
        try repository.updateItem(
            itemId: itemId, userId: userId,
            productName: productName, price: price, quantity: quantity, url: url
        )
    }

    public func setPurchased(_ itemId: Int64, isPurchased: Bool) throws {
        guard let userId else { return }
        try repository.setPurchased(itemId: itemId, userId: userId, isPurchased: isPurchased)
    }

    public func setHidden(_ itemId: Int64, isHidden: Bool) throws {
        guard let userId else { return }
        try repository.setHidden(itemId: itemId, userId: userId, isHidden: isHidden)
    }

    public func deleteItem(_ itemId: Int64) throws {
        guard let userId else { return }
        try repository.deleteItem(itemId: itemId, userId: userId)
    }

    // MARK: Observation

    private func observeLists() {
        listsCancellable = nil
        guard let userId else {
            wishLists = []
            return
        }

        let observation = ValueObservation.tracking { db in
            try WishList
                .filter(WishList.Columns.userId == userId)
                .order(Column("created_at").asc)
                .fetchAll(db)
        }

        listsCancellable = observation.start(
            in: dbWriter,
            scheduling: .mainActor,
            onError: { [weak self] error in
                self?.lastError = error.localizedDescription
            },
            onChange: { [weak self] lists in
                guard let self else { return }
                self.wishLists = lists
                if self.selectedListId == nil || !lists.contains(where: { $0.id == self.selectedListId }) {
                    self.selectedListId = lists.first?.id
                }
            }
        )
    }

    private func observeItems() {
        itemsCancellable = nil
        purchasedCancellable = nil

        guard let userId, let listId = selectedListId else {
            items = []
            purchasedItems = []
            return
        }

        let itemsObservation = ValueObservation.tracking { db in
            try WishListItem
                .filter(WishListItem.Columns.listId == listId)
                .filter(WishListItem.Columns.userId == userId)
                .filter(WishListItem.Columns.isPurchased == false)
                .order(Column("created_at").desc)
                .fetchAll(db)
        }
        itemsCancellable = itemsObservation.start(
            in: dbWriter,
            scheduling: .mainActor,
            onError: { [weak self] error in
                self?.lastError = error.localizedDescription
            },
            onChange: { [weak self] rows in
                self?.items = rows
            }
        )

        let purchasedObservation = ValueObservation.tracking { db in
            try WishListItem
                .filter(WishListItem.Columns.listId == listId)
                .filter(WishListItem.Columns.userId == userId)
                .filter(WishListItem.Columns.isPurchased == true)
                .order(Column("created_at").desc)
                .fetchAll(db)
        }
        purchasedCancellable = purchasedObservation.start(
            in: dbWriter,
            scheduling: .mainActor,
            onError: { [weak self] error in
                self?.lastError = error.localizedDescription
            },
            onChange: { [weak self] rows in
                self?.purchasedItems = rows
            }
        )
    }
}
