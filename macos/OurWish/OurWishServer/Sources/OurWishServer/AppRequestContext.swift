import Hummingbird

/// Custom request context threading the authenticated `userId` (set by
/// `AuthMiddleware` once a bearer token resolves) through to route handlers.
struct AppRequestContext: RequestContext {
    var coreContext: CoreRequestContextStorage
    var userId: Int64?
    var authToken: String?

    init(source: Source) {
        self.coreContext = .init(source: source)
        self.userId = nil
        self.authToken = nil
    }
}
