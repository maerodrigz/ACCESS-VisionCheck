import { useEffect, useState, type FormEvent } from 'react'
import { Copy, Loader2, X } from 'lucide-react'
import { requestAdminPasswordReset } from '../api/auth'

interface Props {
  open: boolean
  initialEmail?: string
  onClose: () => void
}

export function ForgotPasswordDialog({ open, initialEmail = '', onClose }: Props) {
  const [email, setEmail] = useState(initialEmail)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [message, setMessage] = useState<string | null>(null)
  const [tempPassword, setTempPassword] = useState<string | null>(null)
  const [copied, setCopied] = useState(false)

  useEffect(() => {
    if (open) {
      setEmail(initialEmail)
      setError(null)
      setMessage(null)
      setTempPassword(null)
      setCopied(false)
      setLoading(false)
    }
  }, [open, initialEmail])

  if (!open) return null

  function resetState() {
    setError(null)
    setMessage(null)
    setTempPassword(null)
    setCopied(false)
    setLoading(false)
  }

  function handleClose() {
    resetState()
    onClose()
  }

  async function handleSubmit(e: FormEvent) {
    e.preventDefault()
    setError(null)
    setMessage(null)
    setTempPassword(null)
    if (!email.trim()) {
      setError('Enter the email address for your administrator account.')
      return
    }
    setLoading(true)
    try {
      const result = await requestAdminPasswordReset(email)
      setMessage(result.message)
      setTempPassword(result.temporary_password ?? null)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not process request.')
    } finally {
      setLoading(false)
    }
  }

  async function copyPassword() {
    if (!tempPassword) return
    try {
      await navigator.clipboard.writeText(tempPassword)
      setCopied(true)
      window.setTimeout(() => setCopied(false), 2000)
    } catch {
      setCopied(false)
    }
  }

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
              Reset administrator password
            </h2>
            <p className="mt-1 text-sm text-[var(--color-text-secondary)]">
              We&apos;ll generate a temporary password for approved admin accounts.
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
          {!tempPassword ? (
            <div>
              <label htmlFor="forgot-email" className="mb-1.5 block text-xs font-bold text-[var(--color-text-secondary)]">
                Admin email
              </label>
              <input
                id="forgot-email"
                type="email"
                autoComplete="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-muted)] px-4 py-3 text-sm outline-none focus:border-[var(--color-accent-cyan)] focus:ring-2 focus:ring-cyan-100"
                placeholder="admin@access.edu"
              />
            </div>
          ) : (
            <div className="rounded-xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-900">
              {message}
            </div>
          )}

          {tempPassword ? (
            <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-muted)] p-4">
              <div className="text-xs font-bold uppercase tracking-wide text-[var(--color-text-secondary)]">
                Temporary password
              </div>
              <div className="mt-2 flex items-center gap-2">
                <code className="flex-1 break-all rounded-lg bg-[var(--color-surface-elevated)] px-3 py-2 text-sm font-semibold text-[var(--color-text-primary)]">
                  {tempPassword}
                </code>
                <button
                  type="button"
                  onClick={copyPassword}
                  className="inline-flex items-center gap-1 rounded-lg border border-[var(--color-border)] bg-[var(--color-surface-elevated)] px-3 py-2 text-xs font-semibold text-[var(--color-text-secondary)] hover:bg-[var(--color-surface-hover)]"
                >
                  <Copy size={14} />
                  {copied ? 'Copied' : 'Copy'}
                </button>
              </div>
              <p className="mt-2 text-xs text-[var(--color-text-secondary)]">
                Use this once to sign in, then change your password from the profile menu (Change password).
              </p>
            </div>
          ) : null}

          {error ? (
            <div className="rounded-xl border border-red-500/30 bg-red-500/10 px-4 py-3 text-sm text-red-300">
              {error}
            </div>
          ) : null}

          {!tempPassword && message && !error ? (
            <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-muted)] px-4 py-3 text-sm text-[var(--color-text-secondary)]">
              {message}
            </div>
          ) : null}

          <div className="flex gap-2 pt-1">
            <button
              type="button"
              onClick={handleClose}
              disabled={loading}
              className="flex-1 rounded-xl border border-[var(--color-border)] py-2.5 text-sm font-semibold text-[var(--color-text-secondary)] disabled:opacity-50"
            >
              {tempPassword ? 'Done' : 'Cancel'}
            </button>
            {!tempPassword ? (
              <button
                type="submit"
                disabled={loading}
                className="flex flex-1 items-center justify-center gap-2 rounded-xl bg-[var(--color-accent-blue)] py-2.5 text-sm font-bold text-white disabled:opacity-60"
              >
                {loading && <Loader2 size={16} className="animate-spin" />}
                Reset password
              </button>
            ) : null}
          </div>
        </form>
      </div>
    </>
  )
}
