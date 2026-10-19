import { useEffect, useRef, type ReactNode, type RefObject } from 'react'
import { lockMainScroll, unlockMainScroll } from '../lib/mainScrollLock'
import { DrawerBackButton } from './AdminBackButton'

const MAX_WIDTH_CLASS = {
  md: 'max-w-md',
  lg: 'max-w-lg',
  xl: 'max-w-xl',
  '2xl': 'max-w-2xl',
  '3xl': 'max-w-3xl',
} as const

type MaxWidth = keyof typeof MAX_WIDTH_CLASS

function useDrawerA11y(
  panelRef: RefObject<HTMLElement | null>,
  open: boolean,
  onClose: () => void,
) {
  useEffect(() => {
    if (!open || !panelRef.current) return

    const root = panelRef.current
    const previouslyFocused = document.activeElement as HTMLElement | null

    function focusables(): HTMLElement[] {
      return Array.from(
        root.querySelectorAll<HTMLElement>(
          'a[href], button:not([disabled]), textarea:not([disabled]), input:not([disabled]), select:not([disabled]), [tabindex]:not([tabindex="-1"])',
        ),
      ).filter((el) => el.offsetParent !== null)
    }

    const first = focusables()[0]
    first?.focus()

    function onKeyDown(e: KeyboardEvent) {
      if (e.key === 'Escape') {
        e.preventDefault()
        onClose()
        return
      }
      if (e.key !== 'Tab') return

      const els = focusables()
      if (els.length === 0) return

      const firstEl = els[0]
      const lastEl = els[els.length - 1]
      if (e.shiftKey && document.activeElement === firstEl) {
        e.preventDefault()
        lastEl.focus()
      } else if (!e.shiftKey && document.activeElement === lastEl) {
        e.preventDefault()
        firstEl.focus()
      }
    }

    root.addEventListener('keydown', onKeyDown)
    return () => {
      root.removeEventListener('keydown', onKeyDown)
      previouslyFocused?.focus()
    }
  }, [open, onClose, panelRef])
}

interface Props {
  open: boolean
  onClose: () => void
  title: string
  subtitle?: ReactNode
  ariaLabel?: string
  maxWidth?: MaxWidth
  /** When set, replaces the default header row (back + title). */
  header?: ReactNode
  bodyClassName?: string
  children: ReactNode
  footer?: ReactNode
}

/** Centered floating panel with backdrop, Escape, and focus trap. */
export function AdminDrawer({
  open,
  onClose,
  title,
  subtitle,
  ariaLabel,
  maxWidth = 'md',
  header,
  bodyClassName = '',
  children,
  footer,
}: Props) {
  const panelRef = useRef<HTMLElement>(null)
  useDrawerA11y(panelRef, open, onClose)

  useEffect(() => {
    if (!open) return
    lockMainScroll()
    return () => {
      unlockMainScroll()
    }
  }, [open])

  if (!open) return null

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4 sm:p-6"
      aria-hidden={false}
    >
      <button
        type="button"
        aria-label="Close panel"
        className="absolute inset-0 bg-black/30 backdrop-blur-[2px]"
        onClick={onClose}
      />
      <aside
        ref={panelRef}
        role="dialog"
        aria-modal="true"
        aria-label={ariaLabel ?? title}
        className={`relative flex h-auto max-h-[min(90vh,calc(100dvh-2rem))] w-full ${MAX_WIDTH_CLASS[maxWidth]} flex-col overflow-hidden rounded-2xl border border-[var(--color-border)] bg-[var(--color-surface)] shadow-2xl ring-1 ring-black/5`}
      >
        {header ?? (
          <div className="flex shrink-0 items-center gap-2 border-b border-[var(--color-border)] px-5 py-4">
            <DrawerBackButton onClick={onClose} label="Back" />
            <div className="min-w-0 flex-1">
              <h2
                id="admin-drawer-title"
                className="text-base font-extrabold text-[var(--color-text-primary)]"
              >
                {title}
              </h2>
              {subtitle ? (
                <div className="mt-0.5 text-xs text-[var(--color-text-secondary)]">{subtitle}</div>
              ) : null}
            </div>
          </div>
        )}

        <div className={`min-h-0 flex-1 overflow-y-auto overscroll-contain ${bodyClassName}`.trim()}>
          {children}
        </div>
        {footer ? (
          <div className="shrink-0 border-t border-[var(--color-border)] bg-[var(--color-surface)]">
            {footer}
          </div>
        ) : null}
      </aside>
    </div>
  )
}
