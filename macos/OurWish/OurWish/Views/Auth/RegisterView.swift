import OurWishCore
import SwiftUI

/// Replaces `Register.tsx`. Only reachable from `MainWindowView`'s "Create New User"
/// action (i.e. while already logged in), matching the original's navigation — the
/// original's server additionally required `req.session.userId` for this reason.
struct RegisterView: View {
    @Environment(AuthStore.self) private var authStore
    var onBack: () -> Void

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var isSubmitting = false
    @FocusState private var firstNameFocused: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [BrandColor.gradientStart.opacity(0.18), BrandColor.gradientEnd.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                AppGlyph()

                VStack(spacing: 6) {
                    Text("Create New User")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text("OurWish supports up to \(UserRepository.maxUsers) people")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.callout)
                            .foregroundStyle(.red)
                    }
                    if let successMessage {
                        Label(successMessage, systemImage: "checkmark.circle.fill")
                            .font(.callout)
                            .foregroundStyle(.green)
                    }

                    HStack {
                        TextField("First Name", text: $firstName)
                            .focused($firstNameFocused)
                        TextField("Last Name", text: $lastName)
                    }
                    TextField("Email", text: $email)
                        .textContentType(.username)
                    SecureField("Password", text: $password)
                        .textContentType(.newPassword)
                        .onSubmit(submit)
                }
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 360)

                HStack(spacing: 12) {
                    Button("Back", action: onBack)
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    Button(isSubmitting ? "Creating…" : "Create User", action: submit)
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(isSubmitting || authStore.userCount >= UserRepository.maxUsers || !isValid)
                }
            }
            .padding(48)
            .frame(maxWidth: 480)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.15), radius: 24, y: 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { firstNameFocused = true }
    }

    private var isValid: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !password.isEmpty
    }

    private func submit() {
        guard authStore.userCount < UserRepository.maxUsers else {
            errorMessage = "Maximum users (\(UserRepository.maxUsers)) already registered"
            return
        }

        isSubmitting = true
        Task { @MainActor in
            do {
                try await authStore.register(
                    firstName: firstName,
                    lastName: lastName,
                    email: email,
                    password: password
                )
                successMessage = "User created successfully!"
                errorMessage = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { onBack() }
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}
