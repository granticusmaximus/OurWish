import OurWishCore
import SwiftUI

/// Thin wrapper around `ItemsTableView` for personal wish lists — replaces
/// `WishListTable.tsx` in its `isCollaborative={false}` mode (URL column, hide/show,
/// and inline rename all enabled).
struct WishListItemsTableView: View {
    @Environment(WishListStore.self) private var store
    let wishListName: String
    var onEditItem: (Int64) -> Void

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
                    let metadata = store.items.first(where: { $0.id == id })?.metadata ?? .empty
                    run {
                        try await store.updateItem(
                            id,
                            productName: name,
                            price: price,
                            quantity: quantity,
                            url: url,
                            metadata: metadata
                        )
                    }
                },
                onTogglePurchased: { id, isPurchased in
                    run { try await store.setPurchased(id, isPurchased: isPurchased) }
                },
                onDelete: { id in
                    run { try await store.deleteItem(id) }
                },
                onToggleHidden: { id, isHidden in
                    run { try await store.setHidden(id, isHidden: isHidden) }
                },
                onRename: { name in
                    guard let listId = store.selectedListId else { return }
                    run { try await store.renameList(listId, name: name) }
                },
                onEditDetails: onEditItem
            )
        }
    }

    private func run(_ operation: @escaping () async throws -> Void) {
        Task { @MainActor in
            do {
                try await operation()
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
