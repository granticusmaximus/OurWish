import OurWishCore
import SwiftUI

/// Thin wrapper around `ItemsTableView` for personal wish lists — replaces
/// `WishListTable.tsx` in its `isCollaborative={false}` mode (URL column, hide/show,
/// and inline rename all enabled).
struct WishListItemsTableView: View {
    @Environment(WishListStore.self) private var store
    let wishListName: String

    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }

            ItemsTableView(
                title: wishListName,
                items: store.items.map(ItemRow.init),
                purchasedItems: store.purchasedItems.map(ItemRow.init),
                config: ItemsTableConfig(showURLColumn: true, allowHideToggle: true, allowRename: true),
                onSave: { id, name, price, quantity, url in
                    run { try store.updateItem(id, productName: name, price: price, quantity: quantity, url: url) }
                },
                onTogglePurchased: { id, isPurchased in
                    run { try store.setPurchased(id, isPurchased: isPurchased) }
                },
                onDelete: { id in
                    run { try store.deleteItem(id) }
                },
                onToggleHidden: { id, isHidden in
                    run { try store.setHidden(id, isHidden: isHidden) }
                },
                onRename: { name in
                    guard let listId = store.selectedListId else { return }
                    run { try store.renameList(listId, name: name) }
                }
            )
        }
    }

    private func run(_ operation: () throws -> Void) {
        do {
            try operation()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
