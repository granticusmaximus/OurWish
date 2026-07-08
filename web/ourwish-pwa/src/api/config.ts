function trimTrailingSlash(value: string): string {
  return value.replace(/\/+$/, '')
}

const rawApiBaseUrl = import.meta.env.VITE_API_BASE_URL?.trim() ?? ''

// Empty means same-origin production or Vite dev proxy. A non-empty value allows the
// PWA to target a remotely hosted backend without changing call sites.
export const API_BASE_URL = rawApiBaseUrl ? trimTrailingSlash(rawApiBaseUrl) : ''

export function buildAPIURL(path: string): string {
  if (!API_BASE_URL) {
    return path
  }

  if (path.startsWith('/')) {
    return `${API_BASE_URL}${path}`
  }

  return `${API_BASE_URL}/${path}`
}

export function resolveAPIAssetURL(url: string | null): string | null {
  if (!url) {
    return null
  }

  if (/^https?:\/\//i.test(url)) {
    return url
  }

  return buildAPIURL(url)
}
