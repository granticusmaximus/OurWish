import Foundation
import GRDB

/// Local equivalent of `server/routes/collaborative.ts`. `scrapeProductInfo()` from the
/// original file is intentionally not ported — it was never wired to any route there.
public final class CollaborativeListRepository: Sendable {
    private let dbWriter: any DatabaseWriter

    public init(dbWriter: any DatabaseWriter) {
        self.dbWriter = dbWriter
    }

    // MARK: Lists

    public func lists(for userId: Int64) throws -> [CollaborativeListWithPartner] {
        try dbWriter.read { db in
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
    }

    @discardableResult
    public func createList(currentUserId: Int64, partnerEmail: String, name: String) throws -> CollaborativeList {
        let normalizedEmail = partnerEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedEmail.isEmpty, !trimmedName.isEmpty else {
            throw RepositoryError.invalidInput("Partner email and list name required")
        }

        return try dbWriter.write { db in
            guard let partner = try User
                .filter(sql: "LOWER(email) = LOWER(?)", arguments: [normalizedEmail])
                .fetchOne(db)
            else {
                throw RepositoryError.partnerNotFound
            }

            guard partner.id != currentUserId else {
                throw RepositoryError.cannotCollaborateWithSelf
            }

            var list = CollaborativeList(name: trimmedName, user1Id: currentUserId, user2Id: partner.id!)
            try list.insert(db)
            return list
        }
    }

    public func deleteList(listId: Int64, userId: Int64) throws {
        try dbWriter.write { db in
            try assertHasAccess(listId, userId: userId, db: db)
            try db.execute(sql: "DELETE FROM collaborative_lists WHERE id = ?", arguments: [listId])
        }
    }

    // MARK: Items

    /// Looks up an item by id only, scoped to lists the user has access to (used by the
    /// server's image-serving route, which only knows the item id from the URL).
    public func item(id: Int64, userId: Int64) throws -> CollaborativeItem? {
        try dbWriter.read { db in
            guard let item = try CollaborativeItem.fetchOne(db, key: id) else { return nil }
            let hasAccess = try CollaborativeList
                .filter(CollaborativeList.Columns.id == item.listId)
                .filter(CollaborativeList.Columns.user1Id == userId || CollaborativeList.Columns.user2Id == userId)
                .fetchCount(db) > 0
            return hasAccess ? item : nil
        }
    }

    public func items(listId: Int64, userId: Int64, purchased: Bool) throws -> [CollaborativeItem] {
        try dbWriter.read { db in
            try assertHasAccess(listId, userId: userId, db: db)
            return try CollaborativeItem
                .filter(CollaborativeItem.Columns.listId == listId)
                .filter(CollaborativeItem.Columns.isPurchased == purchased)
                .order(Column("created_at").desc)
                .fetchAll(db)
        }
    }

    @discardableResult
    public func addItem(
        listId: Int64,
        userId: Int64,
        productName: String,
        price: Double,
        quantity: Int,
        url: String?,
        imageData: Data? = nil,
        metadata: WishListItemMetadata = .empty
    ) throws -> CollaborativeItem {
        try validateItemInput(productName: productName, quantity: quantity)

        return try dbWriter.write { db in
            try assertHasAccess(listId, userId: userId, db: db)

            var item = CollaborativeItem(
                listId: listId,
                productName: productName,
                price: price,
                quantity: quantity,
                url: url,
                imageData: imageData,
                metadata: metadata
            )
            try item.insert(db)
            return item
        }
    }

    public func updateItem(
        itemId: Int64,
        listId: Int64,
        userId: Int64,
        productName: String,
        price: Double,
        quantity: Int,
        url: String?,
        imageData: Data? = nil,
        metadata: WishListItemMetadata = .empty
    ) throws {
        try validateItemInput(productName: productName, quantity: quantity)

        try dbWriter.write { db in
            try assertHasAccess(listId, userId: userId, db: db)
            try db.execute(
                sql: """
                    UPDATE collaborative_items
                    SET product_name = ?,
                        price = ?,
                        quantity = ?,
                        url = ?,
                        image_data = ?,
                        category = ?,
                        manufacturer = ?,
                        msrp = ?,
                        official_product_url = ?,
                        best_retailer_url = ?,
                        primary_image_url = ?,
                        item_description = ?,
                        specifications = ?,
                        weight = ?,
                        caliber = ?,
                        compatibility = ?,
                        purpose = ?,
                        notes = ?,
                        availability_status = ?,
                        date_retrieved = ?
                    WHERE id = ? AND list_id = ?
                    """,
                arguments: [
                    productName,
                    price,
                    quantity,
                    url,
                    imageData,
                    metadata.category,
                    metadata.manufacturer,
                    metadata.msrp,
                    metadata.officialProductURL,
                    metadata.bestRetailerURL,
                    metadata.primaryImageURL,
                    metadata.itemDescription,
                    metadata.specifications,
                    metadata.weight,
                    metadata.caliber,
                    metadata.compatibility,
                    metadata.purpose,
                    metadata.notes,
                    metadata.availabilityStatus,
                    metadata.dateRetrieved,
                    itemId,
                    listId,
                ]
            )
        }
    }

    public func setPurchased(itemId: Int64, listId: Int64, userId: Int64, isPurchased: Bool) throws {
        try dbWriter.write { db in
            try assertHasAccess(listId, userId: userId, db: db)
            try db.execute(
                sql: "UPDATE collaborative_items SET is_purchased = ? WHERE id = ? AND list_id = ?",
                arguments: [isPurchased, itemId, listId]
            )
        }
    }

    public func setHidden(itemId: Int64, listId: Int64, userId: Int64, isHidden: Bool) throws {
        try dbWriter.write { db in
            try assertHasAccess(listId, userId: userId, db: db)
            try db.execute(
                sql: "UPDATE collaborative_items SET is_hidden = ? WHERE id = ? AND list_id = ?",
                arguments: [isHidden, itemId, listId]
            )
        }
    }

    public func deleteItem(itemId: Int64, listId: Int64, userId: Int64) throws {
        try dbWriter.write { db in
            try assertHasAccess(listId, userId: userId, db: db)
            try db.execute(
                sql: "DELETE FROM collaborative_items WHERE id = ? AND list_id = ?",
                arguments: [itemId, listId]
            )
        }
    }

    // MARK: Helpers

    private func validateItemInput(productName: String, quantity: Int) throws {
        guard !productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RepositoryError.invalidInput("Product name, price, and quantity of at least 1 are required")
        }
        guard quantity >= 1 else {
            throw RepositoryError.invalidInput("Quantity must be at least 1")
        }
    }

    private func assertHasAccess(_ listId: Int64, userId: Int64, db: Database) throws {
        let exists = try CollaborativeList
            .filter(CollaborativeList.Columns.id == listId)
            .filter(CollaborativeList.Columns.user1Id == userId || CollaborativeList.Columns.user2Id == userId)
            .fetchCount(db) > 0
        guard exists else { throw RepositoryError.collaborativeListNotFound }
    }
}
