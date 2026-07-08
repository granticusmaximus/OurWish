import SwiftUI

/// Replaces `AddItemForm.tsx`. Shared by the personal and collaborative flows — the
/// sidebar now owns which list is active, so this always adds to "the list you're
/// currently looking at" rather than offering its own list picker.
struct AddItemSheet: View {
    var onSubmit: (_ productName: String, _ price: Double, _ quantity: Int, _ url: String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var productName = ""
    @State private var price = ""
    @State private var quantity = "1"
    @State private var url = ""
    @State private var errorMessage: String?
    @FocusState private var productNameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("Add Item", systemImage: "plus.circle.fill")
                .font(.title2.bold())
                .foregroundStyle(.tint)

            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            VStack(alignment: .leading, spacing: 14) {
                LabeledField("Product Name") {
                    TextField("e.g. Espresso Machine", text: $productName)
                        .focused($productNameFocused)
                }
                HStack(spacing: 14) {
                    LabeledField("Price Each") {
                        TextField("0.00", text: $price)
                    }
                    LabeledField("Quantity") {
                        TextField("1", text: $quantity)
                    }
                    .frame(width: 90)
                }
                LabeledField("Product URL") {
                    TextField("Optional", text: $url)
                }
            }
            .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Add to List", action: submit)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValid)
            }
        }
        .padding(24)
        .frame(minWidth: 420)
        .onAppear { productNameFocused = true }
    }

    private var isValid: Bool {
        !productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && Double(price) != nil
            && (Int(quantity).map { $0 >= 1 } ?? false)
    }

    private func submit() {
        guard let parsedPrice = Double(price), let parsedQuantity = Int(quantity), parsedQuantity >= 1 else {
            errorMessage = "Product name, price, and quantity are required"
            return
        }

        onSubmit(
            productName.trimmingCharacters(in: .whitespacesAndNewlines),
            parsedPrice,
            parsedQuantity,
            url.isEmpty ? nil : url
        )
        dismiss()
    }
}

/// Small labeled-field wrapper used across the sheet forms for a consistent,
/// modern "form row" look instead of relying on `Form`'s default macOS chrome.
struct LabeledField<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            content
        }
    }
}
