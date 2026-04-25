import React, { useState, useEffect } from 'react';
import { Card, Button, Form, Alert, ListGroup, Spinner, Modal } from 'react-bootstrap';

interface CollaborativeList {
  id: number;
  name: string;
  partner_name: string;
}

interface PartnerUser {
  id: number;
  email: string;
  display_name: string;
}

interface CollaborativeListsProps {
  onSelectList: (listId?: number) => void;
  selectedListId?: number;
}

export function CollaborativeLists({ onSelectList, selectedListId }: CollaborativeListsProps) {
  const [lists, setLists] = useState<CollaborativeList[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [creating, setCreating] = useState(false);
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [partnerEmail, setPartnerEmail] = useState('');
  const [listName, setListName] = useState('');
  const [partnerUsers, setPartnerUsers] = useState<PartnerUser[]>([]);
  const [loadingPartners, setLoadingPartners] = useState(false);

  useEffect(() => {
    fetchLists();
    fetchPartnerUsers();
  }, []);

  const fetchLists = async () => {
    try {
      setLoading(true);
      const response = await fetch('/api/collaborative/lists', {
        credentials: 'include'
      });

      if (!response.ok) throw new Error('Failed to fetch lists');

      const data = await response.json();
      setLists(data);
    } catch (err: any) {
      setError(err.message || 'Failed to load collaborative lists');
    } finally {
      setLoading(false);
    }
  };

  const fetchPartnerUsers = async () => {
    try {
      setLoadingPartners(true);
      const response = await fetch('/api/collaborative/partners', {
        credentials: 'include'
      });

      if (!response.ok) throw new Error('Failed to fetch users');

      const data = await response.json();
      setPartnerUsers(data);
    } catch (err: any) {
      setError(err.message || 'Failed to load users');
    } finally {
      setLoadingPartners(false);
    }
  };

  const handleCreateList = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');

    if (!partnerEmail || !listName) {
      setError('Partner email and list name are required');
      return;
    }

    try {
      setCreating(true);
      const response = await fetch('/api/collaborative/create', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ partnerEmail, listName }),
        credentials: 'include'
      });

      if (!response.ok) {
        const data = await response.json();
        throw new Error(data.error || 'Failed to create list');
      }

      await fetchLists();
      setShowCreateModal(false);
      setPartnerEmail('');
      setListName('');
    } catch (err: any) {
      setError(err.message || 'Failed to create collaborative list');
    } finally {
      setCreating(false);
    }
  };

  const handleDeleteList = async (listId: number) => {
    if (window.confirm('Are you sure you want to delete this collaborative list?')) {
      try {
        const response = await fetch(`/api/collaborative/lists/${listId}`, {
          method: 'DELETE',
          credentials: 'include'
        });

        if (!response.ok) throw new Error('Failed to delete list');

        setLists(lists.filter(l => l.id !== listId));
        if (selectedListId === listId) {
          onSelectList(undefined);
        }
      } catch (err: any) {
        setError(err.message || 'Failed to delete list');
      }
    }
  };

  if (loading) {
    return (
      <Card className="mb-4">
        <Card.Body className="text-center">
          <Spinner animation="border" />
        </Card.Body>
      </Card>
    );
  }

  return (
    <>
      <Card className="mb-4 shadow-sm">
        <Card.Body>
          <div className="d-flex justify-content-between align-items-center mb-3">
            <Card.Title>Collaborative Lists</Card.Title>
            <Button
              variant="success"
              size="sm"
              onClick={() => {
                setShowCreateModal(true);
                if (partnerUsers.length === 0) {
                  fetchPartnerUsers();
                }
              }}
            >
              New Collaborative List
            </Button>
          </div>

          {error && <Alert variant="danger" onClose={() => setError('')} dismissible>{error}</Alert>}

          {lists.length === 0 ? (
            <Alert variant="info">No collaborative lists yet. Create one to get started!</Alert>
          ) : (
            <ListGroup>
              {lists.map((list) => (
                <ListGroup.Item
                  key={list.id}
                  className="d-flex justify-content-between align-items-center"
                  style={{
                    cursor: 'pointer',
                    backgroundColor: selectedListId === list.id ? '#e7f3ff' : 'transparent'
                  }}
                  onClick={() => onSelectList(list.id)}
                >
                  <div>
                    <strong>{list.name}</strong>
                    <br />
                    <small className="text-muted">With {list.partner_name}</small>
                  </div>
                  <Button
                    variant="danger"
                    size="sm"
                    onClick={(e) => {
                      e.stopPropagation();
                      handleDeleteList(list.id);
                    }}
                  >
                    Delete
                  </Button>
                </ListGroup.Item>
              ))}
            </ListGroup>
          )}
        </Card.Body>
      </Card>

      {/* Create Modal */}
      <Modal show={showCreateModal} onHide={() => setShowCreateModal(false)}>
        <Modal.Header closeButton>
          <Modal.Title>Create Collaborative List</Modal.Title>
        </Modal.Header>
        <Modal.Body>
          <Form onSubmit={handleCreateList}>
            <Form.Group className="mb-3">
              <Form.Label>Partner Email</Form.Label>
              <Form.Select
                value={partnerEmail}
                onChange={(e) => setPartnerEmail(e.target.value)}
                required
                disabled={loadingPartners || partnerUsers.length === 0}
              >
                <option value="">
                  {loadingPartners
                    ? 'Loading users...'
                    : partnerUsers.length === 0
                      ? 'No partner users available'
                      : 'Select partner email'}
                </option>
                {partnerUsers.map((partner) => (
                  <option key={partner.id} value={partner.email}>
                    {partner.email}
                  </option>
                ))}
              </Form.Select>
              {!loadingPartners && partnerUsers.length === 0 && (
                <Form.Text className="text-muted">
                  Create another user account first to start a collaborative list.
                </Form.Text>
              )}
            </Form.Group>

            <Form.Group className="mb-3">
              <Form.Label>List Name</Form.Label>
              <Form.Control
                type="text"
                value={listName}
                onChange={(e) => setListName(e.target.value)}
                placeholder="e.g., Bedroom Furniture, Vacation Trip"
                required
              />
            </Form.Group>

            <div className="d-flex gap-2">
              <Button
                variant="primary"
                type="submit"
                disabled={creating}
                className="flex-grow-1"
              >
                {creating ? 'Creating...' : 'Create'}
              </Button>
              <Button
                variant="secondary"
                onClick={() => setShowCreateModal(false)}
                disabled={creating}
              >
                Cancel
              </Button>
            </div>
          </Form>
        </Modal.Body>
      </Modal>
    </>
  );
}
