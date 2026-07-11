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

        // Adds user profile fields (bio, profile picture) on top of the v1 schema.
        // A separate migration rather than folding into v1CreateSchema, since anyone
        // who already launched the app has a v1 database that needs to gain these
        // columns in place rather than being recreated from scratch.
        migrator.registerMigration("v2AddUserProfileFields") { db in
            try db.alter(table: "users") { t in
                t.add(column: "bio", .text)
                t.add(column: "profile_image_data", .blob)
            }
        }

        // Adds a product image column to items, auto-populated from a product URL's
        // page metadata when available (see the app target's ProductImageFetcher).
        migrator.registerMigration("v3AddItemImages") { db in
            try db.alter(table: "wish_list_items") { t in
                t.add(column: "image_data", .blob)
            }
            try db.alter(table: "collaborative_items") { t in
                t.add(column: "image_data", .blob)
            }
        }

        // Persists bearer tokens so a standalone backend process can restart without
        // invalidating every logged-in client immediately.
        migrator.registerMigration("v4AddAuthTokens") { db in
            try db.create(table: "auth_tokens", ifNotExists: true) { t in
                t.column("token", .text).notNull().primaryKey()
                t.column("user_id", .integer).notNull().indexed()
                    .references("users", onDelete: .cascade)
                t.column("created_at", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
            }
        }

        // Adds rich product metadata columns used by the firearms-oriented wish list.
        migrator.registerMigration("v5AddWishListItemMetadata") { db in
            try db.alter(table: "wish_list_items") { t in
                t.add(column: "category", .text)
                t.add(column: "manufacturer", .text)
                t.add(column: "msrp", .double)
                t.add(column: "official_product_url", .text)
                t.add(column: "best_retailer_url", .text)
                t.add(column: "primary_image_url", .text)
                t.add(column: "item_description", .text)
                t.add(column: "specifications", .text)
                t.add(column: "weight", .text)
                t.add(column: "caliber", .text)
                t.add(column: "compatibility", .text)
                t.add(column: "purpose", .text)
                t.add(column: "notes", .text)
                t.add(column: "availability_status", .text)
                t.add(column: "date_retrieved", .datetime)
            }
        }

        // Brings `collaborative_items` to parity with `wish_list_items`: hide/show
        // support and the same rich product metadata columns added in v5.
        migrator.registerMigration("v6CollaborativeItemParity") { db in
            try db.alter(table: "collaborative_items") { t in
                t.add(column: "is_hidden", .boolean).notNull().defaults(to: false)
                t.add(column: "category", .text)
                t.add(column: "manufacturer", .text)
                t.add(column: "msrp", .double)
                t.add(column: "official_product_url", .text)
                t.add(column: "best_retailer_url", .text)
                t.add(column: "primary_image_url", .text)
                t.add(column: "item_description", .text)
                t.add(column: "specifications", .text)
                t.add(column: "weight", .text)
                t.add(column: "caliber", .text)
                t.add(column: "compatibility", .text)
                t.add(column: "purpose", .text)
                t.add(column: "notes", .text)
                t.add(column: "availability_status", .text)
                t.add(column: "date_retrieved", .datetime)
            }
        }

        return migrator
    }
}
