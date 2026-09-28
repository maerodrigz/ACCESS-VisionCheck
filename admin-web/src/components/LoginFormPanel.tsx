import { useState, type FormEvent } from 'react'
import { Loader2, Lock, Mail } from 'lucide-react'
import { ForgotPasswordDialog } from './ForgotPasswordDialog'
import { PasswordInput } from './PasswordInput'

interface LoginFormPanelProps {
  email: string
  password: string
  error: string | null
  loading: boolean
  sheet?: boolean
  onEmailChange: (value: string) => void
  onPasswordChange: (value: string) => void
  onSubmit: (e: FormEvent) => void
}

export function LoginFormPanel({
  email,
  password,
  error,
  loading,
  sheet = false,
  onEmailChange,
  onPasswordChange,
  onSubmit,
}: LoginFormPanelProps) {
  const [forgotOpen, setForgotOpen] = useState(false)

  return (
    <div
      className={[
        'login-form-panel flex h-full flex-col',
        sheet ? 'px-5 pb-4 pt-[18px]' : 'justify-center px-12 py-12 lg:px-16',
      ].join(' ')}
    >
      <div className="mx-auto w-full max-w-[420px]">
        <h1
          className="text-xl font-extrabold tracking-tight text-[var(--login-text)]"
          style={{ lineHeight: 1 }}
        >
          Sign in
        </h1>
        <p className={`text-[var(--login-text-secondary)] ${sheet ? 'mt-1 text-[13px]' : 'mt-1.5 text-sm'}`}>
          Administrator access only
        </p>

        <form onSubmit={onSubmit} className={sheet ? 'mt-3 space-y-2.5' : 'mt-8 space-y-4'}>
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

          <div>
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
            <div className="mt-2 flex justify-end">
              <button
                type="button"
                onClick={() => setForgotOpen(true)}
                className="text-[13px] font-semibold text-[var(--login-secondary)] hover:underline"
              >
                Forgot Password?
              </button>
            </div>
          </div>

          {error && (
            <div className="rounded-2xl border border-red-200 bg-red-50 px-3 py-2.5 text-[13px] text-red-700">
              {error}
            </div>
          )}

          <button type="submit" disabled={loading} className="login-btn-primary mt-1">
            {loading && <Loader2 size={18} className="animate-spin" />}
            Sign In
          </button>
        </form>

        <p className="mt-8 text-center text-[11px] text-[var(--login-text-secondary)]">
          © 2026 ACCESS VisionCheck · USTP Oroquieta Campus
        </p>
      </div>

      <ForgotPasswordDialog
        open={forgotOpen}
        initialEmail={email}
        onClose={() => setForgotOpen(false)}
      />
    </div>
  )
}
