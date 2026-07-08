import Foundation
import OurWishCore

/// Plain, storage-agnostic view model for one line item, shared by the personal and
/// collaborative item tables so they can reuse the same row/table rendering code
/// instead of duplicating it per item type (`WishListItem` vs. `CollaborativeItem`).
struct ItemRow: Identifiable, Equatable {
    let id: Int64
    var productName: String
    var price: Double
    var quantity: Int
    var url: String?
    var isPurchased: Bool
    var isHidden: Bool

    var lineTotal: Double { price * Double(quantity) }
}

extension ItemRow {
    init(_ item: WishListItem) {
        self.init(
            id: item.id!,
            productName: item.productName,
            price: item.price,
            quantity: item.quantity,
            url: item.url,
            isPurchased: item.isPurchased,
            isHidden: item.isHidden
        )
    }

    init(_ item: CollaborativeItem) {
        self.init(
            id: item.id!,
            productName: item.productName,
            price: item.price,
            quantity: item.quantity,
            url: item.url,
            isPurchased: item.isPurchased,
            isHidden: false
        )
    }
}

/// Which optional table features apply — mirrors the `isCollaborative` prop branching
/// in the original `WishListTable.tsx`.
struct ItemsTableConfig {
    var showURLColumn: Bool
    var allowHideToggle: Bool
    var allowRename: Bool
}
