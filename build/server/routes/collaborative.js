import { Router } from 'express';
import { runQuery, runUpdate } from '../database.js';
import axios from 'axios';
import { JSDOM } from 'jsdom';
const router = Router();
// Middleware to check authentication
function requireAuth(req, res, next) {
    if (!req.session?.userId) {
        return res.status(401).json({ error: 'Not authenticated' });
    }
    req.userId = req.session.userId;
    next();
}
// Scrape product info from URL
async function scrapeProductInfo(url) {
    try {
        const response = await axios.get(url, {
            timeout: 5000,
            headers: { 'User-Agent': 'Mozilla/5.0' }
        });
        const dom = new JSDOM(response.data);
        const doc = dom.window.document;
        let name = '';
        let price = 0;
        const nameSelectors = ['h1', '[class*="product-title"]', '[class*="product-name"]', 'title'];
        for (const selector of nameSelectors) {
            const el = doc.querySelector(selector);
            if (el?.textContent) {
                name = el.textContent.trim().substring(0, 100);
                break;
            }
        }
        const priceSelectors = ['[class*="price"]', '[class*="cost"]', '[aria-label*="price"]'];
        for (const selector of priceSelectors) {
            const el = doc.querySelector(selector);
            if (el?.textContent) {
                const priceMatch = el.textContent.match(/\d+\.?\d*/);
                if (priceMatch) {
                    price = parseFloat(priceMatch[0]);
                    break;
                }
            }
        }
        return name && price ? { name, price } : null;
    }
    catch (error) {
        console.error('Scraping error:', error);
        return null;
    }
}
// Get available partner users (excluding current user)
router.get('/partners', requireAuth, async (req, res) => {
    try {
        const partners = await runQuery(`SELECT id, email, display_name
       FROM users
       WHERE id != ?
       ORDER BY email ASC`, [req.userId]);
        return res.json(partners);
    }
    catch (error) {
        console.error('Fetch partners error:', error);
        return res.status(500).json({ error: 'Server error' });
    }
});
// Create collaborative list
router.post('/create', requireAuth, async (req, res) => {
    const { partnerEmail, listName } = req.body;
    const normalizedPartnerEmail = String(partnerEmail ?? '').trim().toLowerCase();
    const normalizedListName = String(listName ?? '').trim();
    if (!normalizedPartnerEmail || !normalizedListName) {
        return res.status(400).json({ error: 'Partner email and list name required' });
    }
    try {
        // Find partner user
        const partners = await runQuery('SELECT id, email, display_name FROM users WHERE LOWER(email) = LOWER(?) AND id != ?', [normalizedPartnerEmail, req.userId]);
        if (partners.length === 0) {
            return res.status(404).json({ error: 'Partner user not found' });
        }
        const partnerId = partners[0].id;
        // Create collaborative list
        const result = await runUpdate(`INSERT INTO collaborative_lists (name, user1_id, user2_id)
       VALUES (?, ?, ?)`, [normalizedListName, req.userId, partnerId]);
        return res.json({
            success: true,
            listId: result.id,
            name: normalizedListName
        });
    }
    catch (error) {
        console.error('Create list error:', error);
        return res.status(500).json({ error: 'Server error' });
    }
});
// Get all collaborative lists for user
router.get('/lists', requireAuth, async (req, res) => {
    try {
        const lists = await runQuery(`SELECT cl.id, cl.name, cl.user1_id, cl.user2_id, 
              CASE WHEN cl.user1_id = ? THEN u2.display_name ELSE u1.display_name END as partner_name
       FROM collaborative_lists cl
       JOIN users u1 ON cl.user1_id = u1.id
       JOIN users u2 ON cl.user2_id = u2.id
       WHERE cl.user1_id = ? OR cl.user2_id = ?`, [req.userId, req.userId, req.userId]);
        return res.json(lists);
    }
    catch (error) {
        console.error('Fetch lists error:', error);
        return res.status(500).json({ error: 'Server error' });
    }
});
// Get items in collaborative list
router.get('/lists/:listId/items', requireAuth, async (req, res) => {
    const { listId } = req.params;
    try {
        // Verify user has access to this list
        const lists = await runQuery(`SELECT * FROM collaborative_lists 
       WHERE id = ? AND (user1_id = ? OR user2_id = ?)`, [listId, req.userId, req.userId]);
        if (lists.length === 0) {
            return res.status(403).json({ error: 'Access denied' });
        }
        const items = await runQuery(`SELECT * FROM collaborative_items 
       WHERE list_id = ? AND is_purchased = 0
       ORDER BY created_at DESC`, [listId]);
        return res.json(items);
    }
    catch (error) {
        console.error('Fetch items error:', error);
        return res.status(500).json({ error: 'Server error' });
    }
});
// Get purchased items in collaborative list
router.get('/lists/:listId/purchased', requireAuth, async (req, res) => {
    const { listId } = req.params;
    try {
        const lists = await runQuery(`SELECT * FROM collaborative_lists 
       WHERE id = ? AND (user1_id = ? OR user2_id = ?)`, [listId, req.userId, req.userId]);
        if (lists.length === 0) {
            return res.status(403).json({ error: 'Access denied' });
        }
        const items = await runQuery(`SELECT * FROM collaborative_items 
       WHERE list_id = ? AND is_purchased = 1
       ORDER BY created_at DESC`, [listId]);
        return res.json(items);
    }
    catch (error) {
        console.error('Fetch purchased error:', error);
        return res.status(500).json({ error: 'Server error' });
    }
});
// Add item to collaborative list
router.post('/lists/:listId/items', requireAuth, async (req, res) => {
    const { listId } = req.params;
    const { productName, price, url } = req.body;
    if (!productName || price === undefined) {
        return res.status(400).json({ error: 'Product name and price required' });
    }
    try {
        // Verify user has access
        const lists = await runQuery(`SELECT * FROM collaborative_lists 
       WHERE id = ? AND (user1_id = ? OR user2_id = ?)`, [listId, req.userId, req.userId]);
        if (lists.length === 0) {
            return res.status(403).json({ error: 'Access denied' });
        }
        const result = await runUpdate(`INSERT INTO collaborative_items (list_id, product_name, price, url)
       VALUES (?, ?, ?, ?)`, [listId, productName, price, url === undefined ? null : url]);
        return res.json({
            success: true,
            itemId: result.id,
            product_name: productName,
            price: price
        });
    }
    catch (error) {
        console.error('Add item error:', error);
        return res.status(500).json({ error: 'Server error' });
    }
});
// Update collaborative item
router.put('/lists/:listId/items/:itemId', requireAuth, async (req, res) => {
    const { listId, itemId } = req.params;
    const { product_name, price, url } = req.body;
    try {
        // Verify access
        const lists = await runQuery(`SELECT * FROM collaborative_lists 
       WHERE id = ? AND (user1_id = ? OR user2_id = ?)`, [listId, req.userId, req.userId]);
        if (lists.length === 0) {
            return res.status(403).json({ error: 'Access denied' });
        }
        await runUpdate(`UPDATE collaborative_items 
       SET product_name = ?, price = ?, url = ?
       WHERE id = ? AND list_id = ?`, [product_name, price, url === undefined ? null : url, itemId, listId]);
        return res.json({ success: true, message: 'Item updated' });
    }
    catch (error) {
        console.error('Update item error:', error);
        return res.status(500).json({ error: 'Server error' });
    }
});
// Mark collaborative item as purchased
router.put('/lists/:listId/items/:itemId/purchase', requireAuth, async (req, res) => {
    const { listId, itemId } = req.params;
    try {
        const lists = await runQuery(`SELECT * FROM collaborative_lists 
       WHERE id = ? AND (user1_id = ? OR user2_id = ?)`, [listId, req.userId, req.userId]);
        if (lists.length === 0) {
            return res.status(403).json({ error: 'Access denied' });
        }
        await runUpdate(`UPDATE collaborative_items 
       SET is_purchased = 1
       WHERE id = ? AND list_id = ?`, [itemId, listId]);
        return res.json({ success: true, message: 'Item marked as purchased' });
    }
    catch (error) {
        console.error('Purchase error:', error);
        return res.status(500).json({ error: 'Server error' });
    }
});
// Delete collaborative item
router.delete('/lists/:listId/items/:itemId', requireAuth, async (req, res) => {
    const { listId, itemId } = req.params;
    try {
        const lists = await runQuery(`SELECT * FROM collaborative_lists 
       WHERE id = ? AND (user1_id = ? OR user2_id = ?)`, [listId, req.userId, req.userId]);
        if (lists.length === 0) {
            return res.status(403).json({ error: 'Access denied' });
        }
        await runUpdate(`DELETE FROM collaborative_items 
       WHERE id = ? AND list_id = ?`, [itemId, listId]);
        return res.json({ success: true, message: 'Item deleted' });
    }
    catch (error) {
        console.error('Delete error:', error);
        return res.status(500).json({ error: 'Server error' });
    }
});
// Delete collaborative list
router.delete('/lists/:listId', requireAuth, async (req, res) => {
    const { listId } = req.params;
    try {
        const lists = await runQuery(`SELECT * FROM collaborative_lists 
       WHERE id = ? AND (user1_id = ? OR user2_id = ?)`, [listId, req.userId, req.userId]);
        if (lists.length === 0) {
            return res.status(403).json({ error: 'Access denied' });
        }
        await runUpdate(`DELETE FROM collaborative_lists WHERE id = ?`, [listId]);
        return res.json({ success: true, message: 'List deleted' });
    }
    catch (error) {
        console.error('Delete list error:', error);
        return res.status(500).json({ error: 'Server error' });
    }
});
export default router;
