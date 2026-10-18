import { useState, type FormEvent } from 'react'
import { Loader2, Lock, Mail } from 'lucide-react'
import { useBranding } from '../context/BrandingContext'
import { AccessOrgSealLogo } from './AccessOrgSealLogo'
import { ForgotPasswordDialog } from './ForgotPasswordDialog'
import { PasswordInput } from './PasswordInput'

function loginTitleLines(appName: string) {
  const title = appName.startsWith('ACCESS') ? 'ACCESS' : appName.split(' ')[0] ?? 'ACCESS'
  const subtitle = appName.includes('VisionCheck')
    ? 'VisionCheck'
    : appName.replace(title, '').trim() || 'VisionCheck'
  return { title, subtitle }
}

interface LoginFormPanelProps {
  email: string
  password: string
  rememberMe: boolean
  error: string | null
  loading: boolean
  mobile?: boolean
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
  mobile = false,
  onEmailChange,
  onPasswordChange,
  onRememberMeChange,
  onSubmit,
}: LoginFormPanelProps) {
  const [forgotOpen, setForgotOpen] = useState(false)
  const { appName } = useBranding()
  const { title, subtitle } = loginTitleLines(appName)
  const sealSize = mobile ? 68 : 80

  return (
    <section
      className={['login-card', mobile ? 'login-card--mobile' : ''].filter(Boolean).join(' ')}
      aria-labelledby="login-heading"
    >
      <div className="login-card__brand">
        <AccessOrgSealLogo size={sealSize} showShadow={false} className="login-card__seal" />
        <div className="login-card__wordmark">
          <span className="login-card__access">{title}</span>
          <span className="login-card__vision">{subtitle}</span>
        </div>
      </div>

      <h1 id="login-heading" className="login-card__title">
        Sign in
      </h1>
      <p className="login-card__subtitle">Continue to your administrator account</p>

      <form onSubmit={onSubmit} className="login-card__form">
        <div className="login-input-wrap">
          <Mail size={18} strokeWidth={2} className="login-input-icon" aria-hidden />
          <input
            id="email"
            type="email"
            autoComplete="email"
            value={email}
            onChange={(e) => onEmailChange(e.target.value)}
            className="login-input"
            placeholder="Email Address"
          />
        </div>

        <div className="login-input-wrap">
          <Lock size={18} strokeWidth={2} className="login-input-icon" aria-hidden />
          <PasswordInput
            id="password"
            value={password}
            onChange={onPasswordChange}
            autoComplete="current-password"
            placeholder="Password"
            className="login-password-light"
          />
        </div>

        <div className="login-card__meta">
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
          {loading && <Loader2 size={18} className="animate-spin" />}
          Sign in
        </button>
      </form>

      <p className="login-card__legal">© 2026 ACCESS VisionCheck · USTP Oroquieta Campus</p>

      <ForgotPasswordDialog
        open={forgotOpen}
        initialEmail={email}
        onClose={() => setForgotOpen(false)}
      />
    </section>
  )
}
