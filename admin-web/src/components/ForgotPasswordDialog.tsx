import { useEffect, useState, type FormEvent } from 'react'
import { Loader2, X } from 'lucide-react'
import { completeForgotPasswordReset, sendForgotPasswordOtp } from '../api/auth'

interface Props {
  open: boolean
  initialEmail?: string
  onClose: () => void
}

export function ForgotPasswordDialog({ open, initialEmail = '', onClose }: Props) {
  const [email, setEmail] = useState(initialEmail)
  const [step, setStep] = useState<0 | 1 | 2>(0)
  const [code, setCode] = useState('')
  const [newPassword, setNewPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [message, setMessage] = useState<string | null>(null)

  useEffect(() => {
    if (open) {
      setEmail(initialEmail)
      setStep(0)
      setCode('')
      setNewPassword('')
      setConfirmPassword('')
      setError(null)
      setMessage(null)
      setLoading(false)
    }
  }, [open, initialEmail])

  if (!open) return null

  function resetState() {
    setError(null)
    setMessage(null)
    setLoading(false)
    setStep(0)
    setCode('')
    setNewPassword('')
    setConfirmPassword('')
  }

  function handleClose() {
    resetState()
    onClose()
  }

  async function handleSubmit(e: FormEvent) {
    e.preventDefault()
    setError(null)
    if (!email.trim()) {
      setError('Enter the email address for your account.')
      return
    }
    setLoading(true)
    try {
      if (step === 0) {
        const result = await sendForgotPasswordOtp(email)
        setMessage(result.message)
        if (result.dev_code) {
          setCode(result.dev_code)
          setMessage(
            `Dev code: ${result.dev_code} (also printed in the backend terminal).`,
          )
        }
        setStep(1)
        return
      }
      if (code.trim().length !== 6) {
        setError('Enter the 6-digit code from your email.')
        return
      }
      if (newPassword.length < 6) {
        setError('Password must be at least 6 characters.')
        return
      }
      if (newPassword !== confirmPassword) {
        setError('Passwords do not match.')
        return
      }
      const done = await completeForgotPasswordReset({
        email,
        code,
        newPassword,
      })
      setMessage(done.message)
      setStep(2)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not process request.')
    } finally {
      setLoading(false)
    }
  }

  const doneReset = step === 2

  return (
    <>
      <button
        type="button"
        aria-label="Close dialog"
        className="fixed inset-0 z-[60] bg-black/40"
        onClick={loading ? undefined : handleClose}
      />
      <div
        role="dialog"
        aria-modal="true"
        className="fixed left-1/2 top-1/2 z-[70] w-full max-w-md -translate-x-1/2 -translate-y-1/2 overflow-hidden rounded-2xl border border-[var(--color-border)] bg-[var(--color-surface)] shadow-xl"
      >
        <div className="flex items-start justify-between border-b border-[var(--color-border)] px-5 py-4">
          <div>
            <h2 className="text-base font-extrabold text-[var(--color-text-primary)]">
              Reset password
            </h2>
            <p className="mt-1 text-sm text-[var(--color-text-secondary)]">
              {step === 0
                ? 'We email a 6-digit code to your account address.'
                : 'Enter the code and your new password.'}
            </p>
          </div>
          <button
            type="button"
            onClick={handleClose}
            disabled={loading}
            className="rounded-lg p-1 text-[var(--color-text-muted)] hover:bg-[var(--color-surface-hover)] disabled:opacity-50"
          >
            <X size={18} />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4 px-5 py-4">
          <div>
            <label htmlFor="forgot-email" className="mb-1.5 block text-xs font-bold text-[var(--color-text-secondary)]">
              Email
            </label>
            <input
              id="forgot-email"
              type="email"
              autoComplete="email"
              readOnly={step === 1}
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-muted)] px-4 py-3 text-sm outline-none focus:border-[var(--color-accent-cyan)] focus:ring-2 focus:ring-cyan-100 read-only:opacity-80"
              placeholder="you@example.com"
            />
          </div>

          {step === 1 ? (
            <>
              <div>
                <label htmlFor="forgot-code" className="mb-1.5 block text-xs font-bold text-[var(--color-text-secondary)]">
                  6-digit code
                </label>
                <input
                  id="forgot-code"
                  inputMode="numeric"
                  maxLength={6}
                  value={code}
                  onChange={(e) => setCode(e.target.value.replace(/\D/g, '').slice(0, 6))}
                  className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-muted)] px-4 py-3 text-sm tracking-widest outline-none focus:border-[var(--color-accent-cyan)] focus:ring-2 focus:ring-cyan-100"
                  placeholder="000000"
                />
              </div>
              <div>
                <label htmlFor="forgot-new-pass" className="mb-1.5 block text-xs font-bold text-[var(--color-text-secondary)]">
                  New password
                </label>
                <input
                  id="forgot-new-pass"
                  type="password"
                  autoComplete="new-password"
                  value={newPassword}
                  onChange={(e) => setNewPassword(e.target.value)}
                  className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-muted)] px-4 py-3 text-sm outline-none focus:border-[var(--color-accent-cyan)] focus:ring-2 focus:ring-cyan-100"
                />
              </div>
              <div>
                <label htmlFor="forgot-confirm-pass" className="mb-1.5 block text-xs font-bold text-[var(--color-text-secondary)]">
                  Confirm password
                </label>
                <input
                  id="forgot-confirm-pass"
                  type="password"
                  autoComplete="new-password"
                  value={confirmPassword}
                  onChange={(e) => setConfirmPassword(e.target.value)}
                  className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-muted)] px-4 py-3 text-sm outline-none focus:border-[var(--color-accent-cyan)] focus:ring-2 focus:ring-cyan-100"
                />
              </div>
            </>
          ) : null}

          {message && !error ? (
            <div
              className={`rounded-xl border px-4 py-3 text-sm ${
                doneReset
                  ? 'border-emerald-200 bg-emerald-50 text-emerald-900'
                  : 'border-[var(--color-border)] bg-[var(--color-surface-muted)] text-[var(--color-text-secondary)]'
              }`}
            >
              {message}
            </div>
          ) : null}

          {error ? (
            <div className="rounded-xl border border-red-500/30 bg-red-500/10 px-4 py-3 text-sm text-red-300">
              {error}
            </div>
          ) : null}

          <div className="flex gap-2 pt-1">
            {step === 1 ? (
              <button
                type="button"
                onClick={() => {
                  setStep(0)
                  setError(null)
                }}
                disabled={loading}
                className="rounded-xl border border-[var(--color-border)] px-4 py-2.5 text-sm font-semibold text-[var(--color-text-secondary)] disabled:opacity-50"
              >
                Back
              </button>
            ) : null}
            <button
              type="button"
              onClick={handleClose}
              disabled={loading}
              className="flex-1 rounded-xl border border-[var(--color-border)] py-2.5 text-sm font-semibold text-[var(--color-text-secondary)] disabled:opacity-50"
            >
              {doneReset ? 'Done' : 'Cancel'}
            </button>
            {!doneReset ? (
              <button
                type="submit"
                disabled={loading}
                className="flex flex-1 items-center justify-center gap-2 rounded-xl bg-[var(--color-accent-blue)] py-2.5 text-sm font-bold text-white disabled:opacity-60"
              >
                {loading && <Loader2 size={16} className="animate-spin" />}
                {step === 0 ? 'Send code' : 'Update password'}
              </button>
            ) : null}
          </div>
        </form>
      </div>
    </>
  )
}
