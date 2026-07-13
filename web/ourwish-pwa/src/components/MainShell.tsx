import { useEffect, useRef, useState } from 'react'
import { api, ApiError } from '../api/client'
import { useAuth } from '../auth/AuthContext'
import type { CollaborativeList, Item, Partner, WishList } from '../api/types'
import type { AddItemInput } from './AddItemModal'
import { AddItemModal } from './AddItemModal'
import { CreateCollaborativeListModal } from './CreateCollaborativeListModal'
import { CreateWishListModal } from './CreateWishListModal'
import { ItemsTable } from './ItemsTable'
import { ProfileModal } from './ProfileModal'

type ListSelection =
  | { kind: 'wish'; id: number }
  | { kind: 'collaborative'; id: number }
  | null

type MobileView = 'sidebar' | 'detail'
type OpenMenu = 'new-list' | 'account' | null

function chooseSelection(
  candidate: ListSelection,
  wishLists: WishList[],
  collaborativeLists: CollaborativeList[],
): ListSelection {
  if (candidate?.kind === 'wish' && wishLists.some((list) => list.id === candidate.id)) {
    return candidate
  }
  if (
    candidate?.kind === 'collaborative'
    && collaborativeLists.some((list) => list.id === candidate.id)
  ) {
    return candidate
  }
  if (wishLists[0]) {
    return { kind: 'wish', id: wishLists[0].id }
  }
  if (collaborativeLists[0]) {
    return { kind: 'collaborative', id: collaborativeLists[0].id }
  }
  return null
}

function isMobileViewport(): boolean {
  return window.matchMedia('(max-width: 768px)').matches
}

export function MainShell({ onCreateNewUser }: { onCreateNewUser: () => void }) {
  const { currentUser, logout } = useAuth()
  const [wishLists, setWishLists] = useState<WishList[]>([])
  const [collaborativeLists, setCollaborativeLists] = useState<CollaborativeList[]>([])
  const [partners, setPartners] = useState<Partner[]>([])
  const [selectedList, setSelectedList] = useState<ListSelection>(null)
  const [activeItems, setActiveItems] = useState<Item[]>([])
  const [purchasedItems, setPurchasedItems] = useState<Item[]>([])
  const [isLoadingLists, setIsLoadingLists] = useState(true)
  const [isLoadingItems, setIsLoadingItems] = useState(false)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)
  const [flashMessage, setFlashMessage] = useState<{ kind: 'success' | 'error'; text: string } | null>(null)
  const [mobileView, setMobileView] = useState<MobileView>(() => (isMobileViewport() ? 'sidebar' : 'detail'))
  const [openMenu, setOpenMenu] = useState<OpenMenu>(null)
  const [showAddItemModal, setShowAddItemModal] = useState(false)
  const [showCreateWishListModal, setShowCreateWishListModal] = useState(false)
  const [showCreateCollaborativeListModal, setShowCreateCollaborativeListModal] = useState(false)
  const [showProfileModal, setShowProfileModal] = useState(false)
  const [isLoadingPartners, setIsLoadingPartners] = useState(false)
  const [partnerLoadError, setPartnerLoadError] = useState<string | null>(null)
  const itemsRequestIdRef = useRef(0)
  const newListMenuRef = useRef<HTMLDivElement | null>(null)
  const accountMenuRef = useRef<HTMLDivElement | null>(null)

  const selectedWishList =
    selectedList?.kind === 'wish' ? wishLists.find((list) => list.id === selectedList.id) ?? null : null
  const selectedCollaborativeList =
    selectedList?.kind === 'collaborative'
      ? collaborativeLists.find((list) => list.id === selectedList.id) ?? null
      : null

  const webAccessURL =
    window.location.port === '8420'
      ? window.location.origin
      : `${window.location.protocol}//${window.location.hostname}:8420`

  useEffect(() => {
    void loadLists()
  }, [])

  useEffect(() => {
    if (!selectedList) {
      setActiveItems([])
      setPurchasedItems([])
      if (isMobileViewport()) {
        setMobileView('sidebar')
      }
      return
    }

    if (!isMobileViewport()) {
      setMobileView('detail')
    }

    void loadItems(selectedList)
  }, [selectedList])

  useEffect(() => {
    const mediaQuery = window.matchMedia('(max-width: 768px)')
    const syncView = () => {
      if (!mediaQuery.matches) {
        setMobileView('detail')
      } else if (!selectedList) {
        setMobileView('sidebar')
      }
    }

    syncView()
    mediaQuery.addEventListener('change', syncView)
    return () => mediaQuery.removeEventListener('change', syncView)
  }, [selectedList])

  useEffect(() => {
    if (!showCreateCollaborativeListModal) return

    setIsLoadingPartners(true)
    setPartnerLoadError(null)
    api
      .partners()
      .then(setPartners)
      .catch((error) => {
        setPartners([])
        setPartnerLoadError(error instanceof ApiError ? error.message : 'Could not load partners')
      })
      .finally(() => setIsLoadingPartners(false))
  }, [showCreateCollaborativeListModal])

  useEffect(() => {
    if (!openMenu) return

    const handlePointerDown = (event: MouseEvent) => {
      const target = event.target as Node
      if (openMenu === 'new-list' && newListMenuRef.current?.contains(target)) return
      if (openMenu === 'account' && accountMenuRef.current?.contains(target)) return
      setOpenMenu(null)
    }

    document.addEventListener('mousedown', handlePointerDown)
    return () => document.removeEventListener('mousedown', handlePointerDown)
  }, [openMenu])

  useEffect(() => {
    if (!flashMessage) return
    const timeoutId = window.setTimeout(() => setFlashMessage(null), 2400)
    return () => window.clearTimeout(timeoutId)
  }, [flashMessage])

  async function loadLists(preferredSelection?: ListSelection) {
    setIsLoadingLists(true)
    try {
      const [nextWishLists, nextCollaborativeLists] = await Promise.all([
        api.wishLists(),
        api.collaborativeLists(),
      ])
      setWishLists(nextWishLists)
      setCollaborativeLists(nextCollaborativeLists)
      setSelectedList((current) => chooseSelection(preferredSelection ?? current, nextWishLists, nextCollaborativeLists))
      setErrorMessage(null)
    } catch (error) {
      setErrorMessage(error instanceof ApiError ? error.message : 'Could not load your lists')
    } finally {
      setIsLoadingLists(false)
    }
  }

  async function loadItems(selection: Exclude<ListSelection, null>) {
    const requestId = ++itemsRequestIdRef.current
    setIsLoadingItems(true)

    try {
      const response =
        selection.kind === 'wish'
          ? await api.wishListItems(selection.id)
          : await api.collaborativeItems(selection.id)

      if (requestId !== itemsRequestIdRef.current) return

      setActiveItems(response.active)
      setPurchasedItems(response.purchased)
      setErrorMessage(null)
    } catch (error) {
      if (requestId !== itemsRequestIdRef.current) return
      setActiveItems([])
      setPurchasedItems([])
      setErrorMessage(error instanceof ApiError ? error.message : 'Could not load items')
    } finally {
      if (requestId === itemsRequestIdRef.current) {
        setIsLoadingItems(false)
      }
    }
  }

  async function refreshSelectedItems() {
    if (!selectedList) return
    await loadItems(selectedList)
  }

  function selectList(selection: Exclude<ListSelection, null>) {
    setSelectedList(selection)
    if (isMobileViewport()) {
      setMobileView('detail')
    }
  }

  async function handleAddItem(input: AddItemInput) {
    if (!selectedList) return
    if (selectedList.kind === 'wish') {
      await api.addWishListItem(selectedList.id, input)
    } else {
      await api.addCollaborativeItem(selectedList.id, input)
    }
    await refreshSelectedItems()
  }

  async function handleRenameWishList(name: string) {
    if (!selectedWishList) return
    await api.renameWishList(selectedWishList.id, name)
    await loadLists({ kind: 'wish', id: selectedWishList.id })
  }

  async function handleSaveItem(id: number, input: AddItemInput) {
    if (!selectedList) return
    if (selectedList.kind === 'wish') {
      await api.updateItem(id, input)
    } else {
      await api.updateCollaborativeItem(selectedList.id, id, input)
    }
    await refreshSelectedItems()
  }

  async function handleTogglePurchased(id: number, isPurchased: boolean) {
    if (!selectedList) return
    if (selectedList.kind === 'wish') {
      await api.setItemPurchased(id, isPurchased)
    } else {
      await api.setCollaborativeItemPurchased(selectedList.id, id, isPurchased)
    }
    await refreshSelectedItems()
  }

  async function handleToggleHidden(id: number, isHidden: boolean) {
    if (!selectedList) return
    if (selectedList.kind === 'wish') {
      await api.setItemHidden(id, isHidden)
    } else {
      await api.setCollaborativeItemHidden(selectedList.id, id, isHidden)
    }
    await refreshSelectedItems()
  }

  async function handleMoveItem(id: number, direction: 'up' | 'down') {
    if (!selectedList) return
    const currentIndex = activeItems.findIndex((item) => item.id === id)
    if (currentIndex === -1) return
    const isHidden = activeItems[currentIndex].isHidden
    const groupIndices = activeItems
      .map((_, index) => index)
      .filter((index) => activeItems[index].isHidden === isHidden)
    const position = groupIndices.indexOf(currentIndex)
    const swapPosition = direction === 'up' ? position - 1 : position + 1
    if (swapPosition < 0 || swapPosition >= groupIndices.length) return
    const swapIndex = groupIndices[swapPosition]

    const reordered = [...activeItems]
    ;[reordered[currentIndex], reordered[swapIndex]] = [reordered[swapIndex], reordered[currentIndex]]
    const orderedItemIds = reordered.map((item) => item.id)

    if (selectedList.kind === 'wish') {
      await api.reorderWishListItems(selectedList.id, orderedItemIds)
    } else {
      await api.reorderCollaborativeItems(selectedList.id, orderedItemIds)
    }
    await refreshSelectedItems()
  }

  async function handleDeleteItem(id: number) {
    if (!selectedList) return
    if (selectedList.kind === 'wish') {
      await api.deleteItem(id)
    } else {
      await api.deleteCollaborativeItem(selectedList.id, id)
    }
    await refreshSelectedItems()
  }

  async function handleCreateWishList(name: string) {
    const created = await api.createWishList(name)
    await loadLists({ kind: 'wish', id: created.id })
    if (isMobileViewport()) {
      setMobileView('detail')
    }
  }

  async function handleCreateCollaborativeList(partnerEmail: string, name: string) {
    const created = await api.createCollaborativeList(partnerEmail, name)
    await loadLists({ kind: 'collaborative', id: created.id })
    if (isMobileViewport()) {
      setMobileView('detail')
    }
  }

  async function handleDeleteSelectedList() {
    if (!selectedList) return

    const label = selectedWishList?.name ?? selectedCollaborativeList?.name ?? 'this list'
    const message =
      selectedList.kind === 'wish'
        ? `Delete "${label}"? This also removes all items in the list.`
        : `Delete "${label}"? This removes the collaborative list for both people.`

    if (!window.confirm(message)) {
      return
    }

    if (selectedList.kind === 'wish') {
      await api.deleteWishList(selectedList.id)
    } else {
      await api.deleteCollaborativeList(selectedList.id)
    }

    await loadLists()
    if (isMobileViewport()) {
      setMobileView('sidebar')
    }
  }

  async function handleCopyWebLink() {
    try {
      await navigator.clipboard.writeText(webAccessURL)
      setFlashMessage({ kind: 'success', text: 'Web access link copied' })
      setOpenMenu(null)
    } catch {
      setFlashMessage({ kind: 'error', text: 'Could not copy the web link' })
    }
  }

  const detailTitle = selectedWishList?.name ?? selectedCollaborativeList?.name ?? 'OurWish'

  return (
    <div className="app-shell">
      <header className={`app-header ${mobileView === 'detail' ? 'showing-detail' : ''}`}>
        <button
          type="button"
          className="btn back-btn"
          onClick={() => setMobileView('sidebar')}
          aria-label="Back to lists"
        >
          ← Lists
        </button>

        <div className="brand">
          <span className="brand-glyph-sm">🎁</span>
          <span>OurWish</span>
        </div>

        <div className="spacer" />

        <div className="header-actions">
          <div className="menu-wrap" ref={newListMenuRef}>
            <button
              type="button"
              className="btn"
              onClick={() => setOpenMenu((current) => (current === 'new-list' ? null : 'new-list'))}
            >
              + New List
            </button>
            {openMenu === 'new-list' && (
              <div className="menu-panel">
                <button
                  type="button"
                  className="menu-item"
                  onClick={() => {
                    setShowCreateWishListModal(true)
                    setOpenMenu(null)
                  }}
                >
                  New Wish List
                </button>
                <button
                  type="button"
                  className="menu-item"
                  onClick={() => {
                    setShowCreateCollaborativeListModal(true)
                    setOpenMenu(null)
                  }}
                >
                  New Collaborative List
                </button>
              </div>
            )}
          </div>

          <div className="menu-wrap" ref={accountMenuRef}>
            <button
              type="button"
              className="btn account-trigger"
              onClick={() => setOpenMenu((current) => (current === 'account' ? null : 'account'))}
            >
              {currentUser?.imageURL ? (
                <img className="account-avatar" src={currentUser.imageURL} alt="" />
              ) : (
                <span className="account-avatar account-avatar-fallback">👤</span>
              )}
              <span className="account-name">{currentUser?.displayName ?? 'Account'}</span>
            </button>
            {openMenu === 'account' && (
              <div className="menu-panel menu-panel-account">
                <button
                  type="button"
                  className="menu-item"
                  onClick={() => {
                    setOpenMenu(null)
                    setShowProfileModal(true)
                  }}
                >
                  Edit Profile
                </button>
                <button
                  type="button"
                  className="menu-item"
                  onClick={() => {
                    setOpenMenu(null)
                    onCreateNewUser()
                  }}
                >
                  Create New User
                </button>
                <div className="menu-divider" />
                <button type="button" className="menu-item" onClick={() => void handleCopyWebLink()}>
                  Copy Web Link
                </button>
                <p className="menu-note">Open {webAccessURL} on another device on this WiFi network.</p>
                <div className="menu-divider" />
                <button
                  type="button"
                  className="menu-item menu-item-danger"
                  onClick={() => {
                    setOpenMenu(null)
                    logout()
                  }}
                >
                  Log Out
                </button>
              </div>
            )}
          </div>
        </div>
      </header>

      {flashMessage && (
        <div className={`shell-flash ${flashMessage.kind === 'error' ? 'shell-flash-error' : 'shell-flash-success'}`}>
          {flashMessage.text}
        </div>
      )}

      <div className={`app-body ${mobileView === 'detail' ? 'showing-detail' : ''}`}>
        <aside className="sidebar">
          <div className="sidebar-section">
            <h3>My Wish Lists</h3>
            {wishLists.length === 0 ? (
              <p className="sidebar-empty">No wish lists yet</p>
            ) : (
              wishLists.map((list) => (
                <button
                  key={list.id}
                  type="button"
                  className={`sidebar-item ${selectedWishList?.id === list.id ? 'active' : ''}`}
                  onClick={() => selectList({ kind: 'wish', id: list.id })}
                >
                  <span aria-hidden="true">🎁</span>
                  <span>{list.name}</span>
                </button>
              ))
            )}
          </div>

          <div className="sidebar-section">
            <h3>Collaborative Lists</h3>
            {collaborativeLists.length === 0 ? (
              <p className="sidebar-empty">No collaborative lists yet</p>
            ) : (
              collaborativeLists.map((list) => (
                <button
                  key={list.id}
                  type="button"
                  className={`sidebar-item ${selectedCollaborativeList?.id === list.id ? 'active' : ''}`}
                  onClick={() => selectList({ kind: 'collaborative', id: list.id })}
                >
                  <span aria-hidden="true">🤝</span>
                  <span>{list.name}</span>
                </button>
              ))
            )}
          </div>
        </aside>

        <main className="detail-pane">
          {isLoadingLists ? (
            <div className="empty-state">
              <span className="empty-icon">⏳</span>
              <p>Loading your lists…</p>
            </div>
          ) : !selectedList ? (
            <div className="empty-state">
              <span className="empty-icon">🎁</span>
              <p>Create a wish list to start adding items.</p>
              <button type="button" className="btn btn-primary" onClick={() => setShowCreateWishListModal(true)}>
                New Wish List
              </button>
            </div>
          ) : (
            <>
              <div className="detail-header">
                <div>
                  <h1>{detailTitle}</h1>
                  {selectedCollaborativeList && (
                    <p className="detail-meta">Shared with {selectedCollaborativeList.partnerName}</p>
                  )}
                </div>
                <div className="detail-actions">
                  <button type="button" className="btn btn-primary" onClick={() => setShowAddItemModal(true)}>
                    Add Item
                  </button>
                  <button
                    type="button"
                    className="btn btn-danger"
                    onClick={() => void handleDeleteSelectedList()}
                    disabled={selectedList.kind === 'wish' && wishLists.length <= 1}
                    title={
                      selectedList.kind === 'wish' && wishLists.length <= 1
                        ? "You can't delete your only wish list"
                        : 'Delete this list'
                    }
                  >
                    Delete List
                  </button>
                </div>
              </div>

              {errorMessage && <p className="error-text">{errorMessage}</p>}

              {isLoadingItems ? (
                <div className="empty-state">
                  <span className="empty-icon">🛒</span>
                  <p>Loading items…</p>
                </div>
              ) : (
                <ItemsTable
                  title={detailTitle}
                  items={activeItems}
                  purchasedItems={purchasedItems}
                  showUrlColumn={selectedList.kind === 'wish'}
                  allowHideToggle={true}
                  allowRename={selectedList.kind === 'wish'}
                  onRename={selectedList.kind === 'wish' ? handleRenameWishList : undefined}
                  onSave={handleSaveItem}
                  onTogglePurchased={handleTogglePurchased}
                  onToggleHidden={handleToggleHidden}
                  onDelete={handleDeleteItem}
                  onMove={handleMoveItem}
                />
              )}
            </>
          )}
        </main>
      </div>

      {showAddItemModal && <AddItemModal onClose={() => setShowAddItemModal(false)} onSubmit={handleAddItem} />}

      {showCreateWishListModal && (
        <CreateWishListModal onClose={() => setShowCreateWishListModal(false)} onSubmit={handleCreateWishList} />
      )}

      {showCreateCollaborativeListModal && (
        <CreateCollaborativeListModal
          partners={partners}
          isLoadingPartners={isLoadingPartners}
          partnerLoadError={partnerLoadError}
          onClose={() => setShowCreateCollaborativeListModal(false)}
          onSubmit={handleCreateCollaborativeList}
        />
      )}

      {showProfileModal && <ProfileModal onClose={() => setShowProfileModal(false)} />}
    </div>
  )
}
