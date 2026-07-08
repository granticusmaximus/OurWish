import AppKit
import OurWishCore
import SwiftUI

/// Replaces `AddItemForm.tsx`. Shared by the personal and collaborative flows — the
/// sidebar now owns which list is active, so this always adds to "the list you're
/// currently looking at" rather than offering its own list picker.
struct AddItemSheet: View {
    var onClose: () -> Void
    var onSubmit: (
        _ productName: String, _ price: Double, _ quantity: Int, _ url: String?, _ imageData: Data?
    ) async throws -> Void

    @State private var productName = ""
    @State private var price = ""
    @State private var quantity = "1"
    @State private var url = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false
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

        isSubmitting = true
        Task { @MainActor in
            do {
                try await onSubmit(
                    productName.trimmingCharacters(in: .whitespacesAndNewlines),
                    parsedPrice,
                    parsedQuantity,
                    url.isEmpty ? nil : url,
                    fetchedImageData
                )
                onClose()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
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
