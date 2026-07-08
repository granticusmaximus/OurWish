import SwiftUI

/// Replaces the "Create New Wish List" `<Modal>` in `App.tsx`.
struct CreateWishListSheet: View {
    var onCreate: (String) throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("New Wish List", systemImage: "gift.fill")
                .font(.title2.bold())
                .foregroundStyle(.tint)

            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            LabeledField("List Name") {
                TextField("e.g. Birthday, Holiday 2026", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .focused($nameFocused)
                    .onSubmit(submit)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .disabled(isSubmitting)
                Button(isSubmitting ? "Creating…" : "Create", action: submit)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(isSubmitting || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(minWidth: 380)
        .onAppear { nameFocused = true }
    }

    private func submit() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Wish list name is required"
            return
        }

        isSubmitting = true
        do {
            try onCreate(trimmed)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }
}
