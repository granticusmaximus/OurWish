import OurWishCore
import SwiftUI

/// Thin wrapper around `ItemsTableView` for collaborative lists — replaces
/// `WishListTable.tsx` in its `isCollaborative={true}` mode (no URL column, no
/// inline rename).
struct CollaborativeItemsTableView: View {
    @Environment(CollaborativeStore.self) private var store
    let listName: String
    var onEditItem: (Int64) -> Void

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
                config: ItemsTableConfig(showURLColumn: false, allowHideToggle: true, allowRename: false),
                onSave: { id, name, price, quantity, url in
                    let existingItem = store.items.first(where: { $0.id == id })
                    run {
                        try await store.updateItem(
                            id, productName: name, price: price, quantity: quantity, url: url,
                            imageData: existingItem?.imageData, metadata: existingItem?.metadata ?? .empty
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
                onEditDetails: onEditItem,
                onMove: { id, direction in
                    run { try await store.moveItem(id, direction: direction) }
                }
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
