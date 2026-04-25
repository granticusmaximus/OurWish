import { useState, useEffect, useRef } from 'react';
import { Container, Row, Col, Navbar, Spinner, Alert, Dropdown, ButtonGroup, Button, Modal, Form } from 'react-bootstrap';
import 'bootstrap/dist/css/bootstrap.min.css';
import './App.css';
import { useAuth } from './contexts/AuthContext';
import { Login } from './components/Login';
import { Register } from './components/Register';
import { AddItemForm } from './components/AddItemForm';
import { WishListTable } from './components/WishListTable';
import { CollaborativeLists } from './components/CollaborativeLists';
import ourWishLogo from './assets/ourwish-logo.svg';

type View = 'login' | 'register' | 'wishlists' | 'collaborative';

interface WishList {
  id: number;
  user_id: number;
  name: string;
  created_at: string;
}

function App() {
  const [view, setView] = useState<View>('login');
  const [wishlists, setWishlists] = useState<WishList[]>([]);
  const [selectedWishListId, setSelectedWishListId] = useState<number>();
  const [items, setItems] = useState<any[]>([]);
  const [purchasedItems, setPurchasedItems] = useState<any[]>([]);
  const [collaborativeItems, setCollaborativeItems] = useState<any[]>([]);
  const [purchasedCollaborativeItems, setPurchasedCollaborativeItems] = useState<any[]>([]);
  const [selectedCollaborativeListId, setSelectedCollaborativeListId] = useState<number>();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [showCreateListModal, setShowCreateListModal] = useState(false);
  const [showDeleteListModal, setShowDeleteListModal] = useState(false);
  const [newListName, setNewListName] = useState('');
  const [listToDeleteId, setListToDeleteId] = useState<number>();
  const [listActionLoading, setListActionLoading] = useState(false);
  const [listModalError, setListModalError] = useState('');
  const { user, loading: authLoading, logout } = useAuth();
  const selectedWishListIdRef = useRef<number | undefined>(undefined);

  useEffect(() => {
    if (!authLoading) {
      if (user) {
        setView((currentView) => (currentView === 'collaborative' ? currentView : 'wishlists'));
        fetchWishLists();
      } else {
        setView('login');
      }
    }
  }, [user, authLoading]);

  useEffect(() => {
    selectedWishListIdRef.current = selectedWishListId;
  }, [selectedWishListId]);

  useEffect(() => {
    if (selectedWishListId) {
      fetchWishListItems(selectedWishListId);
    } else {
      setItems([]);
      setPurchasedItems([]);
    }
  }, [selectedWishListId]);

  useEffect(() => {
    if (selectedCollaborativeListId) {
      fetchCollaborativeItems(selectedCollaborativeListId);
    } else {
      setCollaborativeItems([]);
      setPurchasedCollaborativeItems([]);
    }
  }, [selectedCollaborativeListId]);

  const fetchWishLists = async () => {
    try {
      const response = await fetch('/api/wishlist/lists', {
        credentials: 'include'
      });

      if (response.ok) {
        const data = await response.json();
        const normalizedLists: WishList[] = data.map((list: WishList) => ({
          ...list,
          id: Number(list.id),
          user_id: Number(list.user_id)
        }));
        if (data.length === 0) {
          // Ensure newly created users always have at least one personal list.
          const createResponse = await fetch('/api/wishlist/lists', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ name: 'My Wish List' }),
            credentials: 'include'
          });

          if (createResponse.ok) {
            const created = await createResponse.json();
            const defaultList = {
              id: Number(created.listId),
              user_id: user?.userId ?? 0,
              name: created.name ?? 'My Wish List',
              created_at: new Date().toISOString()
            };
            setWishlists([defaultList]);
            setSelectedWishListId(defaultList.id);
            return;
          }
        }

        setWishlists(normalizedLists);
        
        // Select first list by default
        if (normalizedLists.length > 0 && !selectedWishListId) {
          setSelectedWishListId(normalizedLists[0].id);
        }
      }
    } catch (err: any) {
      setError('Failed to load wish lists');
    }
  };

  const createWishList = async (name: string) => {
    try {
      setListModalError('');
      setListActionLoading(true);
      const response = await fetch('/api/wishlist/lists', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name }),
        credentials: 'include'
      });

      if (!response.ok) throw new Error('Failed to create wish list');

      const created = await response.json();
      await fetchWishLists();
      if (created.listId) {
        setSelectedWishListId(Number(created.listId));
      }
      setShowCreateListModal(false);
      setNewListName('');
    } catch (err: any) {
      const message = err.message || 'Failed to create wish list';
      setListModalError(message);
      setError(message);
    } finally {
      setListActionLoading(false);
    }
  };

  const deleteWishList = async (listId: number) => {
    try {
      setListModalError('');
      setListActionLoading(true);
      const response = await fetch(`/api/wishlist/lists/${listId}`, {
        method: 'DELETE',
        credentials: 'include'
      });

      if (!response.ok) {
        const error = await response.json();
        throw new Error(error.error || 'Failed to delete wish list');
      }

      // Select another list if the deleted one was selected
      if (selectedWishListId === listId) {
        const remainingLists = wishlists.filter(l => l.id !== listId);
        if (remainingLists.length > 0) {
          setSelectedWishListId(remainingLists[0].id);
        }
      }

      await fetchWishLists();
      setShowDeleteListModal(false);
      setListToDeleteId(undefined);
    } catch (err: any) {
      const message = err.message || 'Failed to delete wish list';
      setListModalError(message);
      setError(message);
    } finally {
      setListActionLoading(false);
    }
  };

  const openCreateListModal = () => {
    setError('');
    setListModalError('');
    setNewListName('');
    setShowCreateListModal(true);
  };

  const closeCreateListModal = () => {
    if (listActionLoading) return;
    setShowCreateListModal(false);
    setNewListName('');
    setListModalError('');
  };

  const openDeleteListModal = () => {
    setError('');
    setListModalError('');
    setListToDeleteId(selectedWishListId ?? wishlists[0]?.id);
    setShowDeleteListModal(true);
  };

  const closeDeleteListModal = () => {
    if (listActionLoading) return;
    setShowDeleteListModal(false);
    setListToDeleteId(undefined);
    setListModalError('');
  };

  const updateWishListNameById = async (listId: number, name: string) => {
    try {
      const response = await fetch(`/api/wishlist/lists/${listId}/name`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name }),
        credentials: 'include'
      });

      if (!response.ok) {
        const error = await response.json();
        throw new Error(error.error || 'Failed to update wish list name');
      }

      await fetchWishLists();
    } catch (err: any) {
      throw err;
    }
  };

  const fetchWishListItems = async (listIdOverride?: number) => {
    const listId = Number(listIdOverride ?? selectedWishListId);
    if (!listId) {
      setItems([]);
      setPurchasedItems([]);
      return;
    }

    try {
      const [response1, response2] = await Promise.all([
        fetch(`/api/wishlist/lists/${listId}/items`, {
          credentials: 'include'
        }),
        fetch(`/api/wishlist/lists/${listId}/purchased`, {
          credentials: 'include'
        })
      ]);

      // Ignore stale responses when user switches lists quickly.
      if (selectedWishListIdRef.current !== listId) {
        return;
      }

      if (response1.ok) {
        const data = await response1.json();
        setItems(data);
      } else {
        setItems([]);
      }

      if (response2.ok) {
        const data = await response2.json();
        setPurchasedItems(data);
      } else {
        setPurchasedItems([]);
      }
    } catch (err: any) {
      if (selectedWishListIdRef.current === listId) {
        setItems([]);
        setPurchasedItems([]);
        setError(err.message || 'Failed to load wish list');
      }
    }
  };

  const fetchCollaborativeItems = async (listId: number) => {
    try {
      const [response1, response2] = await Promise.all([
        fetch(`/api/collaborative/lists/${listId}/items`, {
          credentials: 'include'
        }),
        fetch(`/api/collaborative/lists/${listId}/purchased`, {
          credentials: 'include'
        })
      ]);

      if (response1.ok) {
        const data = await response1.json();
        setCollaborativeItems(data);
      }

      if (response2.ok) {
        const data = await response2.json();
        setPurchasedCollaborativeItems(data);
      }
    } catch (err: any) {
      setError('Failed to load collaborative items');
    }
  };

  const handleAddItem = async (product: { productName: string; price: number; quantity: number; url?: string; listId?: number }) => {
    try {
      setLoading(true);
      const targetListId = product.listId || selectedWishListId;
      
      if (!targetListId) {
        throw new Error('No wish list selected');
      }

      const response = await fetch(`/api/wishlist/lists/${targetListId}/items`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          productName: product.productName,
          price: product.price,
          quantity: product.quantity,
          url: product.url
        }),
        credentials: 'include'
      });

      if (!response.ok) throw new Error('Failed to add item');

      await fetchWishListItems(targetListId);
    } catch (err: any) {
      setError(err.message || 'Failed to add item');
    } finally {
      setLoading(false);
    }
  };

  const handleAddCollaborativeItem = async (product: { productName: string; price: number; quantity: number; url?: string }) => {
    if (!selectedCollaborativeListId) return;

    try {
      setLoading(true);
      const response = await fetch(`/api/collaborative/lists/${selectedCollaborativeListId}/items`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(product),
        credentials: 'include'
      });

      if (!response.ok) throw new Error('Failed to add item');

      await fetchCollaborativeItems(selectedCollaborativeListId);
    } catch (err: any) {
      setError(err.message || 'Failed to add item');
    } finally {
      setLoading(false);
    }
  };

  const handleEditItem = async (id: number, updates: any) => {
    try {
      const response = await fetch(`/api/wishlist/items/${id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(updates),
        credentials: 'include'
      });

      if (!response.ok) throw new Error('Failed to update item');

      await fetchWishListItems(selectedWishListId);
    } catch (err: any) {
      throw err;
    }
  };

  const handleEditCollaborativeItem = async (id: number, updates: any) => {
    if (!selectedCollaborativeListId) return;

    try {
      const response = await fetch(
        `/api/collaborative/lists/${selectedCollaborativeListId}/items/${id}`,
        {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(updates),
          credentials: 'include'
        }
      );

      if (!response.ok) throw new Error('Failed to update item');

      await fetchCollaborativeItems(selectedCollaborativeListId);
    } catch (err: any) {
      throw err;
    }
  };

  const handleMarkPurchased = async (id: number, isPurchased: boolean) => {
    try {
      const response = await fetch(`/api/wishlist/items/${id}/purchase`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ isPurchased }),
        credentials: 'include'
      });

      if (!response.ok) throw new Error('Failed to update purchased status');

      await fetchWishListItems(selectedWishListId);
    } catch (err: any) {
      throw err;
    }
  };

  const handleMarkCollaborativePurchased = async (id: number, isPurchased: boolean) => {
    if (!selectedCollaborativeListId) return;

    try {
      const response = await fetch(
        `/api/collaborative/lists/${selectedCollaborativeListId}/items/${id}/purchase`,
        {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ isPurchased }),
          credentials: 'include'
        }
      );

      if (!response.ok) throw new Error('Failed to update purchased status');

      await fetchCollaborativeItems(selectedCollaborativeListId);
    } catch (err: any) {
      throw err;
    }
  };

  const handleDeleteItem = async (id: number) => {
    try {
      const response = await fetch(`/api/wishlist/items/${id}`, {
        method: 'DELETE',
        credentials: 'include'
      });

      if (!response.ok) throw new Error('Failed to delete item');

      await fetchWishListItems(selectedWishListId);
    } catch (err: any) {
      throw err;
    }
  };

  const handleDeleteCollaborativeItem = async (id: number) => {
    if (!selectedCollaborativeListId) return;

    try {
      const response = await fetch(
        `/api/collaborative/lists/${selectedCollaborativeListId}/items/${id}`,
        {
          method: 'DELETE',
          credentials: 'include'
        }
      );

      if (!response.ok) throw new Error('Failed to delete item');

      await fetchCollaborativeItems(selectedCollaborativeListId);
    } catch (err: any) {
      throw err;
    }
  };

  const handleLogout = async () => {
    await logout();
    setView('login');
  };

  if (authLoading) {
    return (
      <div className="d-flex justify-content-center align-items-center full-height-center">
        <Spinner animation="border" />
      </div>
    );
  }

  if (view === 'login') {
    return <Login />;
  }

  if (view === 'register') {
    return <Register onBackClick={() => setView(user ? 'wishlists' : 'login')} />;
  }

  const isCollaborativeView = view === 'collaborative';

  return (
    <>
      <Navbar bg="dark" data-bs-theme="dark" className="mb-4" sticky="top">
        <Container fluid className="d-flex align-items-center px-3 px-xl-4">
          <div className="flex-fill d-flex justify-content-start">
            <Navbar.Brand className="fw-bold mb-0">
              <img
                src={ourWishLogo}
                alt="OurWish"
                style={{ height: '36px', width: 'auto' }}
              />
            </Navbar.Brand>
          </div>
          <div className="flex-fill d-flex justify-content-center gap-2">
            <Button
              variant="outline-light"
              size="sm"
              onClick={() => setView('register')}
            >
              Create New User
            </Button>
            <Button
              variant="outline-light"
              size="sm"
              onClick={() => setView(isCollaborativeView ? 'wishlists' : 'collaborative')}
            >
              {isCollaborativeView ? 'View Wish Lists' : 'View Collaborative Lists'}
            </Button>
          </div>
          <div className="flex-fill d-flex justify-content-end align-items-center gap-3">
            <div className="text-light">Welcome, {user?.displayName}</div>
            <button className="btn btn-outline-light" onClick={handleLogout}>
              Logout
            </button>
          </div>
        </Container>
      </Navbar>

      <Container fluid className="py-4 px-3 px-xl-4">
        {error && (
          <Alert variant="danger" onClose={() => setError('')} dismissible>
            {error}
          </Alert>
        )}

        {isCollaborativeView ? (
          <Row className="g-4">
            <Col xs={12}>
              <div className="mb-4">
                <div className="d-flex justify-content-between align-items-center mb-3">
                  <h3 className="mb-0">Collaborative Lists</h3>
                  <Button
                    variant="outline-primary"
                    size="sm"
                    onClick={() => setView('wishlists')}
                  >
                    Back to My Wish Lists
                  </Button>
                </div>
                <CollaborativeLists
                  onSelectList={setSelectedCollaborativeListId}
                  selectedListId={selectedCollaborativeListId}
                />
              </div>

              {selectedCollaborativeListId ? (
                <div className="mt-4">
                  <h5 className="mb-3">Collaborative List Items</h5>
                  <AddItemForm
                    onSubmit={handleAddCollaborativeItem}
                    loading={loading}
                  />
                  <WishListTable
                    items={collaborativeItems}
                    purchasedItems={purchasedCollaborativeItems}
                    onEdit={handleEditCollaborativeItem}
                    onMarkPurchased={handleMarkCollaborativePurchased}
                    onDelete={handleDeleteCollaborativeItem}
                    isCollaborative={true}
                  />
                </div>
              ) : (
                <Alert variant="info" className="mb-0">
                  Select a collaborative list to view or add shared items.
                </Alert>
              )}
            </Col>
          </Row>
        ) : (
          <Row className="g-4">
            <Col xs={12}>
              <div className="mb-4">
                <div className="d-flex justify-content-between align-items-center mb-3">
                  <h3 className="mb-0">My Wish Lists</h3>
                  <div className="d-flex gap-2">
                    {wishlists.length > 1 && (
                      <Dropdown as={ButtonGroup}>
                        <Button variant="primary" disabled>
                          {wishlists.find(l => l.id === selectedWishListId)?.name || 'Select List'}
                        </Button>
                        <Dropdown.Toggle split variant="primary" id="wishlist-dropdown" />
                        <Dropdown.Menu>
                          {wishlists.map(list => (
                            <Dropdown.Item
                              key={list.id}
                              active={list.id === selectedWishListId}
                              onClick={() => setSelectedWishListId(Number(list.id))}
                            >
                              {list.name}
                            </Dropdown.Item>
                          ))}
                        </Dropdown.Menu>
                      </Dropdown>
                    )}
                    <Button
                      variant="success"
                      size="sm"
                      onClick={openCreateListModal}
                    >
                      + New List
                    </Button>
                    {wishlists.length > 1 && selectedWishListId && (
                      <Button
                        variant="danger"
                        size="sm"
                        onClick={openDeleteListModal}
                      >
                        Delete List
                      </Button>
                    )}
                  </div>
                </div>
                
                {selectedWishListId && (
                  <>
                    <AddItemForm onSubmit={handleAddItem} loading={loading} wishlists={wishlists} />
                    <WishListTable
                      items={items}
                      purchasedItems={purchasedItems}
                      onEdit={handleEditItem}
                      onMarkPurchased={handleMarkPurchased}
                      onDelete={handleDeleteItem}
                      wishListName={wishlists.find(l => l.id === selectedWishListId)?.name || 'My Wish List'}
                      onUpdateName={(name) => updateWishListNameById(selectedWishListId, name)}
                    />
                  </>
                )}
              </div>
            </Col>
          </Row>
        )}
      </Container>

      <Modal show={showCreateListModal} onHide={closeCreateListModal} centered>
        <Modal.Header closeButton={!listActionLoading}>
          <Modal.Title>Create New Wish List</Modal.Title>
        </Modal.Header>
        <Modal.Body>
          {listModalError && (
            <Alert variant="danger" onClose={() => setListModalError('')} dismissible>
              {listModalError}
            </Alert>
          )}
          <Form
            onSubmit={(event) => {
              event.preventDefault();
              const trimmedName = newListName.trim();
              if (!trimmedName) {
                setListModalError('Wish list name is required');
                return;
              }
              createWishList(trimmedName);
            }}
          >
            <Form.Group className="mb-3">
              <Form.Label>Wish List Name</Form.Label>
              <Form.Control
                type="text"
                value={newListName}
                onChange={(event) => setNewListName(event.target.value)}
                placeholder="Enter wish list name"
                autoFocus
                required
              />
            </Form.Group>
            <div className="d-flex justify-content-end gap-2">
              <Button variant="secondary" onClick={closeCreateListModal} disabled={listActionLoading}>
                Cancel
              </Button>
              <Button variant="success" type="submit" disabled={listActionLoading || !newListName.trim()}>
                {listActionLoading ? 'Creating...' : 'Create'}
              </Button>
            </div>
          </Form>
        </Modal.Body>
      </Modal>

      <Modal show={showDeleteListModal} onHide={closeDeleteListModal} centered>
        <Modal.Header closeButton={!listActionLoading}>
          <Modal.Title>Delete Wish List</Modal.Title>
        </Modal.Header>
        <Modal.Body>
          {listModalError && (
            <Alert variant="danger" onClose={() => setListModalError('')} dismissible>
              {listModalError}
            </Alert>
          )}
          <Form
            onSubmit={(event) => {
              event.preventDefault();
              if (!listToDeleteId) {
                setListModalError('Select a wish list to delete');
                return;
              }
              deleteWishList(listToDeleteId);
            }}
          >
            <Form.Group className="mb-3">
              <Form.Label>Select a wish list</Form.Label>
              <Form.Select
                value={listToDeleteId ?? ''}
                onChange={(event) => setListToDeleteId(Number(event.target.value))}
                required
              >
                <option value="">Select a wish list...</option>
                {wishlists.map((list) => (
                  <option key={list.id} value={list.id}>
                    {list.name}
                  </option>
                ))}
              </Form.Select>
            </Form.Group>
            <p className="text-muted mb-3">
              Deleting a wish list also deletes all items in that list.
            </p>
            <div className="d-flex justify-content-end gap-2">
              <Button variant="secondary" onClick={closeDeleteListModal} disabled={listActionLoading}>
                Cancel
              </Button>
              <Button variant="danger" type="submit" disabled={listActionLoading || !listToDeleteId}>
                {listActionLoading ? 'Deleting...' : 'Delete'}
              </Button>
            </div>
          </Form>
        </Modal.Body>
      </Modal>
    </>
  );
}

export default App;
