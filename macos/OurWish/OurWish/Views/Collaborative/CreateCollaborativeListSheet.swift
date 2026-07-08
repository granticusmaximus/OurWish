import OurWishCore
import SwiftUI

/// Replaces the create `<Modal>` in `CollaborativeLists.tsx`.
struct CreateCollaborativeListSheet: View {
    let partners: [User]
    var onCreate: (_ partnerEmail: String, _ name: String) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var partnerEmail = ""
    @State private var listName = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("New Collaborative List", systemImage: "person.2.fill")
                .font(.title2.bold())
                .foregroundStyle(.tint)

            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            if partners.isEmpty {
                Label("Create another user account first to start a collaborative list.", systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                LabeledField("Partner") {
                    Picker("", selection: $partnerEmail) {
                        Text("Select partner").tag("")
                        ForEach(partners) { partner in
                            Text("\(partner.displayName) — \(partner.email)").tag(partner.email)
                        }
                    }
                    .labelsHidden()
                }
            }

            LabeledField("List Name") {
                TextField("e.g. Bedroom Furniture, Vacation Trip", text: $listName)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .disabled(isSubmitting)
                Button(isSubmitting ? "Creating…" : "Create", action: submit)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        isSubmitting || partners.isEmpty || partnerEmail.isEmpty
                            || listName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
            }
        }
        .padding(24)
        .frame(minWidth: 420)
    }

    private func submit() {
        isSubmitting = true
        Task { @MainActor in
            do {
                try await onCreate(partnerEmail, listName.trimmingCharacters(in: .whitespacesAndNewlines))
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}
