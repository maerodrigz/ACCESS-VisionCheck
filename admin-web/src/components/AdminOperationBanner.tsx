import { AlertCircle, CheckCircle2, Loader2, X } from 'lucide-react'
import { useEffect } from 'react'

export type OperationBannerStatus = 'loading' | 'success' | 'error'

export interface OperationBannerState {
  status: OperationBannerStatus
  message: string
}

const STATUS_CLASS: Record<OperationBannerStatus, string> = {
  loading: 'border-[var(--color-accent-blue)]/35 bg-[var(--color-accent-blue)]/10 text-[var(--color-text-primary)]',
  success: 'border-emerald-500/35 bg-emerald-500/10 text-emerald-100',
  error: 'border-red-500/35 bg-red-500/10 text-red-100',
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
        className={`mt-0.5 shrink-0 ${banner.status === 'loading' ? 'animate-spin text-[var(--color-accent-blue)]' : ''} ${banner.status === 'success' ? 'text-emerald-400' : ''} ${banner.status === 'error' ? 'text-red-400' : ''}`}
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
