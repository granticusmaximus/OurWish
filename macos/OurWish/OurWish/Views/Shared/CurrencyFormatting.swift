import Foundation

enum PricingConstants {
    /// Matches `TAX_RATE = 0.0875` in the original `WishListTable.tsx`.
    static let taxRate = 0.0875
}

extension Double {
    var currencyFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: NSNumber(value: self)) ?? String(format: "$%.2f", self)
    }
}
