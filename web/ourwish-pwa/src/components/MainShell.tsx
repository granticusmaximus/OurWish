import { useAuth } from '../auth/AuthContext'

// Placeholder for Phase 7 verification — replaced with the full sidebar/detail shell
// (mirroring MainWindowView.swift) in Phase 8.
export function MainShell({ onCreateNewUser }: { onCreateNewUser: () => void }) {
  const { currentUser, logout } = useAuth()

  return (
    <div style={{ padding: '2rem' }}>
      <h1>OurWish</h1>
      <p>Logged in as {currentUser?.displayName}</p>
      <button type="button" className="btn" onClick={onCreateNewUser}>
        Create New User
      </button>{' '}
      <button type="button" className="btn" onClick={logout}>
        Log Out
      </button>
    </div>
  )
}
