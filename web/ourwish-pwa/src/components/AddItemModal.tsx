import { useState } from 'react'
import type { FormEvent } from 'react'
import { ApiError } from '../api/client'
import { Modal } from './Modal'

export interface AddItemInput {
  productName: string
  price: number
  quantity: number
  url: string | null
}

export function AddItemModal({
  onClose,
  onSubmit,
}: {
  onClose: () => void
  onSubmit: (input: AddItemInput) => Promise<void>
}) {
  const [productName, setProductName] = useState('')
  const [price, setPrice] = useState('')
  const [quantity, setQuantity] = useState('1')
  const [url, setURL] = useState('')
  const [errorMessage, setErrorMessage] = useState<string | null>(null)
  const [isSubmitting, setIsSubmitting] = useState(false)

  const handleSubmit = async (event: FormEvent) => {
    event.preventDefault()

    const trimmedName = productName.trim()
    const parsedPrice = Number(price)
    const parsedQuantity = Number(quantity)

    if (!trimmedName || Number.isNaN(parsedPrice) || !Number.isInteger(parsedQuantity) || parsedQuantity < 1) {
      setErrorMessage('Please enter a valid product name, price, and quantity')
      return
    }

    setIsSubmitting(true)
    setErrorMessage(null)

    try {
      await onSubmit({
        productName: trimmedName,
        price: parsedPrice,
        quantity: parsedQuantity,
        url: url.trim() ? url.trim() : null,
      })
      onClose()
    } catch (error) {
      setErrorMessage(error instanceof ApiError ? error.message : 'Could not add item')
    } finally {
      setIsSubmitting(false)
    }
  }

  return (
    <Modal title="Add Item" onClose={onClose}>
      <form onSubmit={handleSubmit}>
        {errorMessage && <p className="error-text">{errorMessage}</p>}

        <div className="field">
          <label htmlFor="add-item-name">Product Name</label>
          <input
            id="add-item-name"
            value={productName}
            onChange={(event) => setProductName(event.target.value)}
            placeholder="e.g. Espresso Machine"
            autoFocus
            required
          />
        </div>

        <div className="name-row-2">
          <div className="field">
            <label htmlFor="add-item-price">Price Each</label>
            <input
              id="add-item-price"
              inputMode="decimal"
              value={price}
              onChange={(event) => setPrice(event.target.value)}
              placeholder="0.00"
              required
            />
          </div>
          <div className="field">
            <label htmlFor="add-item-quantity">Quantity</label>
            <input
              id="add-item-quantity"
              inputMode="numeric"
              value={quantity}
              onChange={(event) => setQuantity(event.target.value)}
              placeholder="1"
              required
            />
          </div>
        </div>

        <div className="field">
          <label htmlFor="add-item-url">Product URL</label>
          <input
            id="add-item-url"
            type="url"
            value={url}
            onChange={(event) => setURL(event.target.value)}
            placeholder="Optional — the server will try to grab a photo"
          />
        </div>

        <p className="modal-note">If a product URL is provided, OurWish will try to fetch the image server-side.</p>

        <div className="modal-footer">
          <button type="button" className="btn" onClick={onClose} disabled={isSubmitting}>
            Cancel
          </button>
          <button type="submit" className="btn btn-primary" disabled={isSubmitting}>
            {isSubmitting ? 'Adding…' : 'Add to List'}
          </button>
        </div>
      </form>
    </Modal>
  )
}
