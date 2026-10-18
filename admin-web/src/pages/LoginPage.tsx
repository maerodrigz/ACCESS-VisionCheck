import { useEffect, useState, type FormEvent } from 'react'
import { Navigate } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'
import { LoginBrandPanel } from '../components/LoginBrandPanel'
import { LoginFormPanel } from '../components/LoginFormPanel'
import loginHeroBackground from '../assets/login-hero-background.jpg'
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
    const prevHtml = document.documentElement.style.overflow
    const prevBody = document.body.style.overflow
    document.documentElement.style.overflow = 'hidden'
    document.body.style.overflow = 'hidden'
    return () => {
      document.documentElement.style.overflow = prevHtml
      document.body.style.overflow = prevBody
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
      <div
        className="login-page__photo"
        aria-hidden
        style={{ backgroundImage: `url(${loginHeroBackground})` }}
      />
      <div className="login-page__art" aria-hidden />
      <div className="login-page__scrim" aria-hidden />

      <div className="login-layout login-layout--desktop">
        <LoginBrandPanel />
        <LoginFormPanel {...formProps} />
      </div>

      <div className="login-layout login-layout--mobile">
        <LoginBrandPanel compact />
        <LoginFormPanel {...formProps} mobile />
      </div>
    </div>
  )
}
