import { useEffect, useState, type FormEvent } from 'react'
import { Loader2, X } from 'lucide-react'
import { completePhoneVerification, sendPhoneVerificationOtp } from '../api/auth'

interface Props {
  open: boolean
  onClose: () => void
}

export function PhoneVerifyDialog({ open, onClose }: Props) {
  const [phone, setPhone] = useState('')
  const [code, setCode] = useState('')
  const [step, setStep] = useState<0 | 1 | 2>(0)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [message, setMessage] = useState<string | null>(null)
  const [resendSeconds, setResendSeconds] = useState(0)

  useEffect(() => {
    if (open) {
      setPhone('')
      setCode('')
      setStep(0)
      setError(null)
      setMessage(null)
      setLoading(false)
      setResendSeconds(0)
    }
  }, [open])

  useEffect(() => {
    if (resendSeconds <= 0) return
    const t = window.setTimeout(() => setResendSeconds((s) => Math.max(0, s - 1)), 1000)
    return () => window.clearTimeout(t)
  }, [resendSeconds])

  if (!open) return null

  function handleClose() {
    onClose()
  }

  async function sendCode() {
    setError(null)
    if (phone.trim().length < 10) {
      setError('Enter a Philippine mobile number (09XX…).')
      return
    }
    setLoading(true)
    try {
      const result = await sendPhoneVerificationOtp(phone)
      setPhone(result.phone || phone)
      setMessage(result.message)
      if (result.dev_code) {
        setCode(result.dev_code)
        setMessage(`Dev code: ${result.dev_code} (SMS_PROVIDER=log).`)
      }
      setResendSeconds(result.resend_after_seconds ?? 60)
      setStep(1)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not send code.')
    } finally {
      setLoading(false)
    }
  }

  async function handleSubmit(e: FormEvent) {
    e.preventDefault()
    setError(null)
    if (step === 0) {
      await sendCode()
      return
    }
    if (code.trim().length !== 6) {
      setError('Enter the 6-digit SMS code.')
      return
    }
    setLoading(true)
    try {
      const done = await completePhoneVerification({ phone, code })
      setMessage(done.message)
      setStep(2)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not verify number.')
    } finally {
      setLoading(false)
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
              Verify mobile for SMS recovery
            </h2>
            <p className="mt-1 text-sm text-[var(--color-text-secondary)]">
              Admins must verify a Philippine mobile number before SMS password reset works.
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
            <label htmlFor="verify-phone" className="mb-1.5 block text-xs font-bold text-[var(--color-text-secondary)]">
              Mobile number
            </label>
            <input
              id="verify-phone"
              type="tel"
              readOnly={step >= 1}
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
              className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-muted)] px-4 py-3 text-sm outline-none focus:border-[var(--color-accent-cyan)] focus:ring-2 focus:ring-cyan-100 read-only:opacity-80"
              placeholder="09XX XXX XXXX"
            />
          </div>

          {step === 1 ? (
            <div>
              <label htmlFor="verify-code" className="mb-1.5 block text-xs font-bold text-[var(--color-text-secondary)]">
                6-digit code
              </label>
              <input
                id="verify-code"
                inputMode="numeric"
                maxLength={6}
                value={code}
                onChange={(e) => setCode(e.target.value.replace(/\D/g, '').slice(0, 6))}
                className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-muted)] px-4 py-3 text-sm tracking-widest outline-none focus:border-[var(--color-accent-cyan)] focus:ring-2 focus:ring-cyan-100"
              />
              <button
                type="button"
                disabled={loading || resendSeconds > 0}
                onClick={() => void sendCode()}
                className="mt-2 text-xs font-semibold text-[var(--color-accent-blue)] disabled:opacity-50"
              >
                {resendSeconds > 0 ? `Resend code in ${resendSeconds}s` : 'Resend code'}
              </button>
            </div>
          ) : null}

          {message && !error ? (
            <div className="rounded-xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-900">
              {message}
            </div>
          ) : null}
          {error ? (
            <div className="rounded-xl border border-red-500/30 bg-red-500/10 px-4 py-3 text-sm text-red-300">
              {error}
            </div>
          ) : null}

          <div className="flex gap-2 pt-1">
            <button
              type="button"
              onClick={handleClose}
              disabled={loading}
              className="flex-1 rounded-xl border border-[var(--color-border)] py-2.5 text-sm font-semibold text-[var(--color-text-secondary)] disabled:opacity-50"
            >
              {step === 2 ? 'Done' : 'Cancel'}
            </button>
            {step < 2 ? (
              <button
                type="submit"
                disabled={loading}
                className="flex flex-1 items-center justify-center gap-2 rounded-xl bg-[var(--color-accent-blue)] py-2.5 text-sm font-bold text-white disabled:opacity-60"
              >
                {loading && <Loader2 size={16} className="animate-spin" />}
                {step === 0 ? 'Send code' : 'Verify'}
              </button>
            ) : null}
          </div>
        </form>
      </div>
    </>
  )
}
