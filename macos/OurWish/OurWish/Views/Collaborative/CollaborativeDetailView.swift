import OurWishCore
import SwiftUI

/// The detail pane for a selected collaborative list — mirrors `WishListDetailView`.
struct CollaborativeDetailView: View {
    @Environment(CollaborativeStore.self) private var store
    let list: CollaborativeListWithPartner

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

                Label("Shared with \(list.partnerName)", systemImage: "person.2.fill")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                CollaborativeItemsTableView(listName: list.name)
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
                .help("Delete this collaborative list")
            }
        }
        .sheet(isPresented: $showAddItem) {
            AddItemSheet { name, price, quantity, url, imageData in
                try await store.addItem(
                    productName: name,
                    price: price,
                    quantity: quantity,
                    url: url,
                    imageData: imageData
                )
            }
        }
        .confirmationDialog(
            "Delete “\(list.name)”?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete List", role: .destructive) {
                run { try await store.deleteList(list.id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This also deletes all items in this list, for both of you. This can't be undone.")
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
