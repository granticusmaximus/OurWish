import AppKit
import OurWishCore
import SwiftUI
import UniformTypeIdentifiers

/// Lets the logged-in user update their name, bio, profile picture, and password.
/// Reachable from the account menu in `MainWindowView`'s toolbar.
struct ProfileView: View {
    @Environment(AuthStore.self) private var authStore
    @Environment(\.dismiss) private var dismiss

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var displayName = ""
    @State private var email = ""
    @State private var bio = ""
    @State private var profileImageData: Data?
    @State private var isImporterPresented = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var isSaving = false

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var passwordErrorMessage: String?
    @State private var passwordSuccessMessage: String?
    @State private var isChangingPassword = false

    @State private var showDeleteAccountConfirm = false
    @State private var deleteAccountErrorMessage: String?
    @State private var isDeletingAccount = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                profileSection
                Divider()
                passwordSection
                Divider()
                deleteAccountSection
            }
            .padding(28)
        }
        .frame(width: 480, height: 720)
        .onAppear(perform: loadCurrentUser)
    }

    private var header: some View {
        HStack {
            Text("Edit Profile")
                .font(.title2.bold())
            Spacer()
            Button("Done") { dismiss() }
        }
    }

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                avatarView

                VStack(alignment: .leading, spacing: 6) {
                    Button("Change Photo…") { isImporterPresented = true }
                    if profileImageData != nil {
                        Button("Remove Photo", role: .destructive) { profileImageData = nil }
                            .buttonStyle(.borderless)
                    }
                }
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.callout)
            }
            if let successMessage {
                Label(successMessage, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.callout)
            }

            HStack(spacing: 14) {
                LabeledField("First Name") { TextField("", text: $firstName) }
                LabeledField("Last Name") { TextField("", text: $lastName) }
            }
            LabeledField("Display Name") { TextField("", text: $displayName) }
            LabeledField("Email") { TextField("", text: $email) }
            LabeledField("Bio") {
                TextEditor(text: $bio)
                    .font(.body)
                    .frame(height: 80)
                    .padding(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(.separator)
                    )
            }
            .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button(isSaving ? "Saving…" : "Save Profile", action: saveProfile)
                    .buttonStyle(.borderedProminent)
                    .disabled(isSaving || !isProfileValid)
            }
        }
        .fileImporter(isPresented: $isImporterPresented, allowedContentTypes: [.image]) { result in
            switch result {
            case .success(let url):
                if let data = ImageResizing.resizedJPEGData(from: url) {
                    profileImageData = data
                    errorMessage = nil
                } else {
                    errorMessage = "Couldn't load that image"
                }
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }

    private var avatarView: some View {
        Group {
            if let profileImageData, let nsImage = NSImage(data: profileImageData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(.separator, lineWidth: 1))
    }

    private var passwordSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Change Password")
                .font(.headline)

            if let passwordErrorMessage {
                Label(passwordErrorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.callout)
            }
            if let passwordSuccessMessage {
                Label(passwordSuccessMessage, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.callout)
            }

            VStack(spacing: 10) {
                LabeledField("Current Password") { SecureField("", text: $currentPassword) }
                LabeledField("New Password") { SecureField("", text: $newPassword) }
                LabeledField("Confirm New Password") { SecureField("", text: $confirmPassword) }
            }
            .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button(isChangingPassword ? "Updating…" : "Update Password", action: changePassword)
                    .buttonStyle(.bordered)
                    .disabled(isChangingPassword || !isPasswordFormValid)
            }
        }
    }

    private var isProfileValid: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isPasswordFormValid: Bool {
        !currentPassword.isEmpty && !newPassword.isEmpty && newPassword == confirmPassword
    }

    private func loadCurrentUser() {
        guard let user = authStore.currentUser else { return }
        firstName = user.firstName
        lastName = user.lastName
        displayName = user.displayName
        email = user.email
        bio = user.bio ?? ""
        profileImageData = user.profileImageData
    }

    private func saveProfile() {
        isSaving = true
        Task { @MainActor in
            do {
                try await authStore.updateProfile(
                    firstName: firstName,
                    lastName: lastName,
                    displayName: displayName,
                    email: email,
                    bio: bio.isEmpty ? nil : bio,
                    profileImageData: profileImageData
                )
                successMessage = "Profile updated"
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
                successMessage = nil
            }
            isSaving = false
        }
    }

    private func changePassword() {
        guard newPassword == confirmPassword else {
            passwordErrorMessage = "New passwords don't match"
            passwordSuccessMessage = nil
            return
        }

        isChangingPassword = true
        Task { @MainActor in
            do {
                try await authStore.changePassword(currentPassword: currentPassword, newPassword: newPassword)
                passwordSuccessMessage = "Password updated"
                passwordErrorMessage = nil
                currentPassword = ""
                newPassword = ""
                confirmPassword = ""
            } catch {
                passwordErrorMessage = error.localizedDescription
                passwordSuccessMessage = nil
            }
            isChangingPassword = false
        }
    }

    private var deleteAccountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Delete Account")
                .font(.headline)

            Text("Permanently deletes your account and everything in it — wish lists, items, and any lists shared with a partner. This can't be undone.")
                .font(.callout)
                .foregroundStyle(.secondary)

            if let deleteAccountErrorMessage {
                Label(deleteAccountErrorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            Button(isDeletingAccount ? "Deleting…" : "Delete Account", role: .destructive) {
                showDeleteAccountConfirm = true
            }
            .disabled(isDeletingAccount)
        }
        .confirmationDialog(
            "Delete your account?",
            isPresented: $showDeleteAccountConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Account", role: .destructive, action: deleteAccount)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes your account, your wish lists, and any lists shared with a partner. This can't be undone.")
        }
    }

    private func deleteAccount() {
        isDeletingAccount = true
        Task { @MainActor in
            do {
                try await authStore.deleteAccount()
                dismiss()
            } catch {
                deleteAccountErrorMessage = error.localizedDescription
            }
            isDeletingAccount = false
        }
    }
}
