import { Router } from 'express';
import { runQuery, runUpdate } from '../database.js';
const router = Router();
// Login endpoint
router.post('/login', async (req, res) => {
    const { email, password } = req.body;
    if (!email || !password) {
        return res.status(400).json({ error: 'Email and password required' });
    }
    try {
        const users = await runQuery('SELECT * FROM users WHERE email = ? AND password = ?', [email, password]);
        if (users.length === 0) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }
        const user = users[0];
        req.session.userId = user.id;
        req.session.userEmail = user.email;
        req.session.displayName = user.display_name;
        return res.json({
            success: true,
            user: {
                id: user.id,
                displayName: user.display_name,
                email: user.email
            }
        });
    }
    catch (error) {
        console.error('Login error:', error);
        return res.status(500).json({ error: 'Server error' });
    }
});
// Register endpoint (only if fewer than 2 users exist and user is logged in)
router.post('/register', async (req, res) => {
    const { firstName, lastName, email, password } = req.body;
    if (!firstName || !lastName || !email || !password) {
        return res.status(400).json({ error: 'All fields required' });
    }
    if (!req.session?.userId) {
        return res.status(401).json({ error: 'Must be logged in to create new user' });
    }
    try {
        const userCount = await runQuery('SELECT COUNT(*) as count FROM users');
        if (userCount[0].count >= 2) {
            return res.status(403).json({ error: 'Maximum users (2) already registered' });
        }
        const result = await runUpdate(`INSERT INTO users (first_name, last_name, display_name, email, password)
       VALUES (?, ?, ?, ?, ?)`, [firstName, lastName, firstName, email, password]);
        // Seed a default personal wish list for the new user.
        await runUpdate('INSERT INTO wish_lists (user_id, name) VALUES (?, ?)', [result.id, 'My Wish List']);
        return res.json({
            success: true,
            message: 'User created successfully',
            userId: result.id
        });
    }
    catch (error) {
        if (error instanceof Error && error.message.includes('UNIQUE constraint failed')) {
            return res.status(400).json({ error: 'Email already exists' });
        }
        console.error('Register error:', error);
        return res.status(500).json({ error: 'Server error' });
    }
});
// Get current user
router.get('/me', async (req, res) => {
    if (!req.session?.userId) {
        return res.status(401).json({ error: 'Not authenticated' });
    }
    try {
        // Get the first/default wish list name
        const lists = await runQuery('SELECT name FROM wish_lists WHERE user_id = ? ORDER BY created_at ASC LIMIT 1', [req.session.userId]);
        return res.json({
            userId: req.session.userId,
            email: req.session.userEmail,
            displayName: req.session.displayName,
            wishListName: lists[0]?.name || 'My Wish List'
        });
    }
    catch {
        return res.json({
            userId: req.session.userId,
            email: req.session.userEmail,
            displayName: req.session.displayName,
            wishListName: 'My Wish List'
        });
    }
});
// Logout
router.post('/logout', (req, res) => {
    if (req.session) {
        req.session.destroy((err) => {
            if (err) {
                return res.status(500).json({ error: 'Logout failed' });
            }
            return res.json({ success: true, message: 'Logged out' });
        });
    }
    else {
        return res.json({ success: true, message: 'Not logged in' });
    }
});
// Check user count
router.get('/user-count', async (req, res) => {
    try {
        const result = await runQuery('SELECT COUNT(*) as count FROM users');
        return res.json({ count: result[0].count });
    }
    catch (error) {
        console.error('User count error:', error);
        return res.status(500).json({ error: 'Server error' });
    }
});
export default router;
