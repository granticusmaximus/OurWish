import Foundation

/// Text-field-friendly scratch state for whichever row is currently being edited.
struct ItemDraft {
    var productName: String = ""
    var price: String = ""
    var quantity: String = ""
    var url: String = ""

    init() {}

    init(from item: ItemRow) {
        productName = item.productName
        price = String(format: "%.2f", item.price)
        quantity = String(item.quantity)
        url = item.url ?? ""
    }

    var parsedPrice: Double? { Double(price) }
    var parsedQuantity: Int? {
        guard let value = Int(quantity), value >= 1 else { return nil }
        return value
    }

    var isValid: Bool {
        !productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && parsedPrice != nil
            && parsedQuantity != nil
    }
}
