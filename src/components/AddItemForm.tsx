import React, { useState } from 'react';
import { Form, Button, Alert, Modal } from 'react-bootstrap';

interface WishList {
  id: number;
  user_id: number;
  name: string;
  created_at: string;
}

interface AddItemFormProps {
  onSubmit: (product: { productName: string; price: number; quantity: number; url?: string; listId?: number }) => Promise<void>;
  loading?: boolean;
  wishlists?: WishList[];
}

export function AddItemForm({ onSubmit, loading = false, wishlists = [] }: AddItemFormProps) {
  const [showModal, setShowModal] = useState(false);
  const [productName, setProductName] = useState('');
  const [price, setPrice] = useState('');
  const [quantity, setQuantity] = useState('1');
  const [url, setUrl] = useState('');
  const [selectedListId, setSelectedListId] = useState<number | undefined>();
  const [error, setError] = useState('');

  const handleClose = () => {
    setShowModal(false);
    setError('');
  };

  const handleShow = () => {
    // Set default list ID when opening modal
    if (wishlists.length > 0 && !selectedListId) {
      setSelectedListId(wishlists[0].id);
    }
    setShowModal(true);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');

    if (!productName || !price || !quantity) {
      setError('Product name, price, and quantity are required');
      return;
    }

    const parsedQuantity = Number.parseInt(quantity, 10);
    if (!Number.isInteger(parsedQuantity) || parsedQuantity < 1) {
      setError('Quantity must be a whole number of at least 1');
      return;
    }

    try {
      await onSubmit({
        productName: productName,
        price: parseFloat(price),
        quantity: parsedQuantity,
        url: url || undefined,
        listId: wishlists.length > 1 ? selectedListId : undefined
      });

      // Reset form and close modal
      setProductName('');
      setPrice('');
      setQuantity('1');
      setUrl('');
      setSelectedListId(undefined);
      setShowModal(false);
    } catch (err: any) {
      setError(err.message || 'Failed to add item');
    }
  };

  return (
    <>
      <Button variant="primary" onClick={handleShow} className="mb-4">
        + Add New Item
      </Button>

      <Modal show={showModal} onHide={handleClose} centered>
        <Modal.Header closeButton>
          <Modal.Title>Add Item to Wish List</Modal.Title>
        </Modal.Header>
        <Modal.Body>
          {error && <Alert variant="danger" onClose={() => setError('')} dismissible>{error}</Alert>}

          <Form onSubmit={handleSubmit}>
          {wishlists.length > 1 && (
            <Form.Group className="mb-3">
              <Form.Label>Add to Wish List</Form.Label>
              <Form.Select
                value={selectedListId || ''}
                onChange={(e) => setSelectedListId(Number(e.target.value))}
                required
              >
                <option value="">Select a wish list...</option>
                {wishlists.map(list => (
                  <option key={list.id} value={list.id}>
                    {list.name}
                  </option>
                ))}
              </Form.Select>
            </Form.Group>
          )}

          <Form.Group className="mb-3">
            <Form.Label>Product Name</Form.Label>
            <Form.Control
              type="text"
              value={productName}
              onChange={(e) => setProductName(e.target.value)}
              placeholder="Enter product name"
              required
            />
          </Form.Group>

          <Form.Group className="mb-3">
            <Form.Label>Price Each ($)</Form.Label>
            <Form.Control
              type="number"
              value={price}
              onChange={(e) => setPrice(e.target.value)}
              placeholder="Enter price"
              step="0.01"
              required
            />
          </Form.Group>

          <Form.Group className="mb-3">
            <Form.Label>Quantity</Form.Label>
            <Form.Control
              type="number"
              value={quantity}
              onChange={(e) => setQuantity(e.target.value)}
              placeholder="Enter quantity"
              min="1"
              step="1"
              required
            />
          </Form.Group>

          <Form.Group className="mb-3">
            <Form.Label>Product URL (Optional)</Form.Label>
            <Form.Control
              type="url"
              value={url}
              onChange={(e) => setUrl(e.target.value)}
              placeholder="Paste product URL"
            />
            <Form.Text className="text-muted">
              Add a link to view the product online
            </Form.Text>
          </Form.Group>

          <div className="d-flex gap-2 justify-content-end">
            <Button variant="secondary" onClick={handleClose}>
              Cancel
            </Button>
            <Button variant="primary" type="submit" disabled={loading || !productName || !price || !quantity}>
              {loading ? 'Adding...' : 'Add to Wish List'}
            </Button>
          </div>
        </Form>
        </Modal.Body>
      </Modal>
    </>
  );
}
