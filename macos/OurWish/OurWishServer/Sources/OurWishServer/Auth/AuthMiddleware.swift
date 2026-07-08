import Hummingbird

/// Resolves `Authorization: Bearer <token>` into `context.userId`, rejecting with 401
/// if missing or invalid. Applied to every route except login/health — this is the
/// server-side enforcement that didn't need to exist when the app had no network
/// client (see the plan's note on why `AuthStore.register()`'s "must be logged in"
/// rule can no longer be UI-only once a LAN-reachable API exists).
struct AuthMiddleware: RouterMiddleware {
    let tokenStore: TokenStore

    func handle(
        _ request: Request,
        context: AppRequestContext,
        next: (Request, AppRequestContext) async throws -> Response
    ) async throws -> Response {
        guard let authHeader = request.headers[.authorization],
              authHeader.hasPrefix("Bearer ") else {
            throw HTTPError(.unauthorized, message: "Missing or malformed Authorization header")
        }

        let token = String(authHeader.dropFirst("Bearer ".count))
        guard let userId = try await tokenStore.userId(for: token) else {
            throw HTTPError(.unauthorized, message: "Invalid or expired session")
        }

        var context = context
        context.userId = userId
        context.authToken = token
        return try await next(request, context)
    }
}
