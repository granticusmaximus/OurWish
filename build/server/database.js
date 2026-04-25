import initSqlJs from 'sql.js';
import * as fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { dirname } from 'path';
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const configuredDbPath = process.env.OURWISH_DB_PATH?.trim();
const dbPath = configuredDbPath
    ? path.resolve(configuredDbPath)
    : path.join(__dirname, '../ourwish.db');
let db = null;
function hasCollaborativePairUniqueConstraint(database) {
    const indexList = database.exec(`PRAGMA index_list('collaborative_lists')`);
    if (!indexList.length || !indexList[0].values) {
        return false;
    }
    for (const row of indexList[0].values) {
        const indexName = String(row[1]);
        const isUnique = Number(row[2]) === 1;
        if (!isUnique) {
            continue;
        }
        const escapedIndexName = indexName.replace(/'/g, "''");
        const indexInfo = database.exec(`PRAGMA index_info('${escapedIndexName}')`);
        if (!indexInfo.length || !indexInfo[0].values) {
            continue;
        }
        const indexedColumns = indexInfo[0].values
            .map((indexRow) => String(indexRow[2]))
            .sort();
        if (indexedColumns.length === 2 &&
            indexedColumns[0] === 'user1_id' &&
            indexedColumns[1] === 'user2_id') {
            return true;
        }
    }
    return false;
}
async function initDB() {
    const SQL = await initSqlJs();
    const dbDir = path.dirname(dbPath);
    if (!fs.existsSync(dbDir)) {
        fs.mkdirSync(dbDir, { recursive: true });
    }
    if (fs.existsSync(dbPath)) {
        const buffer = fs.readFileSync(dbPath);
        db = new SQL.Database(buffer);
    }
    else {
        db = new SQL.Database();
    }
}
function saveDB() {
    if (db) {
        const data = db.export();
        const buffer = Buffer.from(data);
        fs.writeFileSync(dbPath, buffer);
    }
}
export async function initializeDatabase() {
    await initDB();
    if (!db) {
        throw new Error('Database not initialized');
    }
    // Users table
    db.run(`
    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      first_name TEXT NOT NULL,
      last_name TEXT NOT NULL,
      display_name TEXT NOT NULL,
      email TEXT UNIQUE NOT NULL,
      password TEXT NOT NULL,
      wish_list_name TEXT DEFAULT 'My Wish List',
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  `);
    // Add wish_list_name column if it doesn't exist (for existing databases)
    try {
        db.run(`ALTER TABLE users ADD COLUMN wish_list_name TEXT DEFAULT 'My Wish List'`);
    }
    catch {
        // Column already exists, ignore error
    }
    // Wish list items table
    db.run(`
    CREATE TABLE IF NOT EXISTS wish_list_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      list_id INTEGER,
      product_name TEXT NOT NULL,
      price REAL NOT NULL,
      url TEXT,
      is_purchased INTEGER DEFAULT 0,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      FOREIGN KEY (list_id) REFERENCES wish_lists(id) ON DELETE CASCADE
    )
  `);
    // Wish lists table
    db.run(`
    CREATE TABLE IF NOT EXISTS wish_lists (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      name TEXT NOT NULL DEFAULT 'My Wish List',
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )
  `);
    // Add list_id column to wish_list_items if it doesn't exist
    try {
        db.run(`ALTER TABLE wish_list_items ADD COLUMN list_id INTEGER REFERENCES wish_lists(id) ON DELETE CASCADE`);
    }
    catch {
        // Column already exists, ignore error
    }
    // Collaborative wish lists table
    db.run(`
    CREATE TABLE IF NOT EXISTS collaborative_lists (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      user1_id INTEGER NOT NULL,
      user2_id INTEGER NOT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user1_id) REFERENCES users(id) ON DELETE CASCADE,
      FOREIGN KEY (user2_id) REFERENCES users(id) ON DELETE CASCADE
    )
  `);
    // Migration: remove old UNIQUE(user1_id, user2_id) to allow multiple lists per user pair.
    if (hasCollaborativePairUniqueConstraint(db)) {
        try {
            db.run('PRAGMA foreign_keys = OFF');
            db.run('BEGIN TRANSACTION');
            db.run(`
        CREATE TABLE collaborative_lists_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          user1_id INTEGER NOT NULL,
          user2_id INTEGER NOT NULL,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (user1_id) REFERENCES users(id) ON DELETE CASCADE,
          FOREIGN KEY (user2_id) REFERENCES users(id) ON DELETE CASCADE
        )
      `);
            db.run(`
        INSERT INTO collaborative_lists_new (id, name, user1_id, user2_id, created_at)
        SELECT id, name, user1_id, user2_id, created_at
        FROM collaborative_lists
      `);
            db.run('DROP TABLE collaborative_lists');
            db.run('ALTER TABLE collaborative_lists_new RENAME TO collaborative_lists');
            db.run('COMMIT');
            db.run('PRAGMA foreign_keys = ON');
            console.log('Collaborative list schema migrated to allow multiple lists per user pair');
        }
        catch (error) {
            db.run('ROLLBACK');
            db.run('PRAGMA foreign_keys = ON');
            throw error;
        }
    }
    // Collaborative items table
    db.run(`
    CREATE TABLE IF NOT EXISTS collaborative_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      list_id INTEGER NOT NULL,
      product_name TEXT NOT NULL,
      price REAL NOT NULL,
      url TEXT,
      is_purchased INTEGER DEFAULT 0,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (list_id) REFERENCES collaborative_lists(id) ON DELETE CASCADE
    )
  `);
    console.log('Database tables initialized');
    // Insert default user if not exists
    db.run(`INSERT OR IGNORE INTO users (first_name, last_name, display_name, email, password)
     VALUES (?, ?, ?, ?, ?)`, ['Grant', 'Watson', 'Grant', 'grant@gwsapp.net', 'Wats#0529']);
    console.log('Default user initialized');
    // Create default wish list for users who don't have one
    const users = db.exec('SELECT id, wish_list_name FROM users');
    if (users.length > 0 && users[0].values) {
        for (const row of users[0].values) {
            const userId = row[0];
            const wishListName = row[1] || 'My Wish List';
            // Check if user already has a wish list
            const existingLists = db.exec(`SELECT id FROM wish_lists WHERE user_id = ${userId}`);
            if (!existingLists.length || !existingLists[0].values || existingLists[0].values.length === 0) {
                // Create default wish list
                db.run('INSERT INTO wish_lists (user_id, name) VALUES (?, ?)', [userId, wishListName]);
                // Get the newly created list ID
                const listResult = db.exec(`SELECT id FROM wish_lists WHERE user_id = ${userId} ORDER BY id DESC LIMIT 1`);
                if (listResult.length > 0 && listResult[0].values && listResult[0].values.length > 0) {
                    const listId = listResult[0].values[0][0];
                    // Update existing items to use this list_id
                    db.run('UPDATE wish_list_items SET list_id = ? WHERE user_id = ? AND list_id IS NULL', [listId, userId]);
                }
            }
        }
    }
    console.log('Default wish lists created');
    saveDB();
}
export function runQuery(sql, params = []) {
    return new Promise((resolve, reject) => {
        try {
            if (!db) {
                throw new Error('Database not initialized');
            }
            const stmt = db.prepare(sql);
            stmt.bind(params);
            const rows = [];
            while (stmt.step()) {
                rows.push(stmt.getAsObject());
            }
            stmt.free();
            resolve(rows);
        }
        catch (err) {
            reject(err);
        }
    });
}
export function runUpdate(sql, params = []) {
    return new Promise((resolve, reject) => {
        try {
            if (!db) {
                throw new Error('Database not initialized');
            }
            db.run(sql, params);
            const result = db.exec('SELECT last_insert_rowid() as id, changes() as changes');
            saveDB();
            if (result[0] && result[0].values[0]) {
                resolve({
                    id: result[0].values[0][0],
                    changes: result[0].values[0][1]
                });
            }
            else {
                resolve({ id: 0, changes: 0 });
            }
        }
        catch (err) {
            reject(err);
        }
    });
}
export { db };
