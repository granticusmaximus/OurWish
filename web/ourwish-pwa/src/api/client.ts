import type {
  ApiErrorBody,
  CollaborativeList,
  Item,
  ItemsResponse,
  LoginResponse,
  Partner,
  User,
  WishList,
} from './types'
import { buildAPIURL, resolveAPIAssetURL } from './config'

const TOKEN_KEY = 'ourwish_token'

export function getToken(): string | null {
  return localStorage.getItem(TOKEN_KEY)
}

export function setToken(token: string | null): void {
  if (token) {
    localStorage.setItem(TOKEN_KEY, token)
  } else {
    localStorage.removeItem(TOKEN_KEY)
  }
}

export class ApiError extends Error {
  status: number

  constructor(status: number, message: string) {
    super(message)
    this.status = status
  }
}

async function request<T>(path: string, options: RequestInit = {}): Promise<T> {
  const token = getToken()
  const headers = new Headers(options.headers)
  headers.set('Content-Type', 'application/json')
  if (token) {
    headers.set('Authorization', `Bearer ${token}`)
  }

  const response = await fetch(buildAPIURL(path), { ...options, headers })

  if (!response.ok) {
    let message = `Request failed (${response.status})`
    try {
      const body = (await response.json()) as ApiErrorBody
      message = body.error?.message ?? message
    } catch {
      // Response body wasn't JSON — keep the generic message.
    }
    throw new ApiError(response.status, message)
  }

  if (response.status === 204) {
    return undefined as T
  }

  return (await response.json()) as T
}

interface ItemInput {
  productName: string
  price: number
  quantity: number
  url: string | null
}

interface UpdateProfileInput {
  firstName: string
  lastName: string
  displayName: string
  bio: string | null
  imageBase64: string | null
}

function withResolvedUserImage(user: User): User {
  return {
    ...user,
    imageURL: resolveAPIAssetURL(user.imageURL),
  }
}

function withResolvedItemImage(item: Item): Item {
  return {
    ...item,
    imageURL: resolveAPIAssetURL(item.imageURL),
  }
}

function withResolvedItemsResponse(response: ItemsResponse): ItemsResponse {
  return {
    active: response.active.map(withResolvedItemImage),
    purchased: response.purchased.map(withResolvedItemImage),
  }
}

export const api = {
  login: (email: string, password: string) =>
    request<LoginResponse>('/api/v1/auth/login', {
      method: 'POST',
      body: JSON.stringify({ email, password }),
    }).then((response) => ({
      ...response,
      user: withResolvedUserImage(response.user),
    })),
  logout: () => request<void>('/api/v1/auth/logout', { method: 'POST' }),
  me: () => request<User>('/api/v1/auth/me').then(withResolvedUserImage),
  register: (firstName: string, lastName: string, email: string, password: string) =>
    request<User>('/api/v1/auth/register', {
      method: 'POST',
      body: JSON.stringify({ firstName, lastName, email, password }),
    }).then(withResolvedUserImage),
  updateProfile: (input: UpdateProfileInput) =>
    request<User>('/api/v1/auth/profile', { method: 'PUT', body: JSON.stringify(input) }).then(withResolvedUserImage),
  changePassword: (currentPassword: string, newPassword: string) =>
    request<void>('/api/v1/auth/password', {
      method: 'PUT',
      body: JSON.stringify({ currentPassword, newPassword }),
    }),

  wishLists: () => request<WishList[]>('/api/v1/wishlists'),
  createWishList: (name: string) =>
    request<WishList>('/api/v1/wishlists', { method: 'POST', body: JSON.stringify({ name }) }),
  renameWishList: (id: number, name: string) =>
    request<void>(`/api/v1/wishlists/${id}`, { method: 'PUT', body: JSON.stringify({ name }) }),
  deleteWishList: (id: number) => request<void>(`/api/v1/wishlists/${id}`, { method: 'DELETE' }),
  wishListItems: (id: number) => request<ItemsResponse>(`/api/v1/wishlists/${id}/items`).then(withResolvedItemsResponse),
  addWishListItem: (id: number, input: ItemInput) =>
    request<Item>(`/api/v1/wishlists/${id}/items`, { method: 'POST', body: JSON.stringify(input) }).then(withResolvedItemImage),
  updateItem: (id: number, input: ItemInput) =>
    request<void>(`/api/v1/items/${id}`, { method: 'PUT', body: JSON.stringify(input) }),
  setItemPurchased: (id: number, isPurchased: boolean) =>
    request<void>(`/api/v1/items/${id}/purchase`, { method: 'PUT', body: JSON.stringify({ isPurchased }) }),
  setItemHidden: (id: number, isHidden: boolean) =>
    request<void>(`/api/v1/items/${id}/hidden`, { method: 'PUT', body: JSON.stringify({ isHidden }) }),
  deleteItem: (id: number) => request<void>(`/api/v1/items/${id}`, { method: 'DELETE' }),

  partners: () => request<Partner[]>('/api/v1/collaborative/partners'),
  collaborativeLists: () => request<CollaborativeList[]>('/api/v1/collaborative/lists'),
  createCollaborativeList: (partnerEmail: string, name: string) =>
    request<CollaborativeList>('/api/v1/collaborative/lists', {
      method: 'POST',
      body: JSON.stringify({ partnerEmail, name }),
    }),
  deleteCollaborativeList: (id: number) =>
    request<void>(`/api/v1/collaborative/lists/${id}`, { method: 'DELETE' }),
  collaborativeItems: (listId: number) =>
    request<ItemsResponse>(`/api/v1/collaborative/lists/${listId}/items`).then(withResolvedItemsResponse),
  addCollaborativeItem: (listId: number, input: ItemInput) =>
    request<Item>(`/api/v1/collaborative/lists/${listId}/items`, {
      method: 'POST',
      body: JSON.stringify(input),
    }).then(withResolvedItemImage),
  updateCollaborativeItem: (listId: number, itemId: number, input: ItemInput) =>
    request<void>(`/api/v1/collaborative/lists/${listId}/items/${itemId}`, {
      method: 'PUT',
      body: JSON.stringify(input),
    }),
  setCollaborativeItemPurchased: (listId: number, itemId: number, isPurchased: boolean) =>
    request<void>(`/api/v1/collaborative/lists/${listId}/items/${itemId}/purchase`, {
      method: 'PUT',
      body: JSON.stringify({ isPurchased }),
    }),
  deleteCollaborativeItem: (listId: number, itemId: number) =>
    request<void>(`/api/v1/collaborative/lists/${listId}/items/${itemId}`, { method: 'DELETE' }),
}
