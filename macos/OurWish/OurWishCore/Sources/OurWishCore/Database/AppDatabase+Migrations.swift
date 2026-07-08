import GRDB

extension AppDatabase {
    /// One clean migration creating the final schema directly. Unlike the original
    /// server (which incrementally `ALTER TABLE ... IF NOT EXISTS`'d an evolving sql.js
    /// database), this is a brand-new database with no legacy rows to preserve.
    public static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1CreateSchema") { db in
            try db.create(table: "users") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("first_name", .text).notNull()
                t.column("last_name", .text).notNull()
                t.column("display_name", .text).notNull()
                t.column("email", .text).notNull().unique()
                t.column("password_hash", .text).notNull()
                t.column("wish_list_name", .text).notNull().defaults(to: "My Wish List")
                t.column("created_at", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
            }

            try db.create(table: "wish_lists") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("user_id", .integer).notNull().indexed()
                    .references("users", onDelete: .cascade)
                t.column("name", .text).notNull().defaults(to: "My Wish List")
                t.column("created_at", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
            }

            try db.create(table: "wish_list_items") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("user_id", .integer).notNull().indexed()
                    .references("users", onDelete: .cascade)
                t.column("list_id", .integer).notNull().indexed()
                    .references("wish_lists", onDelete: .cascade)
                t.column("product_name", .text).notNull()
                t.column("price", .double).notNull()
                t.column("quantity", .integer).notNull().defaults(to: 1)
                t.column("url", .text)
                t.column("is_purchased", .boolean).notNull().defaults(to: false)
                t.column("is_hidden", .boolean).notNull().defaults(to: false)
                t.column("created_at", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
            }

            // No UNIQUE(user1_id, user2_id): matches the original's post-migration schema,
            // which deliberately allows multiple collaborative lists per user pair.
            try db.create(table: "collaborative_lists") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("user1_id", .integer).notNull().indexed()
                    .references("users", onDelete: .cascade)
                t.column("user2_id", .integer).notNull().indexed()
                    .references("users", onDelete: .cascade)
                t.column("created_at", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
            }

            try db.create(table: "collaborative_items") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("list_id", .integer).notNull().indexed()
                    .references("collaborative_lists", onDelete: .cascade)
                t.column("product_name", .text).notNull()
                t.column("price", .double).notNull()
                t.column("quantity", .integer).notNull().defaults(to: 1)
                t.column("url", .text)
                t.column("is_purchased", .boolean).notNull().defaults(to: false)
                t.column("created_at", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
            }
        }

        return migrator
    }
}
