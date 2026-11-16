import { useCallback } from 'react'
import type { LucideIcon } from 'lucide-react'
import type { ReactNode } from 'react'
import { useNavigate } from 'react-router-dom'
import { useEscapeToDismiss } from '../hooks/useEscapeToDismiss'

export interface AdminFeatureHeaderProps {
  icon: LucideIcon
  title: string
  description: string
  actions?: ReactNode
  /** When set, Escape returns to this route. No visible back link. */
  backTo?: string
  /** @deprecated Visible back link removed; kept for call-site compatibility. */
  backLabel?: string
}

/**
 * Unified colored feature header for Admin Web pages.
 * Gradient and typography stay fixed; only icon, title, description, and actions vary.
 */
export function AdminFeatureHeader({
  icon: Icon,
  title,
  description,
  actions,
  backTo,
}: AdminFeatureHeaderProps) {
  const navigate = useNavigate()
  const goBack = useCallback(() => {
    if (backTo) navigate(backTo)
  }, [backTo, navigate])

  useEscapeToDismiss(Boolean(backTo), goBack, { skipWhenModalOpen: true })

  return (
    <header className="admin-feature-header w-full min-w-0">
      <div
        className={[
          'flex min-h-[92px] flex-col gap-3 rounded-[17px] border px-4 py-3.5 sm:min-h-[98px] sm:flex-row sm:items-center sm:justify-between sm:gap-4 sm:px-5 sm:py-4',
          'border-[#BDEAF6]',
          'bg-[linear-gradient(105deg,#D8F7FF_0%,#EAF5FF_48%,#F6FBFF_100%)]',
          'shadow-[0_1px_3px_rgba(16,45,74,0.06)]',
        ].join(' ')}
      >
        <div className="flex min-w-0 flex-1 items-start gap-3 sm:items-center sm:gap-3.5">
          <span
            className="flex h-11 w-11 shrink-0 items-center justify-center rounded-[12px] border border-[#BDEAF6]/80 bg-white/70 text-[#1A8FB8] shadow-sm sm:h-12 sm:w-12"
            aria-hidden
          >
            <Icon size={28} strokeWidth={2.1} />
          </span>
          <div className="min-w-0 pt-0.5 sm:pt-0">
            <h1 className="truncate text-[1.2rem] font-extrabold leading-tight tracking-tight text-[#102D4A] sm:text-[1.35rem]">
              {title}
            </h1>
            <p className="mt-1 max-w-3xl text-[13px] leading-snug text-[#4B6C83] sm:text-sm sm:leading-relaxed">
              {description}
            </p>
          </div>
        </div>
        {actions ? (
          <div className="flex w-full shrink-0 flex-wrap items-center gap-2 sm:w-auto sm:justify-end">
            {actions}
          </div>
        ) : null}
      </div>
    </header>
  )
}
