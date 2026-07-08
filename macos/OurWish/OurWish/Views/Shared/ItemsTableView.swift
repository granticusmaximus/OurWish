import SwiftUI

/// Generic item table shared by `WishListItemsTableView` and
/// `CollaborativeItemsTableView` — replaces `WishListTable.tsx`. Both callers hand in
/// `ItemRow` values (mapped from their own model type) plus an `ItemsTableConfig`
/// describing which optional features apply, instead of duplicating the table markup
/// per item type the way the original React component did via an `isCollaborative` prop.
struct ItemsTableView: View {
    let title: String
    let items: [ItemRow]
    let purchasedItems: [ItemRow]
    let config: ItemsTableConfig
    var onSave: (Int64, String, Double, Int, String?) -> Void
    var onTogglePurchased: (Int64, Bool) -> Void
    var onDelete: (Int64) -> Void
    var onToggleHidden: ((Int64, Bool) -> Void)?
    var onRename: ((String) -> Void)?

    @State private var editingId: Int64?
    @State private var draft = ItemDraft()
    @State private var errorMessage: String?

    private var visibleItems: [ItemRow] { items.filter { !$0.isHidden } }
    private var hiddenItems: [ItemRow] { items.filter { $0.isHidden } }
    private var subtotal: Double { visibleItems.reduce(0) { $0 + $1.lineTotal } }
    private var tax: Double { subtotal * PricingConstants.taxRate }
    private var total: Double { subtotal + tax }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            if items.isEmpty {
                ContentUnavailableView(
                    "No Items Yet",
                    systemImage: "cart",
                    description: Text("Add something to get started.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                table(for: visibleItems)

                if !hiddenItems.isEmpty {
                    DisclosureGroup("Hidden Items (\(hiddenItems.count))") {
                        table(for: hiddenItems)
                            .padding(.top, 8)
                    }
                }
            }

            if !purchasedItems.isEmpty {
                PurchasedItemsSection(
                    items: purchasedItems,
                    onTogglePurchased: onTogglePurchased,
                    onDelete: onDelete
                )
            }
        }
        .padding(20)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private var header: some View {
        if config.allowRename, let onRename {
            EditableListNameView(name: title, itemCount: visibleItems.count, onRename: onRename)
        } else {
            Text(visibleItems.count == 1 ? "1 item" : "\(visibleItems.count) items")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var columnCount: Int { config.showURLColumn ? 7 : 6 }

    @ViewBuilder
    private func table(for rows: [ItemRow]) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
            GridRow {
                Text("Purchased").bold()
                Text("Product").bold()
                Text("Qty").bold()
                Text("Price Each").bold()
                Text("Line Total").bold()
                if config.showURLColumn { Text("URL").bold() }
                Text("Actions").bold()
            }
            .font(.subheadline)

            Divider().gridCellColumns(columnCount)

            ForEach(rows) { item in
                ItemTableRow(
                    item: item,
                    config: config,
                    isEditing: editingId == item.id,
                    draft: $draft,
                    onStartEdit: {
                        editingId = item.id
                        draft = ItemDraft(from: item)
                        errorMessage = nil
                    },
                    onSave: { commitEdit(for: item) },
                    onCancelEdit: { editingId = nil },
                    onTogglePurchased: { onTogglePurchased(item.id, $0) },
                    onDelete: { onDelete(item.id) },
                    onToggleHidden: config.allowHideToggle
                        ? { onToggleHidden?(item.id, !item.isHidden) }
                        : nil
                )
            }

            Divider().gridCellColumns(columnCount)

            GridRow {
                Text("Subtotal:").bold().gridCellColumns(columnCount - 1)
                Text(subtotal.currencyFormatted)
            }
            GridRow {
                Text("Tax (\(PricingConstants.taxRate * 100, specifier: "%.2f")%):")
                    .bold()
                    .gridCellColumns(columnCount - 1)
                Text(tax.currencyFormatted)
            }
            GridRow {
                Text("Total:").bold().gridCellColumns(columnCount - 1)
                Text(total.currencyFormatted).bold()
            }
        }
    }

    private func commitEdit(for item: ItemRow) {
        guard let price = draft.parsedPrice, let quantity = draft.parsedQuantity else {
            errorMessage = "Please enter a valid price and quantity"
            return
        }
        let trimmedName = draft.productName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Product name is required"
            return
        }

        onSave(item.id, trimmedName, price, quantity, draft.url.isEmpty ? nil : draft.url)
        editingId = nil
        errorMessage = nil
    }
}
