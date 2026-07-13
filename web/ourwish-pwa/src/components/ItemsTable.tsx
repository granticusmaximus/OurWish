import { useState } from 'react'
import type { FormEvent } from 'react'
import type { Item } from '../api/types'
import { formatCurrency, TAX_RATE } from '../utils/currency'
import { ApiError } from '../api/client'

interface ItemInput {
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

interface ItemsTableProps {
  title: string
  items: Item[]
  purchasedItems: Item[]
  showUrlColumn: boolean
  allowHideToggle: boolean
  allowRename: boolean
  onRename?: (name: string) => Promise<void>
  onSave: (id: number, input: ItemInput) => Promise<void>
  onTogglePurchased: (id: number, isPurchased: boolean) => Promise<void>
  onToggleHidden?: (id: number, isHidden: boolean) => Promise<void>
  onDelete: (id: number) => Promise<void>
  onMove?: (id: number, direction: 'up' | 'down') => Promise<void>
}

interface Draft {
  productName: string
  category: string
  manufacturer: string
  price: string
  msrp: string
  quantity: string
  url: string
  officialProductURL: string
  bestRetailerURL: string
  primaryImageURL: string
  itemDescription: string
  specifications: string
  weight: string
  caliber: string
  compatibility: string
  purpose: string
  notes: string
  availabilityStatus: string
  dateRetrieved: string
}

function toOptional(value: string): string | null {
  const trimmed = value.trim()
  return trimmed ? trimmed : null
}

function normalizeDateInput(value: string | null | undefined): string {
  if (!value) return ''
  const match = value.match(/^(\d{4}-\d{2}-\d{2})/)
  return match ? match[1] : value
}

function draftFrom(item: Item): Draft {
  return {
    productName: item.productName,
    category: item.category ?? '',
    manufacturer: item.manufacturer ?? '',
    price: item.price.toFixed(2),
    msrp: item.msrp?.toFixed(2) ?? '',
    quantity: String(item.quantity),
    url: item.url ?? '',
    officialProductURL: item.officialProductURL ?? '',
    bestRetailerURL: item.bestRetailerURL ?? '',
    primaryImageURL: item.primaryImageURL ?? '',
    itemDescription: item.itemDescription ?? '',
    specifications: item.specifications ?? '',
    weight: item.weight ?? '',
    caliber: item.caliber ?? '',
    compatibility: item.compatibility ?? '',
    purpose: item.purpose ?? '',
    notes: item.notes ?? '',
    availabilityStatus: item.availabilityStatus ?? '',
    dateRetrieved: normalizeDateInput(item.dateRetrieved),
  }
}

function parsedDraft(draft: Draft): ItemInput | null {
  const price = Number(draft.price)
  const quantity = Number(draft.quantity)
  const trimmedMsrp = draft.msrp.trim()
  const msrp = trimmedMsrp ? Number(trimmedMsrp) : null
  const trimmedDate = draft.dateRetrieved.trim()
  const dateRetrieved = trimmedDate ? trimmedDate : null

  if (!draft.productName.trim() || Number.isNaN(price) || !Number.isInteger(quantity) || quantity < 1) {
    return null
  }
  if (trimmedMsrp && Number.isNaN(msrp)) {
    return null
  }
  if (trimmedDate && !/^\d{4}-\d{2}-\d{2}$/.test(trimmedDate)) {
    return null
  }

  return {
    productName: draft.productName.trim(),
    category: toOptional(draft.category),
    manufacturer: toOptional(draft.manufacturer),
    price,
    msrp,
    quantity,
    url: toOptional(draft.url),
    officialProductURL: toOptional(draft.officialProductURL),
    bestRetailerURL: toOptional(draft.bestRetailerURL),
    primaryImageURL: toOptional(draft.primaryImageURL),
    itemDescription: toOptional(draft.itemDescription),
    specifications: toOptional(draft.specifications),
    weight: toOptional(draft.weight),
    caliber: toOptional(draft.caliber),
    compatibility: toOptional(draft.compatibility),
    purpose: toOptional(draft.purpose),
    notes: toOptional(draft.notes),
    availabilityStatus: toOptional(draft.availabilityStatus),
    dateRetrieved,
  }
}

function metadataSummary(item: Item): string[] {
  const chips: string[] = []
  if (item.manufacturer) chips.push(item.manufacturer)
  if (item.category) chips.push(item.category)
  if (item.availabilityStatus) chips.push(item.availabilityStatus)
  if (item.msrp != null) chips.push(`MSRP ${formatCurrency(item.msrp)}`)
  if (item.purpose) chips.push(item.purpose)
  if (item.caliber) chips.push(item.caliber)
  if (item.compatibility) chips.push(item.compatibility)
  return chips
}

// Mirrors macos/OurWish/OurWish/Views/Shared/ItemsTableView.swift.
export function ItemsTable({
  title,
  items,
  purchasedItems,
  showUrlColumn,
  allowHideToggle,
  allowRename,
  onRename,
  onSave,
  onTogglePurchased,
  onToggleHidden,
  onDelete,
  onMove,
}: ItemsTableProps) {
  const [editingId, setEditingId] = useState<number | null>(null)
  const [draft, setDraft] = useState<Draft>({
    productName: '',
    category: '',
    manufacturer: '',
    price: '',
    msrp: '',
    quantity: '',
    url: '',
    officialProductURL: '',
    bestRetailerURL: '',
    primaryImageURL: '',
    itemDescription: '',
    specifications: '',
    weight: '',
    caliber: '',
    compatibility: '',
    purpose: '',
    notes: '',
    availabilityStatus: '',
    dateRetrieved: '',
  })
  const [errorMessage, setErrorMessage] = useState<string | null>(null)
  const [isRenaming, setIsRenaming] = useState(false)
  const [renameDraft, setRenameDraft] = useState(title)
  const [showHidden, setShowHidden] = useState(false)
  const [showPurchased, setShowPurchased] = useState(false)

  const visibleItems = items.filter((item) => !item.isHidden)
  const hiddenItems = items.filter((item) => item.isHidden)
  const subtotal = visibleItems.reduce((sum, item) => sum + item.price * item.quantity, 0)
  const tax = subtotal * TAX_RATE
  const total = subtotal + tax
  const columnCount = showUrlColumn ? 6 : 5

  const startEdit = (item: Item) => {
    setEditingId(item.id)
    setDraft(draftFrom(item))
    setErrorMessage(null)
  }

  const runAction = async (action: () => Promise<void>) => {
    try {
      await action()
      setErrorMessage(null)
    } catch (error) {
      setErrorMessage(error instanceof ApiError ? error.message : 'Something went wrong')
    }
  }

  const saveEdit = async (item: Item) => {
    const parsed = parsedDraft(draft)
    if (!parsed) {
      setErrorMessage('Please enter valid values (name, price, quantity, MSRP if set, and YYYY-MM-DD date)')
      return
    }
    await runAction(async () => {
      await onSave(item.id, parsed)
      setEditingId(null)
    })
  }

  const commitRename = async (event: FormEvent) => {
    event.preventDefault()
    const trimmed = renameDraft.trim()
    if (!trimmed || !onRename) return
    await runAction(async () => {
      await onRename(trimmed)
      setIsRenaming(false)
    })
  }

  const renderRow = (item: Item, index: number, groupLength: number) => {
    const isEditing = editingId === item.id
    const allMetadataChips = metadataSummary(item)
    const metadataChips = allMetadataChips.slice(0, 4)
    const hiddenMetadataCount = Math.max(allMetadataChips.length - metadataChips.length, 0)
    const lineTotal = isEditing
      ? (Number(draft.price) || item.price) * (Number(draft.quantity) || item.quantity)
      : item.price * item.quantity

    return (
      <tr key={item.id}>
        <td>
          <input
            type="checkbox"
            checked={item.isPurchased}
            onChange={(event) => runAction(() => onTogglePurchased(item.id, event.target.checked))}
            aria-label="Purchased"
          />
        </td>
        <td>
          {isEditing ? (
            <div className="item-edit-stack">
              <input
                className="row-input"
                aria-label="Product name"
                value={draft.productName}
                onChange={(event) => setDraft({ ...draft, productName: event.target.value })}
              />
              <details className="metadata-editor">
                <summary>Metadata</summary>
                <div className="metadata-grid">
                  <label>
                    <span>Category</span>
                    <input
                      className="row-input"
                      value={draft.category}
                      onChange={(event) => setDraft({ ...draft, category: event.target.value })}
                    />
                  </label>
                  <label>
                    <span>Manufacturer</span>
                    <input
                      className="row-input"
                      value={draft.manufacturer}
                      onChange={(event) => setDraft({ ...draft, manufacturer: event.target.value })}
                    />
                  </label>
                  <label>
                    <span>MSRP</span>
                    <input
                      className="row-input"
                      value={draft.msrp}
                      onChange={(event) => setDraft({ ...draft, msrp: event.target.value })}
                    />
                  </label>
                  <label>
                    <span>Availability</span>
                    <input
                      className="row-input"
                      value={draft.availabilityStatus}
                      onChange={(event) => setDraft({ ...draft, availabilityStatus: event.target.value })}
                    />
                  </label>
                  <label>
                    <span>Purpose</span>
                    <input
                      className="row-input"
                      value={draft.purpose}
                      onChange={(event) => setDraft({ ...draft, purpose: event.target.value })}
                    />
                  </label>
                  <label>
                    <span>Weight</span>
                    <input
                      className="row-input"
                      value={draft.weight}
                      onChange={(event) => setDraft({ ...draft, weight: event.target.value })}
                    />
                  </label>
                  <label>
                    <span>Caliber</span>
                    <input
                      className="row-input"
                      value={draft.caliber}
                      onChange={(event) => setDraft({ ...draft, caliber: event.target.value })}
                    />
                  </label>
                  <label>
                    <span>Compatibility</span>
                    <input
                      className="row-input"
                      value={draft.compatibility}
                      onChange={(event) => setDraft({ ...draft, compatibility: event.target.value })}
                    />
                  </label>
                  <label>
                    <span>Date Retrieved</span>
                    <input
                      className="row-input"
                      placeholder="YYYY-MM-DD"
                      value={draft.dateRetrieved}
                      onChange={(event) => setDraft({ ...draft, dateRetrieved: event.target.value })}
                    />
                  </label>
                  <label className="metadata-url-field">
                    <span>Official URL</span>
                    <input
                      className="row-input"
                      value={draft.officialProductURL}
                      onChange={(event) => setDraft({ ...draft, officialProductURL: event.target.value })}
                    />
                  </label>
                  <label className="metadata-url-field">
                    <span>Retailer URL</span>
                    <input
                      className="row-input"
                      value={draft.bestRetailerURL}
                      onChange={(event) => setDraft({ ...draft, bestRetailerURL: event.target.value })}
                    />
                  </label>
                  <label className="metadata-url-field">
                    <span>Primary Image URL</span>
                    <input
                      className="row-input"
                      value={draft.primaryImageURL}
                      onChange={(event) => setDraft({ ...draft, primaryImageURL: event.target.value })}
                    />
                  </label>
                  <label className="metadata-textarea-field">
                    <span>Description</span>
                    <textarea
                      className="row-input"
                      rows={3}
                      value={draft.itemDescription}
                      onChange={(event) => setDraft({ ...draft, itemDescription: event.target.value })}
                    />
                  </label>
                  <label className="metadata-textarea-field">
                    <span>Specifications</span>
                    <textarea
                      className="row-input"
                      rows={3}
                      value={draft.specifications}
                      onChange={(event) => setDraft({ ...draft, specifications: event.target.value })}
                    />
                  </label>
                  <label className="metadata-textarea-field">
                    <span>Notes</span>
                    <textarea
                      className="row-input"
                      rows={3}
                      value={draft.notes}
                      onChange={(event) => setDraft({ ...draft, notes: event.target.value })}
                    />
                  </label>
                </div>
              </details>
            </div>
          ) : (
            <div className="item-product-cell">
              {item.imageURL && <img className="item-thumb" src={item.imageURL} alt="" />}
              <div className="item-product-details">
                <span>{item.productName}</span>
                {metadataChips.length > 0 && (
                  <div className="item-meta-summary">
                    {metadataChips.map((chip, index) => (
                      <span key={`${chip}-${index}`} className="item-meta-chip">
                        {chip}
                      </span>
                    ))}
                    {hiddenMetadataCount > 0 && <span className="item-meta-chip">+{hiddenMetadataCount} more</span>}
                  </div>
                )}
              </div>
            </div>
          )}
        </td>
        <td>
          {isEditing ? (
            <input
              className="row-input"
              aria-label="Quantity"
              value={draft.quantity}
              onChange={(event) => setDraft({ ...draft, quantity: event.target.value })}
            />
          ) : (
            item.quantity
          )}
        </td>
        <td>
          {isEditing ? (
            <input
              className="row-input"
              aria-label="Price"
              value={draft.price}
              onChange={(event) => setDraft({ ...draft, price: event.target.value })}
            />
          ) : (
            formatCurrency(item.price)
          )}
        </td>
        <td>{formatCurrency(lineTotal)}</td>
        {showUrlColumn && (
          <td>
            {isEditing ? (
              <input
                className="row-input"
                aria-label="Product URL"
                value={draft.url}
                onChange={(event) => setDraft({ ...draft, url: event.target.value })}
              />
            ) : item.url ? (
              <a href={item.url} target="_blank" rel="noreferrer">
                Link
              </a>
            ) : (
              '—'
            )}
          </td>
        )}
        <td>
          <div className="item-actions">
            {isEditing ? (
              <>
                <button type="button" className="btn" onClick={() => saveEdit(item)}>
                  Save
                </button>
                <button type="button" className="btn" onClick={() => setEditingId(null)}>
                  Cancel
                </button>
              </>
            ) : (
              <>
                <button
                  type="button"
                  className="icon-btn"
                  onClick={() => startEdit(item)}
                  title="Edit"
                  aria-label="Edit"
                >
                  ✏️
                </button>
                <button
                  type="button"
                  className="icon-btn"
                  onClick={() => {
                    if (confirm(`Delete "${item.productName}"?`)) {
                      void runAction(() => onDelete(item.id))
                    }
                  }}
                  title="Delete"
                  aria-label="Delete"
                >
                  🗑️
                </button>
                {allowHideToggle && onToggleHidden && (
                  <button
                    type="button"
                    className="icon-btn"
                    onClick={() => runAction(() => onToggleHidden(item.id, !item.isHidden))}
                    title={item.isHidden ? 'Show' : 'Hide'}
                    aria-label={item.isHidden ? 'Show' : 'Hide'}
                  >
                    {item.isHidden ? '👁️' : '🙈'}
                  </button>
                )}
                {onMove && index > 0 && (
                  <button
                    type="button"
                    className="icon-btn"
                    onClick={() => runAction(() => onMove(item.id, 'up'))}
                    title="Move up"
                    aria-label="Move up"
                  >
                    ▲
                  </button>
                )}
                {onMove && index < groupLength - 1 && (
                  <button
                    type="button"
                    className="icon-btn"
                    onClick={() => runAction(() => onMove(item.id, 'down'))}
                    title="Move down"
                    aria-label="Move down"
                  >
                    ▼
                  </button>
                )}
              </>
            )}
          </div>
        </td>
      </tr>
    )
  }

  const renderTable = (rows: Item[]) => (
    <div className="items-table-wrap">
      <table className="items-table">
        <thead>
          <tr>
            <th>Purchased</th>
            <th>Product</th>
            <th>Qty</th>
            <th>Price</th>
            <th>Total</th>
            {showUrlColumn && <th>URL</th>}
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>{rows.map((item, index) => renderRow(item, index, rows.length))}</tbody>
        <tfoot>
          <tr>
            <td colSpan={columnCount}>Subtotal</td>
            <td>{formatCurrency(subtotal)}</td>
          </tr>
          <tr>
            <td colSpan={columnCount}>Tax ({(TAX_RATE * 100).toFixed(2)}%)</td>
            <td>{formatCurrency(tax)}</td>
          </tr>
          <tr>
            <td colSpan={columnCount}>Total</td>
            <td>{formatCurrency(total)}</td>
          </tr>
        </tfoot>
      </table>
    </div>
  )

  return (
    <div className="items-card">
      <div className="items-card-header">
        {allowRename && isRenaming ? (
          <form onSubmit={commitRename} className="rename-form">
            <input
              className="row-input"
              value={renameDraft}
              onChange={(event) => setRenameDraft(event.target.value)}
              autoFocus
            />
            <button type="submit" className="btn">
              Save
            </button>
            <button type="button" className="btn" onClick={() => setIsRenaming(false)}>
              Cancel
            </button>
          </form>
        ) : (
          <>
            <span>{visibleItems.length === 1 ? '1 item' : `${visibleItems.length} items`}</span>
            {allowRename && onRename && (
              <button
                type="button"
                className="btn-link"
                onClick={() => {
                  setRenameDraft(title)
                  setIsRenaming(true)
                }}
              >
                Rename
              </button>
            )}
          </>
        )}
      </div>

      {errorMessage && <p className="error-text">{errorMessage}</p>}

      {items.length === 0 ? (
        <div className="empty-state">
          <span className="empty-icon">🛒</span>
          <p>No items yet. Add something to get started.</p>
        </div>
      ) : (
        <>
          {renderTable(visibleItems)}
          {hiddenItems.length > 0 && (
            <div className="purchased-section">
              <button type="button" className="btn-link" onClick={() => setShowHidden(!showHidden)}>
                {showHidden ? '▼' : '▶'} Hidden Items ({hiddenItems.length})
              </button>
              {showHidden && renderTable(hiddenItems)}
            </div>
          )}
        </>
      )}

      {purchasedItems.length > 0 && (
        <div className="purchased-section">
          <button type="button" className="btn-link" onClick={() => setShowPurchased(!showPurchased)}>
            {showPurchased ? '▼' : '▶'} Purchased Items ({purchasedItems.length})
          </button>
          {showPurchased &&
            purchasedItems.map((item) => (
              <div className="purchased-row" key={item.id}>
                <input
                  type="checkbox"
                  checked
                  onChange={() => runAction(() => onTogglePurchased(item.id, false))}
                  aria-label="Purchased"
                />
                {item.imageURL && <img className="item-thumb" src={item.imageURL} alt="" />}
                <span>
                  {item.productName} — {item.quantity} x {formatCurrency(item.price)} ={' '}
                  {formatCurrency(item.price * item.quantity)}
                </span>
                <span className="spacer" />
                <button
                  type="button"
                  className="btn btn-danger"
                  onClick={() => {
                    if (confirm(`Remove "${item.productName}"?`)) {
                      void runAction(() => onDelete(item.id))
                    }
                  }}
                >
                  Remove
                </button>
              </div>
            ))}
        </div>
      )}
    </div>
  )
}
