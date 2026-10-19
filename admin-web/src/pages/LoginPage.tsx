import { useEffect, useState, type FormEvent } from 'react'
import { Navigate } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'
import { LoginBrandPanel } from '../components/LoginBrandPanel'
import { LoginFormPanel } from '../components/LoginFormPanel'
import { LoginSplitCurve } from '../components/LoginSplitCurve'
import loginCameraBg from '../assets/login-camera-bg.png'
import '../styles/login.css'

const REMEMBER_EMAIL_KEY = 'access-admin-login-remember-email'

export function LoginPage() {
  const { user, login, loading, initializing } = useAuth()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [rememberMe, setRememberMe] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    try {
      const saved = localStorage.getItem(REMEMBER_EMAIL_KEY)
      if (saved) {
        setEmail(saved)
        setRememberMe(true)
      }
    } catch {
      /* ignore */
    }
  }, [])

  useEffect(() => {
    document.documentElement.classList.add('access-login-active')
    return () => {
      document.documentElement.classList.remove('access-login-active')
    }
  }, [])

  if (initializing) {
    return (
      <div className="login-page login-page--loading">
        <div className="login-page__spinner" aria-hidden />
        <p className="text-sm font-medium text-slate-500">Loading…</p>
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
      try {
        if (rememberMe) {
          localStorage.setItem(REMEMBER_EMAIL_KEY, email.trim())
        } else {
          localStorage.removeItem(REMEMBER_EMAIL_KEY)
        }
      } catch {
        /* ignore */
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Login failed.')
    }
  }

  const formProps = {
    email,
    password,
    rememberMe,
    error,
    loading,
    onEmailChange: setEmail,
    onPasswordChange: setPassword,
    onRememberMeChange: setRememberMe,
    onSubmit: handleSubmit,
  }

  return (
    <div className="login-page">
      <div className="login-shell">
        <div className="login-shell__hero">
          <div className="login-shell__photo" aria-hidden>
            <div
              className="login-shell__photo-bg"
              style={{ '--login-hero-image': `url(${loginCameraBg})` } as React.CSSProperties}
            />
          </div>
          <div className="login-shell__scrim" aria-hidden />
          <LoginSplitCurve />
          <div className="login-shell__brand">
            <LoginBrandPanel />
          </div>
        </div>
        <main className="login-shell__auth">
          <LoginFormPanel {...formProps} />
        </main>
      </div>
    </div>
  )
}
