import AppKit
import SwiftUI

/// One line-item row, in either display or inline-edit mode. Shared by the personal and
/// collaborative item tables (configured via `ItemsTableConfig`) so the row layout and
/// edit/delete/purchase/hide behavior isn't duplicated per item type.
struct ItemTableRow: View {
    let item: ItemRow
    let config: ItemsTableConfig
    let isEditing: Bool
    @Binding var draft: ItemDraft

    var onStartEdit: () -> Void
    var onSave: () -> Void
    var onCancelEdit: () -> Void
    var onTogglePurchased: (Bool) -> Void
    var onDelete: () -> Void
    var onToggleHidden: (() -> Void)?
    var onEditDetails: (() -> Void)?

    var body: some View {
        GridRow {
            Toggle(
                "",
                isOn: Binding(get: { item.isPurchased }, set: { onTogglePurchased($0) })
            )
            .labelsHidden()
            .toggleStyle(.checkbox)

            if isEditing {
                TextField("Product name", text: $draft.productName)
            } else {
                HStack(spacing: 8) {
                    thumbnail
                        .task(id: item.imageData) {
                            cachedThumbnail = item.imageData.flatMap(NSImage.init(data:))
                        }
                    Text(item.productName)
                }
            }

            if isEditing {
                TextField("Qty", text: $draft.quantity)
                    .frame(width: 50)
            } else {
                Text("\(item.quantity)")
            }

            if isEditing {
                TextField("Price", text: $draft.price)
                    .frame(width: 80)
            } else {
                Text(item.price.currencyFormatted)
            }

            Text(lineTotal.currencyFormatted)

            if config.showURLColumn {
                if isEditing {
                    TextField("URL", text: $draft.url)
                } else if let url = item.url, let link = URL(string: url) {
                    Link("Link", destination: link)
                } else {
                    Text("-").foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                if isEditing {
                    Button("Save", action: onSave)
                        .disabled(!draft.isValid)
                    Button("Cancel", action: onCancelEdit)
                } else {
                    Menu {
                        Button("Quick Edit", action: onStartEdit)
                        if let onEditDetails {
                            Button("Edit Details…", action: onEditDetails)
                        }
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .frame(width: 16)
                    .help("Edit")

                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .help("Delete")

                    if config.allowHideToggle, let onToggleHidden {
                        Button {
                            onToggleHidden()
                        } label: {
                            Image(systemName: item.isHidden ? "eye" : "eye.slash")
                        }
                        .help(item.isHidden ? "Show" : "Hide")
                    }
                }
            }
            .buttonStyle(.borderless)
        }
    }

    private var lineTotal: Double {
        guard isEditing else { return item.lineTotal }
        return (draft.parsedPrice ?? item.price) * Double(draft.parsedQuantity ?? item.quantity)
    }

    @State private var cachedThumbnail: NSImage?

    @ViewBuilder
    private var thumbnail: some View {
        if let cachedThumbnail {
            Image(nsImage: cachedThumbnail)
                .resizable()
                .scaledToFill()
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.separator, lineWidth: 0.5))
        }
    }
}
