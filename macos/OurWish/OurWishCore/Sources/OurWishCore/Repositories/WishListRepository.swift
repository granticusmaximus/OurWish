import Foundation
import GRDB

/// Local equivalent of `server/routes/wishlist.ts`.
public final class WishListRepository: Sendable {
    private let dbWriter: any DatabaseWriter

    public init(dbWriter: any DatabaseWriter) {
        self.dbWriter = dbWriter
    }

    // MARK: Lists

    public func lists(for userId: Int64) throws -> [WishList] {
        try dbWriter.read { db in
            try WishList
                .filter(WishList.Columns.userId == userId)
                .order(Column("created_at").asc)
                .fetchAll(db)
        }
    }

    @discardableResult
    public func createList(userId: Int64, name: String) throws -> WishList {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw RepositoryError.invalidInput("Wish list name is required")
        }

        return try dbWriter.write { db in
            var list = WishList(userId: userId, name: trimmedName)
            try list.insert(db)
            return list
        }
    }

    public func renameList(listId: Int64, userId: Int64, name: String) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw RepositoryError.invalidInput("Wish list name is required")
        }

        try dbWriter.write { db in
            try assertOwnsList(listId, userId: userId, db: db)
            try db.execute(
                sql: "UPDATE wish_lists SET name = ? WHERE id = ? AND user_id = ?",
                arguments: [trimmedName, listId, userId]
            )
        }
    }

    public func deleteList(listId: Int64, userId: Int64) throws {
        try dbWriter.write { db in
            try assertOwnsList(listId, userId: userId, db: db)

            let totalLists = try WishList.filter(WishList.Columns.userId == userId).fetchCount(db)
            guard totalLists > 1 else {
                throw RepositoryError.cannotDeleteOnlyWishList
            }

            try db.execute(
                sql: "DELETE FROM wish_list_items WHERE list_id = ? AND user_id = ?",
                arguments: [listId, userId]
            )
            try db.execute(
                sql: "DELETE FROM wish_lists WHERE id = ? AND user_id = ?",
                arguments: [listId, userId]
            )
        }
    }

    // MARK: Items

    public func item(id: Int64, userId: Int64) throws -> WishListItem? {
        try dbWriter.read { db in
            try WishListItem
                .filter(WishListItem.Columns.id == id)
                .filter(WishListItem.Columns.userId == userId)
                .fetchOne(db)
        }
    }

    public func items(listId: Int64, userId: Int64, purchased: Bool) throws -> [WishListItem] {
        try dbWriter.read { db in
            try assertOwnsList(listId, userId: userId, db: db)
            return try WishListItem
                .filter(WishListItem.Columns.listId == listId)
                .filter(WishListItem.Columns.isPurchased == purchased)
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
        imageData: Data? = nil
    ) throws -> WishListItem {
        try validateItemInput(productName: productName, quantity: quantity)

        return try dbWriter.write { db in
            try assertOwnsList(listId, userId: userId, db: db)

            var item = WishListItem(
                userId: userId,
                listId: listId,
                productName: productName,
                price: price,
                quantity: quantity,
                url: url,
                imageData: imageData
            )
            try item.insert(db)
            return item
        }
    }

    public func updateItem(
        itemId: Int64,
        userId: Int64,
        productName: String,
        price: Double,
        quantity: Int,
        url: String?
    ) throws {
        try validateItemInput(productName: productName, quantity: quantity)

        try dbWriter.write { db in
            try assertOwnsItem(itemId, userId: userId, db: db)
            try db.execute(
                sql: """
                    UPDATE wish_list_items
                    SET product_name = ?, price = ?, quantity = ?, url = ?
                    WHERE id = ? AND user_id = ?
                    """,
                arguments: [productName, price, quantity, url, itemId, userId]
            )
        }
    }

    public func setPurchased(itemId: Int64, userId: Int64, isPurchased: Bool) throws {
        try dbWriter.write { db in
            try assertOwnsItem(itemId, userId: userId, db: db)
            try db.execute(
                sql: "UPDATE wish_list_items SET is_purchased = ? WHERE id = ? AND user_id = ?",
                arguments: [isPurchased, itemId, userId]
            )
        }
    }

    public func setHidden(itemId: Int64, userId: Int64, isHidden: Bool) throws {
        try dbWriter.write { db in
            try assertOwnsItem(itemId, userId: userId, db: db)
            try db.execute(
                sql: "UPDATE wish_list_items SET is_hidden = ? WHERE id = ? AND user_id = ?",
                arguments: [isHidden, itemId, userId]
            )
        }
    }

    public func deleteItem(itemId: Int64, userId: Int64) throws {
        try dbWriter.write { db in
            try assertOwnsItem(itemId, userId: userId, db: db)
            try db.execute(
                sql: "DELETE FROM wish_list_items WHERE id = ? AND user_id = ?",
                arguments: [itemId, userId]
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

    private func assertOwnsList(_ listId: Int64, userId: Int64, db: Database) throws {
        let exists = try WishList
            .filter(WishList.Columns.id == listId)
            .filter(WishList.Columns.userId == userId)
            .fetchCount(db) > 0
        guard exists else { throw RepositoryError.wishListNotFound }
    }

    private func assertOwnsItem(_ itemId: Int64, userId: Int64, db: Database) throws {
        let exists = try WishListItem
            .filter(WishListItem.Columns.id == itemId)
            .filter(WishListItem.Columns.userId == userId)
            .fetchCount(db) > 0
        guard exists else { throw RepositoryError.itemNotFound }
    }
}
