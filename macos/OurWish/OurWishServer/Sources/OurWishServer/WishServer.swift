import GRDB
import Hummingbird
import OurWishCore

/// The embedded HTTP API — runs inside the same process as the SwiftUI app, calling
/// directly into `OurWishCore`'s repositories against the same `DatabaseQueue` the
/// native UI uses. No second database connection, no duplicated business logic.
public struct WishServer: Sendable {
    /// The port used both by the app (`OurWishApp.swift`) and the standalone
    /// command-line runner (`RunServer`), so it's only defined in one place.
    public static let defaultPort = 8420

    private let dbWriter: any DatabaseWriter

    public init(dbWriter: any DatabaseWriter = DatabaseManager.shared) {
        self.dbWriter = dbWriter
    }

    public func run(port: Int = WishServer.defaultPort) async throws {
        let tokenStore = TokenStore()
        let userRepository = UserRepository(dbWriter: dbWriter)
        let wishListRepository = WishListRepository(dbWriter: dbWriter)
        let authMiddleware = AuthMiddleware(tokenStore: tokenStore)

        let router = Router(context: AppRequestContext.self)
        router.add(
            middleware: CORSMiddleware(
                allowOrigin: .originBased,
                allowMethods: [.get, .post, .put, .delete, .head, .options]
            )
        )

        router.get("/health") { _, _ in "OK" }

        let authRoutes = AuthRoutes(userRepository: userRepository, tokenStore: tokenStore)
        authRoutes.addPublicRoutes(to: router.group("/api/v1/auth"))
        authRoutes.addProtectedRoutes(to: router.group("/api/v1/auth").add(middleware: authMiddleware))
        authRoutes.addUserImageRoute(to: router.group("/api/v1/users").add(middleware: authMiddleware))

        let wishListRoutes = WishListRoutes(repository: wishListRepository)
        wishListRoutes.addRoutes(to: router.group("/api/v1").add(middleware: authMiddleware))
        wishListRoutes.addImageRoute(to: router.group("/api/v1/items").add(middleware: authMiddleware))

        let collaborativeRepository = CollaborativeListRepository(dbWriter: dbWriter)
        let collaborativeRoutes = CollaborativeRoutes(repository: collaborativeRepository, userRepository: userRepository)
        collaborativeRoutes.addRoutes(to: router.group("/api/v1").add(middleware: authMiddleware))
        collaborativeRoutes.addImageRoute(to: router.group("/api/v1/collaborative-items").add(middleware: authMiddleware))

        let app = Application(
            router: router,
            configuration: .init(address: .hostname("0.0.0.0", port: port))
        )
        try await app.runService()
    }
}
