import { AlertCircle, CheckCircle2, Loader2, X } from 'lucide-react'
import { useEffect } from 'react'

export type OperationBannerStatus = 'loading' | 'success' | 'error'

export interface OperationBannerState {
  status: OperationBannerStatus
  message: string
}

const STATUS_CLASS: Record<OperationBannerStatus, string> = {
  loading:
    'border border-[color-mix(in_srgb,var(--color-accent-blue)_35%,transparent)] bg-[color-mix(in_srgb,var(--color-accent-blue)_10%,transparent)] text-[var(--color-text-primary)]',
  success: 'admin-alert admin-alert--success',
  error: 'admin-alert admin-alert--error',
}

interface Props {
  banner: OperationBannerState | null
  onDismiss?: () => void
  autoDismissMs?: number
}

export function AdminOperationBanner({ banner, onDismiss, autoDismissMs = 6000 }: Props) {
  useEffect(() => {
    if (!banner || banner.status === 'loading' || !onDismiss) return
    const timer = window.setTimeout(onDismiss, autoDismissMs)
    return () => window.clearTimeout(timer)
  }, [banner, onDismiss, autoDismissMs])

  if (!banner) return null

  const Icon =
    banner.status === 'loading'
      ? Loader2
      : banner.status === 'success'
        ? CheckCircle2
        : AlertCircle

  return (
    <div
      role={banner.status === 'error' ? 'alert' : 'status'}
      aria-live="polite"
      className={`flex items-start gap-3 rounded-xl border px-4 py-3 text-sm shadow-sm ${STATUS_CLASS[banner.status]}`}
    >
      <Icon
        size={18}
        className={`mt-0.5 shrink-0 ${banner.status === 'loading' ? 'animate-spin text-[var(--color-accent-blue)]' : ''} ${banner.status === 'success' ? 'text-[var(--color-success)]' : ''} ${banner.status === 'error' ? 'text-[var(--color-danger)]' : ''}`}
      />
      <p className="min-w-0 flex-1 font-semibold leading-snug">{banner.message}</p>
      {banner.status !== 'loading' && onDismiss ? (
        <button
          type="button"
          aria-label="Dismiss"
          onClick={onDismiss}
          className="shrink-0 rounded-lg p-1 opacity-70 hover:bg-black/10 hover:opacity-100"
        >
          <X size={16} />
        </button>
      ) : null}
    </div>
  )
}
