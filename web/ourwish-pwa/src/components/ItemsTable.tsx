import { useState } from 'react'
import type { FormEvent } from 'react'
import type { Item } from '../api/types'
import { formatCurrency, TAX_RATE } from '../utils/currency'
import { ApiError } from '../api/client'

interface ItemInput {
  productName: string
  price: number
  quantity: number
  url: string | null
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
}

interface Draft {
  productName: string
  price: string
  quantity: string
  url: string
}

function draftFrom(item: Item): Draft {
  return {
    productName: item.productName,
    price: item.price.toFixed(2),
    quantity: String(item.quantity),
    url: item.url ?? '',
  }
}

function parsedDraft(draft: Draft): ItemInput | null {
  const price = Number(draft.price)
  const quantity = Number(draft.quantity)
  if (!draft.productName.trim() || Number.isNaN(price) || !Number.isInteger(quantity) || quantity < 1) {
    return null
  }
  return {
    productName: draft.productName.trim(),
    price,
    quantity,
    url: draft.url.trim() ? draft.url.trim() : null,
  }
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
}: ItemsTableProps) {
  const [editingId, setEditingId] = useState<number | null>(null)
  const [draft, setDraft] = useState<Draft>({ productName: '', price: '', quantity: '', url: '' })
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

  const saveEdit = async (id: number) => {
    const parsed = parsedDraft(draft)
    if (!parsed) {
      setErrorMessage('Please enter a valid product name, price, and quantity')
      return
    }
    await runAction(async () => {
      await onSave(id, parsed)
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

  const renderRow = (item: Item) => {
    const isEditing = editingId === item.id
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
            <input
              className="row-input"
              aria-label="Product name"
              value={draft.productName}
              onChange={(event) => setDraft({ ...draft, productName: event.target.value })}
            />
          ) : (
            <div className="item-product-cell">
              {item.imageURL && <img className="item-thumb" src={item.imageURL} alt="" />}
              <span>{item.productName}</span>
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
                <button type="button" className="btn" onClick={() => saveEdit(item.id)}>
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
        <tbody>{rows.map(renderRow)}</tbody>
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
