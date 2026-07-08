// Mirrors the DTOs in macos/OurWish/OurWishServer/Sources/OurWishServer/DTOs.swift —
// keep these in sync by hand since the two projects don't share a schema generator.

export interface User {
  id: number
  firstName: string
  lastName: string
  displayName: string
  email: string
  bio: string | null
  imageURL: string | null
}

export interface LoginResponse {
  token: string
  user: User
}

export interface WishList {
  id: number
  name: string
}

export interface Item {
  id: number
  productName: string
  category: string | null
  manufacturer: string | null
  price: number
  msrp: number | null
  quantity: number
  url: string | null
  officialProductURL: string | null
  bestRetailerURL: string | null
  primaryImageURL: string | null
  itemDescription: string | null
  specifications: string | null
  weight: string | null
  caliber: string | null
  compatibility: string | null
  purpose: string | null
  notes: string | null
  availabilityStatus: string | null
  dateRetrieved: string | null
  isPurchased: boolean
  isHidden: boolean
  imageURL: string | null
}

export interface ItemsResponse {
  active: Item[]
  purchased: Item[]
}

export interface CollaborativeList {
  id: number
  name: string
  partnerName: string
}

export interface Partner {
  email: string
  displayName: string
}

export interface ApiErrorBody {
  error: {
    message: string
  }
}
