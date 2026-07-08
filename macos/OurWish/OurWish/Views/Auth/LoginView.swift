import OurWishCore
import SwiftUI

/// Replaces `Login.tsx`.
struct LoginView: View {
    @Environment(AuthStore.self) private var authStore

    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isLoggingIn = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case email, password
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.accentColor.opacity(0.18), Color.accentColor.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                AppGlyph()

                VStack(spacing: 6) {
                    Text("OurWish")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    Text("Welcome back")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.callout)
                            .foregroundStyle(.red)
                    }

                    TextField("Email", text: $email)
                        .textContentType(.username)
                        .focused($focusedField, equals: .email)
                        .onSubmit { focusedField = .password }

                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .focused($focusedField, equals: .password)
                        .onSubmit(login)
                }
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 320)

                Button(isLoggingIn ? "Logging in…" : "Log In", action: login)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isLoggingIn || email.isEmpty || password.isEmpty)
            }
            .padding(48)
            .frame(maxWidth: 440)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.15), radius: 24, y: 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { focusedField = .email }
    }

    private func login() {
        isLoggingIn = true
        do {
            try authStore.login(email: email, password: password)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoggingIn = false
    }
}

/// The app's brand mark — a simple glyph so the login/register screens don't feel bare
/// while a real app icon is designed.
struct AppGlyph: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 72, height: 72)
                .shadow(color: Color.accentColor.opacity(0.35), radius: 12, y: 6)

            Image(systemName: "gift.fill")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(.white)
        }
    }
}
