import OurWishCore
import SwiftUI

/// Thin wrapper around `ItemsTableView` for collaborative lists — replaces
/// `WishListTable.tsx` in its `isCollaborative={true}` mode (no URL column, no
/// hide/show, no inline rename).
struct CollaborativeItemsTableView: View {
    @Environment(CollaborativeStore.self) private var store
    let listName: String

    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }

            ItemsTableView(
                title: listName,
                items: store.items.map(ItemRow.init),
                purchasedItems: store.purchasedItems.map(ItemRow.init),
                config: ItemsTableConfig(showURLColumn: false, allowHideToggle: false, allowRename: false),
                onSave: { id, name, price, quantity, url in
                    run { try store.updateItem(id, productName: name, price: price, quantity: quantity, url: url) }
                },
                onTogglePurchased: { id, isPurchased in
                    run { try store.setPurchased(id, isPurchased: isPurchased) }
                },
                onDelete: { id in
                    run { try store.deleteItem(id) }
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
