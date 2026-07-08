import OurWishCore
import SwiftUI

/// The detail pane for a selected personal wish list — the sidebar now owns switching
/// between lists and creating new ones, so this only handles the selected list's items
/// plus per-list actions (add item, delete this list) in its toolbar.
struct WishListDetailView: View {
    @Environment(WishListStore.self) private var store
    let list: WishList

    @State private var showAddItem = false
    @State private var showDeleteConfirm = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
                WishListItemsTableView(wishListName: list.name)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(.background)
        .navigationTitle(list.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddItem = true
                } label: {
                    Label("Add Item", systemImage: "plus")
                }
                .help("Add a new item to this list")
            }
            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete List", systemImage: "trash")
                }
                .disabled(store.wishLists.count <= 1)
                .help(
                    store.wishLists.count <= 1
                        ? "You can't delete your only wish list"
                        : "Delete this wish list"
                )
            }
        }
        .sheet(isPresented: $showAddItem) {
            AddItemSheet(onClose: { showAddItem = false }) { name, price, quantity, url, imageData, metadata in
                try await store.addItem(
                        productName: name, price: price, quantity: quantity, url: url,
                        listId: list.id, imageData: imageData, metadata: metadata
                    )
            }
        }
        .confirmationDialog(
            "Delete “\(list.name)”?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete List", role: .destructive) {
                guard let id = list.id else { return }
                run { try await store.deleteList(id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This also deletes all items in this list. This can't be undone.")
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
