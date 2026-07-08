import Foundation
import GRDB
import Observation

/// In-memory "who's logged in right now" concept, replacing the original app's
/// server-side `express-session` cookie. There's no network boundary here, so logging
/// out just clears this and logging back in re-authenticates against the local DB;
/// nothing is persisted across app launches (matches the original's session lifetime
/// being tied to the server process, just shorter — a deliberate simplification since
/// there's no separate "server" to keep a session alive between launches).
@MainActor
@Observable
public final class AuthStore {
    public private(set) var currentUser: User?
    public private(set) var userCount: Int = 0
    public var lastError: String?

    private let userRepository: UserRepository

    public init(dbWriter: any DatabaseWriter = DatabaseManager.shared) {
        self.userRepository = UserRepository(dbWriter: dbWriter)
        refreshUserCount()
    }

    public func refreshUserCount() {
        do {
            userCount = try userRepository.count()
        } catch {
            lastError = error.localizedDescription
        }
    }

    public func login(email: String, password: String) throws {
        currentUser = try userRepository.login(email: email, password: password)
    }

    public func logout() {
        currentUser = nil
    }

    /// Only reachable from the main window's "Create New User" action, i.e. while
    /// already logged in as someone — mirrors the original's `req.session.userId`
    /// requirement, which is enforced by UI navigation rather than a repository check
    /// since there's no separate untrusted client here.
    public func register(firstName: String, lastName: String, email: String, password: String) throws {
        try userRepository.createUser(firstName: firstName, lastName: lastName, email: email, password: password)
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
    ) throws {
        guard let userId = currentUser?.id else { return }
        currentUser = try userRepository.updateProfile(
            userId: userId,
            firstName: firstName,
            lastName: lastName,
            displayName: displayName,
            bio: bio,
            profileImageData: profileImageData
        )
    }

    public func changePassword(currentPassword: String, newPassword: String) throws {
        guard let userId = currentUser?.id else { return }
        try userRepository.updatePassword(userId: userId, currentPassword: currentPassword, newPassword: newPassword)
    }
}
