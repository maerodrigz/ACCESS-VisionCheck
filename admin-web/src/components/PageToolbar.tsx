import { RefreshCw } from 'lucide-react'



/** Pill export/action buttons — matches page header toolbar. */

export const pageToolbarBtnClass =

  'inline-flex items-center gap-2 rounded-full border border-[var(--color-border)] bg-[var(--color-surface-muted)] px-4 py-2 text-sm font-medium text-[var(--color-text-primary)] shadow-sm transition hover:bg-[var(--color-surface-hover)] disabled:opacity-50'



/** Icon-only control — use for prev/next, not refresh. */

export const pageToolbarIconBtnClass =

  'inline-flex h-10 w-10 shrink-0 items-center justify-center rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-muted)] text-[var(--color-text-secondary)] shadow-sm transition hover:bg-[var(--color-surface-hover)] disabled:opacity-50'



export function PageToolbarRefreshButton({

  onClick,

  disabled,

  loading,

}: {

  onClick: () => void

  disabled?: boolean

  loading?: boolean

}) {

  return (

    <button type="button" onClick={onClick} disabled={disabled} className={pageToolbarBtnClass}>

      <RefreshCw

        size={16}

        className={`shrink-0 text-[var(--color-text-muted)] ${loading ? 'animate-spin' : ''}`}

        strokeWidth={2}

      />

      <span className="whitespace-nowrap text-sm font-medium">Refresh</span>

    </button>

  )

}


