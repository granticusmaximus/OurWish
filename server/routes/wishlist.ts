import { Router, Request, Response, NextFunction } from 'express';
import { runQuery, runUpdate } from '../database.js';

const router = Router();

interface AuthRequest extends Request {
  userId?: number;
}

interface WishListRow {
  id: number;
  user_id: number;
  name: string;
  created_at: string;
}

interface WishListItemRow {
  id: number;
  user_id: number;
  list_id: number | null;
  product_name: string;
  price: number;
  quantity: number;
  url: string | null;
  is_purchased: number;
  created_at: string;
}

interface CountRow {
  count: number;
}

// Middleware to check authentication
function requireAuth(req: AuthRequest, res: Response, next: NextFunction) {
  if (!req.session?.userId) {
    return res.status(401).json({ error: 'Not authenticated' });
  }
  req.userId = req.session.userId;
  next();
}

// ===== WISH LIST MANAGEMENT ENDPOINTS =====

// Get all wish lists for current user
router.get('/lists', requireAuth, async (req: AuthRequest, res: Response) => {
  try {
    const lists = await runQuery<WishListRow>(
      `SELECT * FROM wish_lists 
       WHERE user_id = ?
       ORDER BY created_at ASC`,
      [req.userId]
    );

    return res.json(lists);
  } catch (error) {
    console.error('Fetch wish lists error:', error);
    return res.status(500).json({ error: 'Server error' });
  }
});

// Create new wish list
router.post('/lists', requireAuth, async (req: AuthRequest, res: Response) => {
  const { name } = req.body;

  if (!name || name.trim() === '') {
    return res.status(400).json({ error: 'Wish list name is required' });
  }

  try {
    const result = await runUpdate(
      'INSERT INTO wish_lists (user_id, name) VALUES (?, ?)',
      [req.userId, name.trim()]
    );

    return res.json({
      success: true,
      listId: result.id,
      name: name.trim()
    });
  } catch (error) {
    console.error('Create wish list error:', error);
    return res.status(500).json({ error: 'Server error' });
  }
});

// Update wish list name
router.put('/lists/:listId/name', requireAuth, async (req: AuthRequest, res: Response) => {
  const { listId } = req.params;
  const { name } = req.body;

  if (!name || name.trim() === '') {
    return res.status(400).json({ error: 'Wish list name is required' });
  }

  try {
    // Verify ownership
    const lists = await runQuery<WishListRow>(
      'SELECT * FROM wish_lists WHERE id = ? AND user_id = ?',
      [listId, req.userId]
    );

    if (lists.length === 0) {
      return res.status(404).json({ error: 'Wish list not found' });
    }

    await runUpdate(
      'UPDATE wish_lists SET name = ? WHERE id = ? AND user_id = ?',
      [name.trim(), listId, req.userId]
    );

    return res.json({ success: true, name: name.trim() });
  } catch (error) {
    console.error('Update wish list name error:', error);
    return res.status(500).json({ error: 'Server error' });
  }
});

// Delete wish list
router.delete('/lists/:listId', requireAuth, async (req: AuthRequest, res: Response) => {
  const { listId } = req.params;

  try {
    // Verify ownership
    const lists = await runQuery<WishListRow>(
      'SELECT * FROM wish_lists WHERE id = ? AND user_id = ?',
      [listId, req.userId]
    );

    if (lists.length === 0) {
      return res.status(404).json({ error: 'Wish list not found' });
    }

    // Check if user has more than one list
    const allLists = await runQuery<CountRow>(
      'SELECT COUNT(*) as count FROM wish_lists WHERE user_id = ?',
      [req.userId]
    );

    if (allLists[0].count <= 1) {
      return res.status(400).json({ error: 'Cannot delete your only wish list' });
    }

    await runUpdate(
      'DELETE FROM wish_list_items WHERE list_id = ? AND user_id = ?',
      [listId, req.userId]
    );

    await runUpdate(
      'DELETE FROM wish_lists WHERE id = ? AND user_id = ?',
      [listId, req.userId]
    );

    return res.json({ success: true });
  } catch (error) {
    console.error('Delete wish list error:', error);
    return res.status(500).json({ error: 'Server error' });
  }
});

// ===== WISH LIST ITEMS ENDPOINTS =====

// Get items for a specific wish list
router.get('/lists/:listId/items', requireAuth, async (req: AuthRequest, res: Response) => {
  const { listId } = req.params;

  try {
    // Verify ownership
    const lists = await runQuery<WishListRow>(
      'SELECT * FROM wish_lists WHERE id = ? AND user_id = ?',
      [listId, req.userId]
    );

    if (lists.length === 0) {
      return res.status(404).json({ error: 'Wish list not found' });
    }

    const items = await runQuery<WishListItemRow>(
      `SELECT * FROM wish_list_items 
       WHERE list_id = ? AND is_purchased = 0
       ORDER BY created_at DESC`,
      [listId]
    );

    return res.json(items);
  } catch (error) {
    console.error('Fetch items error:', error);
    return res.status(500).json({ error: 'Server error' });
  }
});

// Get purchased items for a specific wish list
router.get('/lists/:listId/purchased', requireAuth, async (req: AuthRequest, res: Response) => {
  const { listId } = req.params;

  try {
    // Verify ownership
    const lists = await runQuery<WishListRow>(
      'SELECT * FROM wish_lists WHERE id = ? AND user_id = ?',
      [listId, req.userId]
    );

    if (lists.length === 0) {
      return res.status(404).json({ error: 'Wish list not found' });
    }

    const items = await runQuery<WishListItemRow>(
      `SELECT * FROM wish_list_items 
       WHERE list_id = ? AND is_purchased = 1
       ORDER BY created_at DESC`,
      [listId]
    );

    return res.json(items);
  } catch (error) {
    console.error('Fetch purchased error:', error);
    return res.status(500).json({ error: 'Server error' });
  }
});

// Add item to a specific wish list
router.post('/lists/:listId/items', requireAuth, async (req: AuthRequest, res: Response) => {
  const { listId } = req.params;
  const { productName, price, quantity, url } = req.body;
  const normalizedQuantity = Number(quantity ?? 1);

  if (!productName || price === undefined || !Number.isInteger(normalizedQuantity) || normalizedQuantity < 1) {
    return res.status(400).json({ error: 'Product name, price, and quantity of at least 1 are required' });
  }

  try {
    // Verify ownership
    const lists = await runQuery<WishListRow>(
      'SELECT * FROM wish_lists WHERE id = ? AND user_id = ?',
      [listId, req.userId]
    );

    if (lists.length === 0) {
      return res.status(404).json({ error: 'Wish list not found' });
    }

    const result = await runUpdate(
      `INSERT INTO wish_list_items (user_id, list_id, product_name, price, quantity, url)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [req.userId, listId, productName, price, normalizedQuantity, url === undefined ? null : url]
    );

    return res.json({
      success: true,
      itemId: result.id,
      product_name: productName,
      price: price,
      quantity: normalizedQuantity,
      url: url === undefined ? null : url
    });
  } catch (error) {
    console.error('Add item error:', error);
    return res.status(500).json({ error: 'Server error' });
  }
});

// ===== LEGACY ENDPOINTS (for backward compatibility) =====

// ===== LEGACY ENDPOINTS (for backward compatibility) =====

// Get personal wish list items
router.get('/items', requireAuth, async (req: AuthRequest, res: Response) => {
  try {
    const items = await runQuery<WishListItemRow>(
      `SELECT * FROM wish_list_items 
       WHERE user_id = ? AND is_purchased = 0
       ORDER BY created_at DESC`,
      [req.userId]
    );

    return res.json(items);
  } catch (error) {
    console.error('Fetch items error:', error);
    return res.status(500).json({ error: 'Server error' });
  }
});

// Get purchased items
router.get('/purchased', requireAuth, async (req: AuthRequest, res: Response) => {
  try {
    const items = await runQuery<WishListItemRow>(
      `SELECT * FROM wish_list_items 
       WHERE user_id = ? AND is_purchased = 1
       ORDER BY created_at DESC`,
      [req.userId]
    );

    return res.json(items);
  } catch (error) {
    console.error('Fetch purchased error:', error);
    return res.status(500).json({ error: 'Server error' });
  }
});

// Add item to wish list (legacy - auto-selects first list or uses provided listId)
router.post('/items', requireAuth, async (req: AuthRequest, res: Response) => {
  const { productName, price, quantity, url, listId } = req.body;
  const normalizedQuantity = Number(quantity ?? 1);

  if (!productName || price === undefined || !Number.isInteger(normalizedQuantity) || normalizedQuantity < 1) {
    return res.status(400).json({ error: 'Product name, price, and quantity of at least 1 are required' });
  }

  try {
    // If listId not provided, use first list
    let targetListId = listId;
    if (!targetListId) {
      const lists = await runQuery<WishListRow>(
        'SELECT id FROM wish_lists WHERE user_id = ? ORDER BY created_at ASC LIMIT 1',
        [req.userId]
      );
      
      if (lists.length === 0) {
        return res.status(404).json({ error: 'No wish list found' });
      }
      targetListId = lists[0].id;
    } else {
      // Verify ownership
      const lists = await runQuery<WishListRow>(
        'SELECT * FROM wish_lists WHERE id = ? AND user_id = ?',
        [targetListId, req.userId]
      );

      if (lists.length === 0) {
        return res.status(404).json({ error: 'Wish list not found' });
      }
    }

    const result = await runUpdate(
      `INSERT INTO wish_list_items (user_id, list_id, product_name, price, quantity, url)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [req.userId, targetListId, productName, price, normalizedQuantity, url === undefined ? null : url]
    );

    return res.json({
      success: true,
      itemId: result.id,
      product_name: productName,
      price: price,
      quantity: normalizedQuantity,
      url: url === undefined ? null : url
    });
  } catch (error) {
    console.error('Add item error:', error);
    return res.status(500).json({ error: 'Server error' });
  }
});

// Update item
router.put('/items/:id', requireAuth, async (req: AuthRequest, res: Response) => {
  const { id } = req.params;
  const { product_name, price, quantity, url } = req.body;
  const normalizedQuantity = Number(quantity ?? 1);

  if (!Number.isInteger(normalizedQuantity) || normalizedQuantity < 1) {
    return res.status(400).json({ error: 'Quantity must be at least 1' });
  }

  try {
    // Verify ownership
    const items = await runQuery<WishListItemRow>(
      'SELECT * FROM wish_list_items WHERE id = ? AND user_id = ?',
      [id, req.userId]
    );

    if (items.length === 0) {
      return res.status(404).json({ error: 'Item not found' });
    }

    await runUpdate(
      `UPDATE wish_list_items 
       SET product_name = ?, price = ?, quantity = ?, url = ?
       WHERE id = ? AND user_id = ?`,
      [product_name, price, normalizedQuantity, url === undefined ? null : url, id, req.userId]
    );

    return res.json({ success: true, message: 'Item updated' });
  } catch (error) {
    console.error('Update item error:', error);
    return res.status(500).json({ error: 'Server error' });
  }
});

// Mark item as purchased
router.put('/items/:id/purchase', requireAuth, async (req: AuthRequest, res: Response) => {
  const { id } = req.params;

  try {
    await runUpdate(
      `UPDATE wish_list_items 
       SET is_purchased = 1
       WHERE id = ? AND user_id = ?`,
      [id, req.userId]
    );

    return res.json({ success: true, message: 'Item marked as purchased' });
  } catch (error) {
    console.error('Purchase error:', error);
    return res.status(500).json({ error: 'Server error' });
  }
});

// Delete item
router.delete('/items/:id', requireAuth, async (req: AuthRequest, res: Response) => {
  const { id } = req.params;

  try {
    await runUpdate(
      'DELETE FROM wish_list_items WHERE id = ? AND user_id = ?',
      [id, req.userId]
    );

    return res.json({ success: true, message: 'Item deleted' });
  } catch (error) {
    console.error('Delete error:', error);
    return res.status(500).json({ error: 'Server error' });
  }
});

// Update wish list name
router.put('/name', requireAuth, async (req: AuthRequest, res: Response) => {
  const { name } = req.body;

  if (!name || name.trim() === '') {
    return res.status(400).json({ error: 'Wish list name is required' });
  }

  try {
    // Update the first/default wish list name for backward compatibility
    const lists = await runQuery<WishListRow>(
      'SELECT id FROM wish_lists WHERE user_id = ? ORDER BY created_at ASC LIMIT 1',
      [req.userId]
    );

    if (lists.length === 0) {
      return res.status(404).json({ error: 'No wish list found' });
    }

    await runUpdate(
      'UPDATE wish_lists SET name = ? WHERE id = ? AND user_id = ?',
      [name.trim(), lists[0].id, req.userId]
    );

    return res.json({ success: true, name: name.trim() });
  } catch (error) {
    console.error('Update name error:', error);
    return res.status(500).json({ error: 'Server error' });
  }
});

export default router;
