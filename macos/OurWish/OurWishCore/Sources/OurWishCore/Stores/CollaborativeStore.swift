import Foundation
import GRDB
import Observation

/// Mirrors `WishListStore` for collaborative lists — see that file for the
/// `.start`-over-`.values(in:)` observation rationale.
@MainActor
@Observable
public final class CollaborativeStore {
    public private(set) var lists: [CollaborativeListWithPartner] = []
    public private(set) var partners: [User] = []
    public var selectedListId: Int64? {
        didSet {
            guard oldValue != selectedListId else { return }
            observeItems()
        }
    }
    public private(set) var items: [CollaborativeItem] = []
    public private(set) var purchasedItems: [CollaborativeItem] = []
    public var lastError: String?

    public let repository: CollaborativeListRepository
    private let userRepository: UserRepository
    private let dbWriter: any DatabaseWriter
    private var userId: Int64?

    private var listsCancellable: DatabaseCancellable?
    private var itemsCancellable: DatabaseCancellable?
    private var purchasedCancellable: DatabaseCancellable?

    public init(dbWriter: any DatabaseWriter = DatabaseManager.shared) {
        self.dbWriter = dbWriter
        self.repository = CollaborativeListRepository(dbWriter: dbWriter)
        self.userRepository = UserRepository(dbWriter: dbWriter)
    }

    /// Call on login/logout to (re)start observations scoped to the new user.
    public func setCurrentUser(_ userId: Int64?) {
        guard self.userId != userId else { return }
        self.userId = userId
        selectedListId = nil
        items = []
        purchasedItems = []
        refreshPartners()
        observeLists()
    }

    public func refreshPartners() {
        guard let userId else {
            partners = []
            return
        }
        do {
            partners = try userRepository.partners(excluding: userId)
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: Lists

    public func createList(partnerEmail: String, name: String) throws {
        guard let userId else { return }
        let list = try repository.createList(currentUserId: userId, partnerEmail: partnerEmail, name: name)
        selectedListId = list.id
    }

    public func deleteList(_ listId: Int64) throws {
        guard let userId else { return }
        try repository.deleteList(listId: listId, userId: userId)
        if selectedListId == listId {
            selectedListId = nil
        }
    }

    // MARK: Items

    public func addItem(productName: String, price: Double, quantity: Int, url: String?) throws {
        guard let userId, let listId = selectedListId else {
            throw RepositoryError.collaborativeListNotFound
        }
        try repository.addItem(
            listId: listId, userId: userId,
            productName: productName, price: price, quantity: quantity, url: url
        )
    }

    public func updateItem(_ itemId: Int64, productName: String, price: Double, quantity: Int, url: String?) throws {
        guard let userId, let listId = selectedListId else { return }
        try repository.updateItem(
            itemId: itemId, listId: listId, userId: userId,
            productName: productName, price: price, quantity: quantity, url: url
        )
    }

    public func setPurchased(_ itemId: Int64, isPurchased: Bool) throws {
        guard let userId, let listId = selectedListId else { return }
        try repository.setPurchased(itemId: itemId, listId: listId, userId: userId, isPurchased: isPurchased)
    }

    public func deleteItem(_ itemId: Int64) throws {
        guard let userId, let listId = selectedListId else { return }
        try repository.deleteItem(itemId: itemId, listId: listId, userId: userId)
    }

    // MARK: Observation

    private func observeLists() {
        listsCancellable = nil
        guard let userId else {
            lists = []
            return
        }

        let observation = ValueObservation.tracking { db in
            try CollaborativeListWithPartner.fetchAll(
                db,
                sql: """
                    SELECT cl.id, cl.name, cl.user1_id, cl.user2_id,
                           CASE WHEN cl.user1_id = ? THEN u2.display_name ELSE u1.display_name END AS partner_name
                    FROM collaborative_lists cl
                    JOIN users u1 ON cl.user1_id = u1.id
                    JOIN users u2 ON cl.user2_id = u2.id
                    WHERE cl.user1_id = ? OR cl.user2_id = ?
                    ORDER BY cl.created_at ASC
                    """,
                arguments: [userId, userId, userId]
            )
        }

        listsCancellable = observation.start(
            in: dbWriter,
            scheduling: .async(onQueue: .main),
            onError: { [weak self] error in
                self?.lastError = error.localizedDescription
            },
            onChange: { [weak self] rows in
                guard let self else { return }
                self.lists = rows
                if let selected = self.selectedListId, !rows.contains(where: { $0.id == selected }) {
                    self.selectedListId = nil
                }
            }
        )
    }

    private func observeItems() {
        itemsCancellable = nil
        purchasedCancellable = nil

        guard let listId = selectedListId else {
            items = []
            purchasedItems = []
            return
        }

        let itemsObservation = ValueObservation.tracking { db in
            try CollaborativeItem
                .filter(CollaborativeItem.Columns.listId == listId)
                .filter(CollaborativeItem.Columns.isPurchased == false)
                .order(Column("created_at").desc)
                .fetchAll(db)
        }
        itemsCancellable = itemsObservation.start(
            in: dbWriter,
            scheduling: .async(onQueue: .main),
            onError: { [weak self] error in
                self?.lastError = error.localizedDescription
            },
            onChange: { [weak self] rows in
                self?.items = rows
            }
        )

        let purchasedObservation = ValueObservation.tracking { db in
            try CollaborativeItem
                .filter(CollaborativeItem.Columns.listId == listId)
                .filter(CollaborativeItem.Columns.isPurchased == true)
                .order(Column("created_at").desc)
                .fetchAll(db)
        }
        purchasedCancellable = purchasedObservation.start(
            in: dbWriter,
            scheduling: .async(onQueue: .main),
            onError: { [weak self] error in
                self?.lastError = error.localizedDescription
            },
            onChange: { [weak self] rows in
                self?.purchasedItems = rows
            }
        )
    }
}
