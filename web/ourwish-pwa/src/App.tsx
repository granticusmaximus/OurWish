import { useState } from 'react'
import './App.css'
import { useAuth } from './auth/AuthContext'
import { LoginPage } from './pages/LoginPage'
import { RegisterPage } from './pages/RegisterPage'
import { MainShell } from './components/MainShell'

// Mirrors macos/OurWish/OurWish/Views/Main/RootView.swift's login/register/main
// branching.
function App() {
  const { currentUser, isLoading } = useAuth()
  const [showRegister, setShowRegister] = useState(false)

  if (isLoading) {
    return (
      <div className="auth-screen">
        <div className="brand-glyph">🎁</div>
      </div>
    )
  }

  if (showRegister) {
    return <RegisterPage onDone={() => setShowRegister(false)} />
  }

  if (!currentUser) {
    return <LoginPage />
  }

  return <MainShell onCreateNewUser={() => setShowRegister(true)} />
}

export default App
