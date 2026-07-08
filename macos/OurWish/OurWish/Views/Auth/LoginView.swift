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
                colors: [BrandColor.gradientStart.opacity(0.18), BrandColor.gradientEnd.opacity(0.08)],
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
        Task { @MainActor in
            do {
                try await authStore.login(email: email, password: password)
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoggingIn = false
        }
    }
}

/// The app's brand mark — mirrors the generated app icon's gradient + glyph
/// (`Assets.xcassets/AppIcon.appiconset`) exactly, drawn in SwiftUI so it stays crisp
/// at any size instead of embedding a raster image.
struct AppGlyph: View {
    var size: CGFloat = 72

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.306, style: .continuous)
                .fill(BrandColor.gradient)
                .frame(width: size, height: size)
                .shadow(color: BrandColor.gradientEnd.opacity(0.35), radius: size * 0.167, y: size * 0.083)

            Image(systemName: "gift.fill")
                .font(.system(size: size * 0.44, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}
