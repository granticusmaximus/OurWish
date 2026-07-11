import Foundation
#if canImport(Observation)
import Observation
#endif

/// Tracks the authenticated user for either local or remote-backed app modes.
#if canImport(Observation)
@MainActor
@Observable
public final class AuthStore {
    public private(set) var currentUser: User?
    public private(set) var userCount: Int = 0
    public var lastError: String?

    private let service: any AuthStoreService

    public init(service: any AuthStoreService = LocalAuthStoreService()) {
        self.service = service
    }

    public func refreshUserCount() {
        Task {
            do {
                userCount = try await service.userCount()
                lastError = nil
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    public func login(email: String, password: String) async throws {
        currentUser = try await service.login(email: email, password: password)
        refreshUserCount()
    }

    public func logout() async {
        try? await service.logout()
        currentUser = nil
    }

    /// Only reachable from the main window's "Create New User" action, i.e. while
    /// already logged in as someone.
    public func register(firstName: String, lastName: String, email: String, password: String) async throws {
        try await service.register(firstName: firstName, lastName: lastName, email: email, password: password)
        refreshUserCount()
    }

    /// Updates the logged-in user's profile and refreshes `currentUser` so the UI
    /// (toolbar avatar, welcome text, etc.) reflects the change immediately.
    public func updateProfile(
        firstName: String,
        lastName: String,
        displayName: String,
        bio: String?,
        profileImageData: Data?
    ) async throws {
        guard let userId = currentUser?.id else { return }
        currentUser = try await service.updateProfile(
            userId: userId,
            firstName: firstName,
            lastName: lastName,
            displayName: displayName,
            bio: bio,
            profileImageData: profileImageData
        )
    }

    public func changePassword(currentPassword: String, newPassword: String) async throws {
        guard let userId = currentUser?.id else { return }
        try await service.changePassword(userId: userId, currentPassword: currentPassword, newPassword: newPassword)
    }
}
#endif
