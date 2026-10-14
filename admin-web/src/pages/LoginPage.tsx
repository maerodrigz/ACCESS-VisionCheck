import { useState, type FormEvent } from 'react'
import { Navigate } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'
import { LoginBrandPanel } from '../components/LoginBrandPanel'
import { LoginFormPanel } from '../components/LoginFormPanel'
import '../styles/login.css'

export function LoginPage() {
  const { user, login, loading, initializing } = useAuth()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState<string | null>(null)

  if (initializing) {
    return (
      <div className="login-page flex min-h-screen items-center justify-center bg-[var(--login-bg)]">
        <div className="text-sm font-medium text-[var(--login-text-secondary)]">Loading…</div>
      </div>
    )
  }

  if (user) return <Navigate to="/" replace />

  async function handleSubmit(e: FormEvent) {
    e.preventDefault()
    setError(null)
    if (!email.trim() || !password) {
      setError('Please fill in all fields.')
      return
    }
    try {
      await login(email, password)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Login failed.')
    }
  }

  const formProps = {
    email,
    password,
    error,
    loading,
    onEmailChange: setEmail,
    onPasswordChange: setPassword,
    onSubmit: handleSubmit,
  }

  return (
    <div className="login-page min-h-screen">
      {/* Desktop — wide hero + narrower sign-in column (~70/30) */}
      <div className="hidden min-h-screen lg:flex">
        <div className="login-brand-column min-w-0 flex-1">
          <LoginBrandPanel />
        </div>
        <div className="login-form-panel login-form-column flex min-h-screen shrink-0">
          <LoginFormPanel {...formProps} />
        </div>
      </div>

      {/* Mobile — dark hero + white sheet overlapping */}
      <div className="flex min-h-screen flex-col lg:hidden">
        <div className="shrink-0" style={{ height: '32vh', minHeight: 220 }}>
          <LoginBrandPanel compact />
        </div>
        <div className="login-sheet login-form-panel relative -mt-[22px] flex min-h-0 flex-1 flex-col">
          <LoginFormPanel {...formProps} sheet />
        </div>
      </div>
    </div>
  )
}
