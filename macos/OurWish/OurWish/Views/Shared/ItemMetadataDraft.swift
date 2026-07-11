import Foundation
import OurWishCore

/// Text-field-friendly scratch state for `AddItemSheet`'s metadata section, mirroring
/// `ItemDraft`'s convention — one struct owning the trimming/parsing/validation logic
/// instead of it being repeated inline for each of the 15 fields at submit time.
struct ItemMetadataDraft {
    var category = ""
    var manufacturer = ""
    var msrp = ""
    var officialProductURL = ""
    var bestRetailerURL = ""
    var primaryImageURL = ""
    var itemDescription = ""
    var specifications = ""
    var weight = ""
    var caliber = ""
    var compatibility = ""
    var purpose = ""
    var notes = ""
    var availabilityStatus = ""
    var dateRetrieved = ""

    private var trimmedMSRP: String { msrp.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var parsedMSRP: Double? { Double(trimmedMSRP) }
    /// True only when `msrp` has non-blank text that isn't a valid number.
    var hasInvalidMSRP: Bool { !trimmedMSRP.isEmpty && parsedMSRP == nil }

    private var trimmedDateRetrieved: String { dateRetrieved.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var parsedDateRetrieved: Date? { WishListItemMetadata.dateOnlyFormatter.date(from: trimmedDateRetrieved) }
    /// True only when `dateRetrieved` has non-blank text that isn't `YYYY-MM-DD`.
    var hasInvalidDateRetrieved: Bool { !trimmedDateRetrieved.isEmpty && parsedDateRetrieved == nil }

    /// Only valid to call once `hasInvalidMSRP`/`hasInvalidDateRetrieved` are both false.
    func build() -> WishListItemMetadata {
        WishListItemMetadata(
            category: category.nilIfEmpty,
            manufacturer: manufacturer.nilIfEmpty,
            msrp: trimmedMSRP.isEmpty ? nil : parsedMSRP,
            officialProductURL: officialProductURL.nilIfEmpty,
            bestRetailerURL: bestRetailerURL.nilIfEmpty,
            primaryImageURL: primaryImageURL.nilIfEmpty,
            itemDescription: itemDescription.nilIfEmpty,
            specifications: specifications.nilIfEmpty,
            weight: weight.nilIfEmpty,
            caliber: caliber.nilIfEmpty,
            compatibility: compatibility.nilIfEmpty,
            purpose: purpose.nilIfEmpty,
            notes: notes.nilIfEmpty,
            availabilityStatus: availabilityStatus.nilIfEmpty,
            dateRetrieved: trimmedDateRetrieved.isEmpty ? nil : parsedDateRetrieved
        )
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
