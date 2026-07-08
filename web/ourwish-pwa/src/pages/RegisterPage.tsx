import { useState } from 'react'
import type { FormEvent } from 'react'
import { useAuth } from '../auth/AuthContext'
import { ApiError } from '../api/client'

const MAX_USERS = 2

// Mirrors macos/OurWish/OurWish/Views/Auth/RegisterView.swift — only reachable from
// the main shell's "Create New User" action (i.e. while already logged in). The
// server enforces this with a required bearer token, not just this page's routing.
export function RegisterPage({ onDone }: { onDone: () => void }) {
  const { register } = useAuth()
  const [firstName, setFirstName] = useState('')
  const [lastName, setLastName] = useState('')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [errorMessage, setErrorMessage] = useState<string | null>(null)
  const [successMessage, setSuccessMessage] = useState<string | null>(null)
  const [isSubmitting, setIsSubmitting] = useState(false)

  const isValid = firstName.trim() && lastName.trim() && email.trim() && password

  const handleSubmit = async (event: FormEvent) => {
    event.preventDefault()
    setIsSubmitting(true)
    setErrorMessage(null)
    try {
      await register(firstName, lastName, email, password)
      setSuccessMessage('User created successfully!')
      setTimeout(onDone, 1200)
    } catch (error) {
      setErrorMessage(error instanceof ApiError ? error.message : 'Registration failed')
    } finally {
      setIsSubmitting(false)
    }
  }

  return (
    <div className="auth-screen">
      <div className="auth-card">
        <div className="brand-glyph">🎁</div>
        <div className="auth-title">
          <h1>Create New User</h1>
          <p>OurWish supports up to {MAX_USERS} people</p>
        </div>

        {errorMessage && <p className="error-text">{errorMessage}</p>}
        {successMessage && <p className="success-text">{successMessage}</p>}

        <form onSubmit={handleSubmit}>
          <div className="name-row">
            <div className="field">
              <label htmlFor="firstName">First Name</label>
              <input
                id="firstName"
                value={firstName}
                onChange={(event) => setFirstName(event.target.value)}
                required
              />
            </div>
            <div className="field">
              <label htmlFor="lastName">Last Name</label>
              <input
                id="lastName"
                value={lastName}
                onChange={(event) => setLastName(event.target.value)}
                required
              />
            </div>
          </div>
          <div className="field">
            <label htmlFor="regEmail">Email</label>
            <input
              id="regEmail"
              type="email"
              autoComplete="username"
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              required
            />
          </div>
          <div className="field">
            <label htmlFor="regPassword">Password</label>
            <input
              id="regPassword"
              type="password"
              autoComplete="new-password"
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              required
            />
          </div>
          <button type="submit" className="btn btn-primary" disabled={isSubmitting || !isValid}>
            {isSubmitting ? 'Creating…' : 'Create User'}
          </button>
        </form>

        <button type="button" className="btn-link" onClick={onDone}>
          Back
        </button>
      </div>
    </div>
  )
}
