import Foundation
import GRDB

/// Resolves the on-disk location of the OurWish SQLite database and owns the single
/// `DatabaseQueue` used throughout the app.
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

    /// Opens (creating if necessary), migrates, and seeds the database at the resolved path.
    public static func makeQueue() throws -> DatabaseQueue {
        let url = try resolveDatabaseURL()
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let dbQueue = try DatabaseQueue(path: url.path)
        try AppDatabase.migrator.migrate(dbQueue)
        try AppDatabase.seedDefaultUserIfNeeded(dbQueue)
        return dbQueue
    }

    /// The shared, process-wide database queue. Lazily created on first access.
    public static let shared: DatabaseQueue = {
        do {
            return try makeQueue()
        } catch {
            fatalError("Failed to open OurWish database: \(error)")
        }
    }()
}
