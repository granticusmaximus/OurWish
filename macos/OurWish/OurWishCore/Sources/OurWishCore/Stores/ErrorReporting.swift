import Foundation

/// Shared by the `@Observable` stores: runs a throwing operation and mirrors its
/// outcome into `lastError`, so each store's refresh methods don't repeat the same
/// `do { ...; lastError = nil } catch { lastError = error.localizedDescription }` block.
@MainActor
protocol ErrorReporting: AnyObject {
    var lastError: String? { get set }
}

extension ErrorReporting {
    func runCatching(_ operation: () async throws -> Void) async {
        do {
            try await operation()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }
}
