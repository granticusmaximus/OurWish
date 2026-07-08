import { useState } from 'react'
import type { FormEvent } from 'react'
import type { Partner } from '../api/types'
import { ApiError } from '../api/client'
import { Modal } from './Modal'

export function CreateCollaborativeListModal({
  partners,
  isLoadingPartners,
  partnerLoadError,
  onClose,
  onSubmit,
}: {
  partners: Partner[]
  isLoadingPartners: boolean
  partnerLoadError: string | null
  onClose: () => void
  onSubmit: (partnerEmail: string, name: string) => Promise<void>
}) {
  const [partnerEmail, setPartnerEmail] = useState('')
  const [listName, setListName] = useState('')
  const [errorMessage, setErrorMessage] = useState<string | null>(null)
  const [isSubmitting, setIsSubmitting] = useState(false)

  const handleSubmit = async (event: FormEvent) => {
    event.preventDefault()
    const trimmedName = listName.trim()
    if (!partnerEmail || !trimmedName) {
      setErrorMessage('Please choose a partner and enter a list name')
      return
    }

    setIsSubmitting(true)
    setErrorMessage(null)
    try {
      await onSubmit(partnerEmail, trimmedName)
      onClose()
    } catch (error) {
      setErrorMessage(error instanceof ApiError ? error.message : 'Could not create collaborative list')
    } finally {
      setIsSubmitting(false)
    }
  }

  return (
    <Modal title="New Collaborative List" onClose={onClose}>
      <form onSubmit={handleSubmit}>
        {errorMessage && <p className="error-text">{errorMessage}</p>}
        {partnerLoadError && <p className="error-text">{partnerLoadError}</p>}

        {isLoadingPartners ? (
          <p className="modal-note">Loading partners…</p>
        ) : partners.length === 0 ? (
          <p className="modal-note">Create another user account first to start a collaborative list.</p>
        ) : (
          <div className="field">
            <label htmlFor="partner-email">Partner</label>
            <select
              id="partner-email"
              value={partnerEmail}
              onChange={(event) => setPartnerEmail(event.target.value)}
              required
            >
              <option value="">Select partner</option>
              {partners.map((partner) => (
                <option key={partner.email} value={partner.email}>
                  {partner.displayName} — {partner.email}
                </option>
              ))}
            </select>
          </div>
        )}

        <div className="field">
          <label htmlFor="collaborative-list-name">List Name</label>
          <input
            id="collaborative-list-name"
            value={listName}
            onChange={(event) => setListName(event.target.value)}
            placeholder="e.g. Bedroom Furniture, Vacation Trip"
            autoFocus
            required
          />
        </div>

        <div className="modal-footer">
          <button type="button" className="btn" onClick={onClose} disabled={isSubmitting}>
            Cancel
          </button>
          <button
            type="submit"
            className="btn btn-primary"
            disabled={isSubmitting || isLoadingPartners || partners.length === 0 || !partnerEmail || !listName.trim()}
          >
            {isSubmitting ? 'Creating…' : 'Create'}
          </button>
        </div>
      </form>
    </Modal>
  )
}
