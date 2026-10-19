import { useState, type FormEvent } from 'react'
import { ArrowRight, Loader2, Lock, Mail } from 'lucide-react'
import { APP_SUBTITLE, APP_TITLE } from './AccessBrand'
import { AccessOrgSealLogo } from './AccessOrgSealLogo'
import { ForgotPasswordDialog } from './ForgotPasswordDialog'
import { PasswordInput } from './PasswordInput'

interface LoginFormPanelProps {
  email: string
  password: string
  rememberMe: boolean
  error: string | null
  loading: boolean
  onEmailChange: (value: string) => void
  onPasswordChange: (value: string) => void
  onRememberMeChange: (value: boolean) => void
  onSubmit: (e: FormEvent) => void
}

export function LoginFormPanel({
  email,
  password,
  rememberMe,
  error,
  loading,
  onEmailChange,
  onPasswordChange,
  onRememberMeChange,
  onSubmit,
}: LoginFormPanelProps) {
  const [forgotOpen, setForgotOpen] = useState(false)

  return (
    <div className="login-auth" aria-labelledby="login-heading">
      <div className="login-auth__inner">
        <div className="login-auth__brand">
          <div className="login-auth__lockup">
            <AccessOrgSealLogo size={90} showShadow={false} className="login-auth__seal" />
            <div className="login-auth__wordmark">
              <span className="login-auth__access">{APP_TITLE}</span>
              <span className="login-auth__vision">{APP_SUBTITLE}</span>
            </div>
          </div>
        </div>

        <header className="login-auth__header">
          <h1 id="login-heading" className="login-auth__title">
            Welcome Back!
          </h1>
          <p className="login-auth__subtitle">Sign in to your administrator account</p>
        </header>

        <form onSubmit={onSubmit} className="login-auth__form">
          <div className="login-field">
            <label htmlFor="email" className="login-field__label login-sr-only">
              Email
            </label>
            <div className="login-input-wrap">
              <Mail size={18} strokeWidth={2} className="login-input-icon" aria-hidden />
              <input
                id="email"
                type="email"
                autoComplete="email"
                value={email}
                onChange={(e) => onEmailChange(e.target.value)}
                className="login-input"
                placeholder="admin@access.edu"
              />
            </div>
          </div>

          <div className="login-field">
            <label htmlFor="password" className="login-field__label login-sr-only">
              Password
            </label>
            <div className="login-input-wrap">
              <Lock size={18} strokeWidth={2} className="login-input-icon" aria-hidden />
              <PasswordInput
                id="password"
                value={password}
                onChange={onPasswordChange}
                autoComplete="current-password"
                placeholder="Enter your password"
                className="login-password-light"
              />
            </div>
          </div>

          <div className="login-auth__meta">
            <label className="login-remember">
              <input
                type="checkbox"
                checked={rememberMe}
                onChange={(e) => onRememberMeChange(e.target.checked)}
                className="login-remember__check"
              />
              Remember me
            </label>
            <button type="button" onClick={() => setForgotOpen(true)} className="login-link">
              Forgot password?
            </button>
          </div>

          {error && (
            <div className="login-form__error" role="alert">
              {error}
            </div>
          )}

          <button type="submit" disabled={loading} className="login-btn-primary">
            {loading ? (
              <>
                <Loader2 size={18} className="login-btn-primary__spinner" aria-hidden />
                Signing in…
              </>
            ) : (
              <>
                Sign In
                <ArrowRight size={18} strokeWidth={2.5} aria-hidden />
              </>
            )}
          </button>
        </form>

        <p className="login-auth__legal">© 2026 ACCESS VisionCheck · USTP Oroquieta Campus</p>
      </div>

      <ForgotPasswordDialog
        open={forgotOpen}
        initialEmail={email}
        onClose={() => setForgotOpen(false)}
      />
    </div>
  )
}
