import { useState } from 'react'
import type { FormEvent } from 'react'
import { ApiError } from '../api/client'
import { Modal } from './Modal'

export interface AddItemInput {
  productName: string
  category?: string | null
  manufacturer?: string | null
  price: number
  msrp?: number | null
  quantity: number
  url: string | null
  officialProductURL?: string | null
  bestRetailerURL?: string | null
  primaryImageURL?: string | null
  itemDescription?: string | null
  specifications?: string | null
  weight?: string | null
  caliber?: string | null
  compatibility?: string | null
  purpose?: string | null
  notes?: string | null
  availabilityStatus?: string | null
  dateRetrieved?: string | null
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
  const [category, setCategory] = useState('')
  const [manufacturer, setManufacturer] = useState('')
  const [msrp, setMsrp] = useState('')
  const [officialProductURL, setOfficialProductURL] = useState('')
  const [bestRetailerURL, setBestRetailerURL] = useState('')
  const [primaryImageURL, setPrimaryImageURL] = useState('')
  const [itemDescription, setItemDescription] = useState('')
  const [specifications, setSpecifications] = useState('')
  const [weight, setWeight] = useState('')
  const [caliber, setCaliber] = useState('')
  const [compatibility, setCompatibility] = useState('')
  const [purpose, setPurpose] = useState('')
  const [notes, setNotes] = useState('')
  const [availabilityStatus, setAvailabilityStatus] = useState('')
  const [dateRetrieved, setDateRetrieved] = useState('')
  const [errorMessage, setErrorMessage] = useState<string | null>(null)
  const [isSubmitting, setIsSubmitting] = useState(false)

  const handleSubmit = async (event: FormEvent) => {
    event.preventDefault()

    const trimmedName = productName.trim()
    const parsedPrice = Number(price)
    const parsedMsrp = msrp.trim() ? Number(msrp) : null
    const parsedQuantity = Number(quantity)

    if (!trimmedName || Number.isNaN(parsedPrice) || !Number.isInteger(parsedQuantity) || parsedQuantity < 1) {
      setErrorMessage('Please enter a valid product name, price, and quantity')
      return
    }
    if (parsedMsrp !== null && Number.isNaN(parsedMsrp)) {
      setErrorMessage('MSRP must be a valid number when provided')
      return
    }

    setIsSubmitting(true)
    setErrorMessage(null)

    try {
      await onSubmit({
        productName: trimmedName,
        category: category.trim() ? category.trim() : null,
        manufacturer: manufacturer.trim() ? manufacturer.trim() : null,
        price: parsedPrice,
        msrp: parsedMsrp,
        quantity: parsedQuantity,
        url: url.trim() ? url.trim() : null,
        officialProductURL: officialProductURL.trim() ? officialProductURL.trim() : null,
        bestRetailerURL: bestRetailerURL.trim() ? bestRetailerURL.trim() : null,
        primaryImageURL: primaryImageURL.trim() ? primaryImageURL.trim() : null,
        itemDescription: itemDescription.trim() ? itemDescription.trim() : null,
        specifications: specifications.trim() ? specifications.trim() : null,
        weight: weight.trim() ? weight.trim() : null,
        caliber: caliber.trim() ? caliber.trim() : null,
        compatibility: compatibility.trim() ? compatibility.trim() : null,
        purpose: purpose.trim() ? purpose.trim() : null,
        notes: notes.trim() ? notes.trim() : null,
        availabilityStatus: availabilityStatus.trim() ? availabilityStatus.trim() : null,
        dateRetrieved: dateRetrieved.trim() ? dateRetrieved.trim() : null,
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

        <div className="field">
          <label htmlFor="add-item-category">Category</label>
          <input id="add-item-category" value={category} onChange={(event) => setCategory(event.target.value)} />
        </div>

        <div className="field">
          <label htmlFor="add-item-manufacturer">Manufacturer</label>
          <input id="add-item-manufacturer" value={manufacturer} onChange={(event) => setManufacturer(event.target.value)} />
        </div>

        <div className="name-row-2">
          <div className="field">
            <label htmlFor="add-item-msrp">MSRP</label>
            <input id="add-item-msrp" inputMode="decimal" value={msrp} onChange={(event) => setMsrp(event.target.value)} />
          </div>
          <div className="field">
            <label htmlFor="add-item-availability">Availability</label>
            <input
              id="add-item-availability"
              value={availabilityStatus}
              onChange={(event) => setAvailabilityStatus(event.target.value)}
              placeholder="In Stock / Out of Stock / Backorder"
            />
          </div>
        </div>

        <div className="field">
          <label htmlFor="add-item-purpose">Purpose</label>
          <input id="add-item-purpose" value={purpose} onChange={(event) => setPurpose(event.target.value)} />
        </div>

        <div className="field">
          <label htmlFor="add-item-official-url">Official Product URL</label>
          <input
            id="add-item-official-url"
            type="url"
            value={officialProductURL}
            onChange={(event) => setOfficialProductURL(event.target.value)}
          />
        </div>

        <div className="field">
          <label htmlFor="add-item-best-retailer-url">Best Retailer URL</label>
          <input
            id="add-item-best-retailer-url"
            type="url"
            value={bestRetailerURL}
            onChange={(event) => setBestRetailerURL(event.target.value)}
          />
        </div>

        <div className="field">
          <label htmlFor="add-item-image-url">Primary Image URL</label>
          <input
            id="add-item-image-url"
            type="url"
            value={primaryImageURL}
            onChange={(event) => setPrimaryImageURL(event.target.value)}
          />
        </div>

        <div className="field">
          <label htmlFor="add-item-specs">Specifications</label>
          <textarea id="add-item-specs" value={specifications} onChange={(event) => setSpecifications(event.target.value)} />
        </div>

        <div className="name-row-2">
          <div className="field">
            <label htmlFor="add-item-weight">Weight</label>
            <input id="add-item-weight" value={weight} onChange={(event) => setWeight(event.target.value)} />
          </div>
          <div className="field">
            <label htmlFor="add-item-caliber">Caliber</label>
            <input id="add-item-caliber" value={caliber} onChange={(event) => setCaliber(event.target.value)} />
          </div>
        </div>

        <div className="field">
          <label htmlFor="add-item-compatibility">Compatibility</label>
          <input id="add-item-compatibility" value={compatibility} onChange={(event) => setCompatibility(event.target.value)} />
        </div>

        <div className="field">
          <label htmlFor="add-item-date-retrieved">Date Retrieved</label>
          <input id="add-item-date-retrieved" type="date" value={dateRetrieved} onChange={(event) => setDateRetrieved(event.target.value)} />
        </div>

        <div className="field">
          <label htmlFor="add-item-description">Description</label>
          <textarea id="add-item-description" value={itemDescription} onChange={(event) => setItemDescription(event.target.value)} />
        </div>

        <div className="field">
          <label htmlFor="add-item-notes">Notes</label>
          <textarea id="add-item-notes" value={notes} onChange={(event) => setNotes(event.target.value)} />
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
