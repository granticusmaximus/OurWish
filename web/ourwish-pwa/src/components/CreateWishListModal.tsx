import { useState } from 'react'
import type { FormEvent } from 'react'
import { ApiError } from '../api/client'
import { Modal } from './Modal'

export function CreateWishListModal({
  onClose,
  onSubmit,
}: {
  onClose: () => void
  onSubmit: (name: string) => Promise<void>
}) {
  const [name, setName] = useState('')
  const [errorMessage, setErrorMessage] = useState<string | null>(null)
  const [isSubmitting, setIsSubmitting] = useState(false)

  const handleSubmit = async (event: FormEvent) => {
    event.preventDefault()
    const trimmed = name.trim()
    if (!trimmed) {
      setErrorMessage('Wish list name is required')
      return
    }

    setIsSubmitting(true)
    setErrorMessage(null)
    try {
      await onSubmit(trimmed)
      onClose()
    } catch (error) {
      setErrorMessage(error instanceof ApiError ? error.message : 'Could not create wish list')
    } finally {
      setIsSubmitting(false)
    }
  }

  return (
    <Modal title="New Wish List" onClose={onClose}>
      <form onSubmit={handleSubmit}>
        {errorMessage && <p className="error-text">{errorMessage}</p>}

        <div className="field">
          <label htmlFor="wish-list-name">List Name</label>
          <input
            id="wish-list-name"
            value={name}
            onChange={(event) => setName(event.target.value)}
            placeholder="e.g. Birthday, Holiday 2026"
            autoFocus
            required
          />
        </div>

        <div className="modal-footer">
          <button type="button" className="btn" onClick={onClose} disabled={isSubmitting}>
            Cancel
          </button>
          <button type="submit" className="btn btn-primary" disabled={isSubmitting || !name.trim()}>
            {isSubmitting ? 'Creating…' : 'Create'}
          </button>
        </div>
      </form>
    </Modal>
  )
}
