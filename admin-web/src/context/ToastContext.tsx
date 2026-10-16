import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from 'react'
import { AlertCircle, CheckCircle2, Info, X } from 'lucide-react'

export type ToastTone = 'success' | 'error' | 'info'

interface ToastItem {
  id: number
  message: string
  tone: ToastTone
}

interface ToastContextValue {
  showToast: (message: string, tone?: ToastTone | boolean) => void
}

const ToastContext = createContext<ToastContextValue | null>(null)

const TONE_CLASS: Record<ToastTone, string> = {
  success: 'admin-alert admin-alert--success',
  error: 'admin-alert admin-alert--error',
  info: 'admin-alert border-[var(--color-border)] bg-[var(--color-surface-elevated)] text-[var(--color-text-primary)]',
}

function resolveTone(tone?: ToastTone | boolean): ToastTone {
  if (tone === true) return 'error'
  if (tone === false || tone == null) return 'success'
  return tone
}

function durationForTone(tone: ToastTone): number {
  if (tone === 'error') return 4200
  if (tone === 'info') return 4000
  return 3500
}

export function ToastProvider({ children }: { children: ReactNode }) {
  const [toast, setToast] = useState<ToastItem | null>(null)
  const timerRef = useRef<number | null>(null)
  const idRef = useRef(0)

  const showToast = useCallback((message: string, tone: ToastTone | boolean = 'success') => {
    const resolved = resolveTone(tone)
    if (timerRef.current) window.clearTimeout(timerRef.current)
    idRef.current += 1
    const id = idRef.current
    setToast({ id, message, tone: resolved })
    timerRef.current = window.setTimeout(() => {
      setToast((current) => (current?.id === id ? null : current))
    }, durationForTone(resolved))
  }, [])

  useEffect(() => {
    return () => {
      if (timerRef.current) window.clearTimeout(timerRef.current)
    }
  }, [])

  const value = useMemo(() => ({ showToast }), [showToast])

  return (
    <ToastContext.Provider value={value}>
      {children}
      {toast ? (
        <div
          role={toast.tone === 'error' ? 'alert' : 'status'}
          aria-live="polite"
          className={`fixed bottom-6 right-6 z-[80] flex max-w-sm items-start gap-2.5 rounded-xl border px-4 py-2.5 text-sm font-semibold shadow-lg ${TONE_CLASS[toast.tone]}`}
        >
          {toast.tone === 'success' ? (
            <CheckCircle2 size={18} className="mt-0.5 shrink-0 text-[var(--color-success)]" />
          ) : toast.tone === 'error' ? (
            <AlertCircle size={18} className="mt-0.5 shrink-0 text-[var(--color-danger)]" />
          ) : (
            <Info size={18} className="mt-0.5 shrink-0 text-[var(--color-accent-blue)]" />
          )}
          <span className="min-w-0 flex-1 leading-snug">{toast.message}</span>
          <button
            type="button"
            aria-label="Dismiss"
            onClick={() => setToast(null)}
            className="shrink-0 rounded p-0.5 opacity-70 hover:opacity-100"
          >
            <X size={14} />
          </button>
        </div>
      ) : null}
    </ToastContext.Provider>
  )
}

export function useToast() {
  const ctx = useContext(ToastContext)
  if (!ctx) {
    throw new Error('useToast must be used within ToastProvider')
  }
  return ctx
}
