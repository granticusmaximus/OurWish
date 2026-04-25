import { useEffect, useState } from 'react';
import { Table, Button, Form, Alert, Collapse, Card } from 'react-bootstrap';

interface WishListItem {
  id: number;
  product_name: string;
  price: number;
  quantity: number;
  url?: string;
}

interface WishListTableProps {
  items: WishListItem[];
  purchasedItems: WishListItem[];
  onEdit: (id: number, item: Partial<WishListItem>) => Promise<void>;
  onMarkPurchased: (id: number, isPurchased: boolean) => Promise<void>;
  onDelete: (id: number) => Promise<void>;
  isCollaborative?: boolean;
  wishListName?: string;
  onUpdateName?: (name: string) => Promise<void>;
}

const TAX_RATE = 0.0875;

function PencilIcon() {
  return (
    <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 16 16" aria-hidden="true">
      <path d="M12.854.146a.5.5 0 0 1 .707 0l2.586 2.586a.5.5 0 0 1 0 .707l-10 10L3 14l.56-3.147z" />
      <path fillRule="evenodd" d="M1 13.5V16h2.5l8.086-8.086-2.5-2.5zM12.793 4.5 11.5 3.207 13.293 1.414 14.586 2.707z" />
    </svg>
  );
}

function TrashIcon() {
  return (
    <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 16 16" aria-hidden="true">
      <path d="M5.5 5.5A.5.5 0 0 1 6 6v6a.5.5 0 0 1-1 0V6a.5.5 0 0 1 .5-.5m2.5 0A.5.5 0 0 1 8.5 6v6a.5.5 0 0 1-1 0V6a.5.5 0 0 1 .5-.5m3 .5a.5.5 0 0 0-1 0v6a.5.5 0 0 0 1 0z" />
      <path d="M14.5 3a1 1 0 0 1-1 1H13v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V4h-.5a1 1 0 0 1 0-2H5V1a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v1h2.5a1 1 0 0 1 1 1M6 1v1h4V1z" />
    </svg>
  );
}

function EyeSlashIcon() {
  return (
    <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 16 16" aria-hidden="true">
      <path d="M13.359 11.238C14.611 10.234 15.42 8.915 16 8c-.728-1.148-1.68-2.517-3.043-3.76l-.708.708A12.6 12.6 0 0 1 14.82 8a12.3 12.3 0 0 1-2.186 2.553z" />
      <path d="M11.297 9.824a3 3 0 0 0-4.121-4.12zM9.261 11.86l-.766-.766A3 3 0 0 1 4.906 7.51l-.77-.77a4 4 0 0 0 5.125 5.124" />
      <path d="M2.379 5.207A12.5 12.5 0 0 0 1.18 8c.728 1.148 1.68 2.517 3.043 3.76C5.603 12.912 6.783 13.5 8 13.5c.716 0 1.412-.203 2.066-.564l.739.739C9.933 14.216 8.98 14.5 8 14.5c-1.655 0-3.193-.735-4.448-1.833C2.262 11.538 1.267 10.175.5 8.999l-.22-.337.22-.337C1.267 6.825 2.262 5.462 3.552 4.333q.379-.332.786-.632z" />
      <path fillRule="evenodd" d="M13.646 14.354a.5.5 0 0 1-.707 0l-12-12a.5.5 0 1 1 .707-.708l12 12a.5.5 0 0 1 0 .708" />
    </svg>
  );
}

function EyeIcon() {
  return (
    <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 16 16" aria-hidden="true">
      <path d="M16 8s-3-5.5-8-5.5S0 8 0 8s3 5.5 8 5.5S16 8 16 8M1.173 8a13 13 0 0 1 1.66-2.043C4.12 4.668 5.88 3.5 8 3.5s3.879 1.168 5.168 2.457A13 13 0 0 1 14.828 8c-.058.087-.122.183-.195.288-.335.48-.83 1.12-1.465 1.755C11.879 11.332 10.119 12.5 8 12.5s-3.879-1.168-5.168-2.457A13 13 0 0 1 1.172 8z" />
      <path d="M8 5.5a2.5 2.5 0 1 0 0 5 2.5 2.5 0 0 0 0-5" />
    </svg>
  );
}

export function WishListTable({
  items,
  purchasedItems,
  onEdit,
  onMarkPurchased,
  onDelete,
  isCollaborative,
  wishListName = 'Wish List Items',
  onUpdateName
}: WishListTableProps) {
  const [editingId, setEditingId] = useState<number | null>(null);
  const [editForm, setEditForm] = useState<Partial<WishListItem>>({});
  const [showPurchased, setShowPurchased] = useState(false);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState<number | null>(null);
  const [editingName, setEditingName] = useState(false);
  const [tempName, setTempName] = useState(wishListName);
  const [hiddenItemIds, setHiddenItemIds] = useState<number[]>([]);

  useEffect(() => {
    setHiddenItemIds((currentHiddenIds) =>
      currentHiddenIds.filter((itemId) => items.some((item) => item.id === itemId))
    );
  }, [items]);

  const visibleItems = items.filter((item) => !hiddenItemIds.includes(item.id));
  const hiddenItems = items.filter((item) => hiddenItemIds.includes(item.id));
  const subtotal = visibleItems.reduce((sum, item) => sum + (item.price * item.quantity), 0);
  const tax = subtotal * TAX_RATE;
  const total = subtotal + tax;

  const handleEditStart = (item: WishListItem) => {
    setEditingId(item.id);
    setEditForm(item);
    setError('');
  };

  const handleEditSave = async (id: number) => {
    try {
      setLoading(id);
      await onEdit(id, editForm);
      setEditingId(null);
    } catch (err: any) {
      setError(err.message || 'Failed to update item');
    } finally {
      setLoading(null);
    }
  };

  const handleMarkPurchased = async (id: number, isPurchased: boolean) => {
    try {
      setLoading(id);
      await onMarkPurchased(id, isPurchased);
    } catch (err: any) {
      setError(err.message || 'Failed to update purchased status');
    } finally {
      setLoading(null);
    }
  };

  const handleDelete = async (id: number) => {
    if (window.confirm('Are you sure you want to delete this item?')) {
      try {
        setLoading(id);
        await onDelete(id);
      } catch (err: any) {
        setError(err.message || 'Failed to delete item');
      } finally {
        setLoading(null);
      }
    }
  };

  const handleNameEdit = () => {
    setTempName(wishListName);
    setEditingName(true);
  };

  const handleNameSave = async () => {
    if (onUpdateName && tempName.trim()) {
      try {
        await onUpdateName(tempName.trim());
        setEditingName(false);
      } catch (err: any) {
        setError(err.message || 'Failed to update name');
      }
    }
  };

  const handleNameCancel = () => {
    setTempName(wishListName);
    setEditingName(false);
  };

  const toggleItemVisibility = (id: number) => {
    setHiddenItemIds((currentHiddenIds) =>
      currentHiddenIds.includes(id)
        ? currentHiddenIds.filter((itemId) => itemId !== id)
        : [...currentHiddenIds, id]
    );
  };

  return (
    <Card className="shadow-sm">
      <Card.Body>
        {error && <Alert variant="danger" onClose={() => setError('')} dismissible>{error}</Alert>}

        <div className="mb-3 d-flex align-items-center gap-2">
          {editingName && !isCollaborative && onUpdateName ? (
            <>
              <Form.Control
                type="text"
                value={tempName}
                onChange={(e) => setTempName(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter') handleNameSave();
                  if (e.key === 'Escape') handleNameCancel();
                }}
                autoFocus
                style={{ maxWidth: '300px' }}
              />
              <Button variant="success" size="sm" onClick={handleNameSave}>
                ✓
              </Button>
              <Button variant="secondary" size="sm" onClick={handleNameCancel}>
                ✕
              </Button>
            </>
          ) : (
            <>
              <h5 className="mb-0">{wishListName} ({visibleItems.length} shown)</h5>
              {!isCollaborative && onUpdateName && (
                <Button variant="link" size="sm" onClick={handleNameEdit} className="text-decoration-none p-0">
                  ✏️ Edit
                </Button>
              )}
            </>
          )}
        </div>

        {items.length === 0 ? (
          <Alert variant="info">No items in your wish list yet</Alert>
        ) : (
          <>
            <div className="table-responsive">
              <Table striped bordered hover>
                <thead className="table-dark">
                  <tr>
                    <th style={{ width: '10%' }}>Purchased</th>
                    <th style={{ width: '30%' }}>Product Name</th>
                    <th style={{ width: '10%' }}>Qty</th>
                    <th style={{ width: '15%' }}>Price Each</th>
                    <th style={{ width: '15%' }}>Line Total</th>
                    {!isCollaborative && <th style={{ width: '10%' }}>URL</th>}
                    <th style={{ width: isCollaborative ? '20%' : '10%' }}>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {visibleItems.map((item) =>
                    editingId === item.id ? (
                      <tr key={item.id}>
                        <td className="text-center align-middle">
                          <Form.Check
                            type="checkbox"
                            checked={false}
                            onChange={(e) => handleMarkPurchased(item.id, e.target.checked)}
                            disabled={loading === item.id}
                            aria-label="Toggle purchased status"
                          />
                        </td>
                        <td>
                          <Form.Control
                            type="text"
                            value={editForm.product_name || ''}
                            onChange={(e) => setEditForm({ ...editForm, product_name: e.target.value })}
                          />
                        </td>
                        <td>
                          <Form.Control
                            type="number"
                            value={editForm.quantity || 1}
                            onChange={(e) => setEditForm({ ...editForm, quantity: parseInt(e.target.value, 10) || 1 })}
                            min="1"
                            step="1"
                          />
                        </td>
                        <td>
                          <Form.Control
                            type="number"
                            value={editForm.price || 0}
                            onChange={(e) => setEditForm({ ...editForm, price: parseFloat(e.target.value) })}
                            step="0.01"
                          />
                        </td>
                        <td>${(((editForm.price || 0) * (editForm.quantity || 1))).toFixed(2)}</td>
                        {!isCollaborative && (
                          <td>
                            <Form.Control
                              type="text"
                              value={editForm.url || ''}
                              onChange={(e) => setEditForm({ ...editForm, url: e.target.value })}
                              placeholder="URL"
                            />
                          </td>
                        )}
                        <td>
                          <div className="wishlist-action-buttons">
                          <Button
                            variant="success"
                            size="sm"
                            onClick={() => handleEditSave(item.id)}
                            disabled={loading === item.id}
                          >
                            Save
                          </Button>
                          <Button
                            variant="secondary"
                            size="sm"
                            onClick={() => setEditingId(null)}
                            disabled={loading === item.id}
                          >
                            Cancel
                          </Button>
                          <Button
                            variant="dark"
                            size="sm"
                            onClick={() => toggleItemVisibility(item.id)}
                            disabled={loading === item.id}
                            className="wishlist-visibility-button"
                            aria-label="Hide item"
                            title="Hide"
                          >
                            <EyeSlashIcon />
                          </Button>
                          </div>
                        </td>
                      </tr>
                    ) : (
                      <tr key={item.id}>
                        <td className="text-center align-middle">
                          <Form.Check
                            type="checkbox"
                            checked={false}
                            onChange={(e) => handleMarkPurchased(item.id, e.target.checked)}
                            disabled={loading === item.id}
                            aria-label="Toggle purchased status"
                          />
                        </td>
                        <td>{item.product_name}</td>
                        <td>{item.quantity}</td>
                        <td>${item.price.toFixed(2)}</td>
                        <td>${(item.price * item.quantity).toFixed(2)}</td>
                        {!isCollaborative && (
                          <td>
                            {item.url ? (
                              <a href={item.url} target="_blank" rel="noopener noreferrer" className="text-truncate">
                                Link
                              </a>
                            ) : (
                              '-'
                            )}
                          </td>
                        )}
                        <td>
                          <div className="wishlist-action-buttons">
                          <Button
                            variant="info"
                            size="sm"
                            onClick={() => handleEditStart(item)}
                            disabled={loading === item.id}
                            className="wishlist-icon-button"
                            aria-label="Edit item"
                            title="Edit"
                          >
                            <PencilIcon />
                          </Button>
                          <Button
                            variant="danger"
                            size="sm"
                            onClick={() => handleDelete(item.id)}
                            disabled={loading === item.id}
                            className="wishlist-icon-button"
                            aria-label="Delete item"
                            title="Delete"
                          >
                            <TrashIcon />
                          </Button>
                          <Button
                            variant="dark"
                            size="sm"
                            onClick={() => toggleItemVisibility(item.id)}
                            disabled={loading === item.id}
                            className="wishlist-icon-button wishlist-visibility-button"
                            aria-label="Hide item"
                            title="Hide"
                          >
                            <EyeSlashIcon />
                          </Button>
                          </div>
                        </td>
                      </tr>
                    )
                  )}
                </tbody>
                <tfoot>
                  <tr>
                    <th colSpan={4}>Subtotal:</th>
                    <th>${subtotal.toFixed(2)}</th>
                    {!isCollaborative && <th></th>}
                    <th></th>
                  </tr>
                  <tr>
                    <th colSpan={4}>Tax (8.75%):</th>
                    <th>${tax.toFixed(2)}</th>
                    {!isCollaborative && <th></th>}
                    <th></th>
                  </tr>
                  <tr style={{ backgroundColor: '#f8f9fa' }}>
                    <th colSpan={4}>Total:</th>
                    <th style={{ fontSize: '1.1em', fontWeight: 'bold' }}>${total.toFixed(2)}</th>
                    {!isCollaborative && <th></th>}
                    <th></th>
                  </tr>
                </tfoot>
              </Table>
            </div>

            {hiddenItems.length > 0 && (
              <div className="mt-4">
                <h6 className="mb-3">Hidden Items ({hiddenItems.length})</h6>
                <div className="table-responsive">
                  <Table striped bordered hover size="sm">
                    <thead className="table-light">
                      <tr>
                        <th style={{ width: '10%' }}>Purchased</th>
                        <th style={{ width: '30%' }}>Product Name</th>
                        <th style={{ width: '10%' }}>Qty</th>
                        <th style={{ width: '15%' }}>Price Each</th>
                        <th style={{ width: '15%' }}>Line Total</th>
                        {!isCollaborative && <th style={{ width: '10%' }}>URL</th>}
                        <th style={{ width: isCollaborative ? '20%' : '10%' }}>Actions</th>
                      </tr>
                    </thead>
                    <tbody>
                      {hiddenItems.map((item) => (
                        <tr key={item.id}>
                          <td className="text-center align-middle">
                            <Form.Check
                              type="checkbox"
                              checked={false}
                              onChange={(e) => handleMarkPurchased(item.id, e.target.checked)}
                              disabled={loading === item.id}
                              aria-label="Toggle purchased status"
                            />
                          </td>
                          <td>{item.product_name}</td>
                          <td>{item.quantity}</td>
                          <td>${item.price.toFixed(2)}</td>
                          <td>${(item.price * item.quantity).toFixed(2)}</td>
                          {!isCollaborative && (
                            <td>
                              {item.url ? (
                                <a href={item.url} target="_blank" rel="noopener noreferrer" className="text-truncate">
                                  Link
                                </a>
                              ) : (
                                '-'
                              )}
                            </td>
                          )}
                          <td>
                            <Button
                              variant="dark"
                              size="sm"
                              onClick={() => toggleItemVisibility(item.id)}
                              className="wishlist-icon-button wishlist-visibility-button"
                              aria-label="Show item"
                              title="Show"
                            >
                              <EyeIcon />
                            </Button>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </Table>
                </div>
              </div>
            )}
          </>
        )}

        {purchasedItems.length > 0 && (
          <div className="mt-5">
            <Button
              variant="outline-success"
              onClick={() => setShowPurchased(!showPurchased)}
              className="mb-3"
            >
              {showPurchased ? '▼' : '▶'} Purchased Items ({purchasedItems.length})
            </Button>

            <Collapse in={showPurchased}>
              <div>
                <div className="list-group" style={{ maxHeight: '300px', overflowY: 'auto' }}>
                  {purchasedItems.map((item) => (
                    <div key={item.id} className="list-group-item d-flex justify-content-between align-items-center">
                      <div className="d-flex align-items-center gap-3">
                        <Form.Check
                          type="checkbox"
                          checked={true}
                          onChange={(e) => handleMarkPurchased(item.id, e.target.checked)}
                          disabled={loading === item.id}
                          aria-label="Toggle purchased status"
                        />
                        <span>
                          <strong>{item.product_name}</strong> - {item.quantity} x ${item.price.toFixed(2)} = ${(item.price * item.quantity).toFixed(2)}
                        </span>
                      </div>
                      <Button
                        variant="danger"
                        size="sm"
                        onClick={() => handleDelete(item.id)}
                        disabled={loading === item.id}
                      >
                        Remove
                      </Button>
                    </div>
                  ))}
                </div>
              </div>
            </Collapse>
          </div>
        )}
      </Card.Body>
    </Card>
  );
}
