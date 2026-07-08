import { createContext, useCallback, useContext, useEffect, useState } from 'react'
import type { ReactNode } from 'react'
import { api, getToken, setToken } from '../api/client'
import type { User } from '../api/types'

interface AuthContextValue {
  currentUser: User | null
  isLoading: boolean
  login: (email: string, password: string) => Promise<void>
  logout: () => void
  register: (firstName: string, lastName: string, email: string, password: string) => Promise<void>
  refreshCurrentUser: () => Promise<void>
  setCurrentUser: (user: User) => void
}

const AuthContext = createContext<AuthContextValue | undefined>(undefined)

// Mirrors macos/OurWish/OurWishCore/Sources/OurWishCore/Stores/AuthStore.swift, but
// backed by the HTTP API instead of a direct GRDB connection — same shape of state
// (currentUser, login/logout/register), different transport.
export function AuthProvider({ children }: { children: ReactNode }) {
  const [currentUser, setCurrentUserState] = useState<User | null>(null)
  const [isLoading, setIsLoading] = useState(true)

  useEffect(() => {
    const token = getToken()
    if (!token) {
      setIsLoading(false)
      return
    }
    api
      .me()
      .then(setCurrentUserState)
      .catch(() => setToken(null))
      .finally(() => setIsLoading(false))
  }, [])

  const login = useCallback(async (email: string, password: string) => {
    const response = await api.login(email, password)
    setToken(response.token)
    setCurrentUserState(response.user)
  }, [])

  const logout = useCallback(() => {
    setToken(null)
    setCurrentUserState(null)
  }, [])

  // Only reachable while already logged in (see RegisterPage) — the server enforces
  // this too (requires a valid bearer token), since this endpoint is reachable by
  // anything on the LAN, not just this app's UI.
  const register = useCallback(
    async (firstName: string, lastName: string, email: string, password: string) => {
      await api.register(firstName, lastName, email, password)
    },
    [],
  )

  const refreshCurrentUser = useCallback(async () => {
    const user = await api.me()
    setCurrentUserState(user)
  }, [])

  return (
    <AuthContext.Provider
      value={{
        currentUser,
        isLoading,
        login,
        logout,
        register,
        refreshCurrentUser,
        setCurrentUser: setCurrentUserState,
      }}
    >
      {children}
    </AuthContext.Provider>
  )
}

// oxlint-disable-next-line react/only-export-components
export function useAuth(): AuthContextValue {
  const context = useContext(AuthContext)
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider')
  }
  return context
}
