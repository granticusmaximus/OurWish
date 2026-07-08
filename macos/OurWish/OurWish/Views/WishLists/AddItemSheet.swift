import AppKit
import OurWishCore
import SwiftUI

/// Replaces `AddItemForm.tsx`. Shared by the personal and collaborative flows — the
/// sidebar now owns which list is active, so this always adds to "the list you're
/// currently looking at" rather than offering its own list picker.
struct AddItemSheet: View {
    var onClose: () -> Void
    var onSubmit: (
        _ productName: String,
        _ price: Double,
        _ quantity: Int,
        _ url: String?,
        _ imageData: Data?,
        _ metadata: WishListItemMetadata
    ) async throws -> Void

    @State private var productName = ""
    @State private var price = ""
    @State private var quantity = "1"
    @State private var url = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false

    @State private var category = ""
    @State private var manufacturer = ""
    @State private var msrp = ""
    @State private var officialProductURL = ""
    @State private var bestRetailerURL = ""
    @State private var primaryImageURL = ""
    @State private var itemDescription = ""
    @State private var specifications = ""
    @State private var weight = ""
    @State private var caliber = ""
    @State private var compatibility = ""
    @State private var purpose = ""
    @State private var notes = ""
    @State private var availabilityStatus = ""
    @State private var dateRetrieved = ""
    @FocusState private var productNameFocused: Bool

    @State private var fetchedImageData: Data?
    @State private var isFetchingImage = false
    @State private var imageFetchTask: Task<Void, Never>?

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
                    TextField("Optional — we'll try to grab a photo", text: $url)
                }

                LabeledField("Category") {
                    TextField("Rifle, Optic, Magazine...", text: $category)
                }

                LabeledField("Manufacturer") {
                    TextField("Radian Weapons", text: $manufacturer)
                }

                HStack(spacing: 14) {
                    LabeledField("MSRP") {
                        TextField("Optional", text: $msrp)
                    }
                    LabeledField("Availability") {
                        TextField("In Stock / Out of Stock / Backorder", text: $availabilityStatus)
                    }
                }

                LabeledField("Purpose") {
                    TextField("Home Defense, Hunting...", text: $purpose)
                }

                LabeledField("Official Product URL") {
                    TextField("Optional", text: $officialProductURL)
                }

                LabeledField("Best Retailer URL") {
                    TextField("Optional", text: $bestRetailerURL)
                }

                LabeledField("Primary Image URL") {
                    TextField("Optional", text: $primaryImageURL)
                }

                LabeledField("Specifications") {
                    TextEditor(text: $specifications)
                        .frame(minHeight: 72)
                        .padding(6)
                        .background(.background, in: RoundedRectangle(cornerRadius: 8))
                }

                HStack(spacing: 14) {
                    LabeledField("Weight") {
                        TextField("Optional", text: $weight)
                    }
                    LabeledField("Caliber") {
                        TextField("Optional", text: $caliber)
                    }
                }

                LabeledField("Compatibility") {
                    TextField("AR-15, M-LOK...", text: $compatibility)
                }

                LabeledField("Date Retrieved") {
                    TextField("YYYY-MM-DD", text: $dateRetrieved)
                }

                LabeledField("Description") {
                    TextEditor(text: $itemDescription)
                        .frame(minHeight: 72)
                        .padding(6)
                        .background(.background, in: RoundedRectangle(cornerRadius: 8))
                }

                LabeledField("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 72)
                        .padding(6)
                        .background(.background, in: RoundedRectangle(cornerRadius: 8))
                }

                imagePreview
            }
            .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button("Cancel", action: onClose)
                    .disabled(isSubmitting)
                Button("Add to List", action: submit)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(isSubmitting || !isValid)
            }
        }
        .padding(24)
        .frame(minWidth: 420)
        .onAppear { productNameFocused = true }
        .onChange(of: url, initial: false) { _, newValue in
            scheduleImageFetch(for: newValue)
        }
    }

    @ViewBuilder
    private var imagePreview: some View {
        if isFetchingImage {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Looking for a product photo…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else if let fetchedImageData, let nsImage = NSImage(data: fetchedImageData) {
            HStack(spacing: 8) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator))

                Text("Photo found")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Remove", role: .destructive) { self.fetchedImageData = nil }
                    .buttonStyle(.borderless)
                    .font(.caption)
            }
        }
    }

    private var isValid: Bool {
        !productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && Double(price) != nil
            && (Int(quantity).map { $0 >= 1 } ?? false)
    }

    private func scheduleImageFetch(for rawURL: String) {
        imageFetchTask?.cancel()
        fetchedImageData = nil
        isFetchingImage = false

        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, URL(string: trimmed) != nil else { return }

        imageFetchTask = Task {
            // Debounce so we don't fire a fetch on every keystroke while pasting/typing.
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }

            isFetchingImage = true
            let data = await ProductImageFetcher.fetchImageData(for: trimmed)
            guard !Task.isCancelled else { return }

            fetchedImageData = data
            isFetchingImage = false
        }
    }

    private func submit() {
        guard let parsedPrice = Double(price), let parsedQuantity = Int(quantity), parsedQuantity >= 1 else {
            errorMessage = "Product name, price, and quantity are required"
            return
        }
        let parsedMsrp = msrp.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : Double(msrp)
        if msrp.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false && parsedMsrp == nil {
            errorMessage = "MSRP must be a valid number"
            return
        }

        let trimmedDate = dateRetrieved.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsedDate: Date?
        if trimmedDate.isEmpty {
            parsedDate = nil
        } else {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .iso8601)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "yyyy-MM-dd"
            parsedDate = formatter.date(from: trimmedDate)
            if parsedDate == nil {
                errorMessage = "Date Retrieved must use YYYY-MM-DD"
                return
            }
        }

        isSubmitting = true
        Task { @MainActor in
            do {
                let metadata = WishListItemMetadata(
                    category: category.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    manufacturer: manufacturer.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    msrp: parsedMsrp,
                    officialProductURL: officialProductURL.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    bestRetailerURL: bestRetailerURL.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    primaryImageURL: primaryImageURL.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    itemDescription: itemDescription.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    specifications: specifications.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    weight: weight.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    caliber: caliber.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    compatibility: compatibility.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    purpose: purpose.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    availabilityStatus: availabilityStatus.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    dateRetrieved: parsedDate
                )
                try await onSubmit(
                    productName.trimmingCharacters(in: .whitespacesAndNewlines),
                    parsedPrice,
                    parsedQuantity,
                    url.isEmpty ? nil : url,
                    fetchedImageData,
                    metadata
                )
                onClose()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
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
