import SwiftUI

/// The collapsible "Purchased Items" list — replaces the `<Collapse>` block in
/// `WishListTable.tsx`.
struct PurchasedItemsSection: View {
    let items: [ItemRow]
    var onTogglePurchased: (Int64, Bool) -> Void
    var onDelete: (Int64) -> Void

    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(spacing: 6) {
                ForEach(items) { item in
                    HStack {
                        Toggle(
                            "",
                            isOn: Binding(get: { true }, set: { onTogglePurchased(item.id, $0) })
                        )
                        .labelsHidden()
                        .toggleStyle(.checkbox)

                        Text("\(item.productName) — \(item.quantity) x \(item.price.currencyFormatted) = \(item.lineTotal.currencyFormatted)")

                        Spacer()

                        Button("Remove", role: .destructive) {
                            onDelete(item.id)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 4)
                    Divider()
                }
            }
            .padding(.top, 8)
        } label: {
            Text("Purchased Items (\(items.count))")
                .font(.headline)
        }
    }
}
