import SwiftUI

/// Inline rename control for a wish list — only used in the personal (non-collaborative)
/// table, matching the original's `!isCollaborative && onUpdateName` guard. The list's
/// name is already shown in the window's navigation title, so this only surfaces the
/// item count plus a compact "Rename" affordance rather than repeating the title.
struct EditableListNameView: View {
    let name: String
    let itemCount: Int
    var onRename: (String) -> Void

    @State private var isEditing = false
    @State private var draft = ""

    var body: some View {
        HStack(spacing: 10) {
            if isEditing {
                TextField("List name", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 260)
                    .onSubmit(commit)
                Button("Save", action: commit)
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Cancel") { isEditing = false }
            } else {
                Text(itemCount == 1 ? "1 item" : "\(itemCount) items")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button {
                    draft = name
                    isEditing = true
                } label: {
                    Label("Rename", systemImage: "pencil")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help("Rename this list")
            }
        }
    }

    private func commit() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onRename(trimmed)
        isEditing = false
    }
}
