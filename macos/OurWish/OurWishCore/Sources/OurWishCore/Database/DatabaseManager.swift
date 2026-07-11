import Foundation
import GRDB

/// Resolves the on-disk location of the OurWish SQLite database and owns the single
/// `DatabasePool` used throughout the app.
///
/// The database intentionally lives outside the app bundle, at
/// `~/Library/Application Support/OurWish/ourwish.db`, so a Debug build launched from
/// Xcode and a Release build launched as an installed app read and write the exact same
/// file. This only works because the app runs with App Sandbox disabled — a sandboxed
/// app would be given a per-app-container Application Support path instead, which could
/// differ between build configurations.
public enum DatabaseManager {
    /// Overrides the resolved database path. Mirrors the original server's
    /// `OURWISH_DB_PATH` environment variable, and lets tests point at a throwaway
    /// location instead of touching real user data.
    private static let pathOverrideEnvironmentKey = "OURWISH_DB_PATH"

    public static func resolveDatabaseURL(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) throws -> URL {
        if let override = environment[pathOverrideEnvironmentKey], !override.isEmpty {
            return URL(fileURLWithPath: override)
        }

        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return appSupport
            .appendingPathComponent("OurWish", isDirectory: true)
            .appendingPathComponent("ourwish.db")
    }

    /// Opens (creating if necessary), migrates, and seeds the database at the resolved
    /// path. A `DatabasePool` (WAL mode, one writer + a pool of concurrent readers)
    /// rather than a `DatabaseQueue` (one serialized connection) — this database is
    /// accessed both by the native UI and, whenever the embedded HTTP server is
    /// running in-process (see `OurWishApp`), by every request that server handles.
    /// With a single `DatabaseQueue` those two callers would serialize behind each
    /// other; `DatabasePool` lets UI reads and server reads proceed concurrently.
    public static func makeDatabase() throws -> DatabasePool {
        let url = try resolveDatabaseURL()
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let dbPool = try DatabasePool(path: url.path)
        try AppDatabase.migrator.migrate(dbPool)
        try AppDatabase.seedDefaultUserIfNeeded(dbPool)
        return dbPool
    }

    /// The shared, process-wide database connection. Lazily created on first access.
    public static let shared: DatabasePool = {
        do {
            return try makeDatabase()
        } catch {
            fatalError("Failed to open OurWish database: \(error)")
        }
    }()
}
