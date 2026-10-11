import { ArrowLeft } from 'lucide-react'
import { Link } from 'react-router-dom'

const linkClass =
  'mb-3 inline-flex items-center gap-1.5 text-sm font-semibold text-[var(--color-accent-primary)] transition hover:opacity-80 lg:hidden'

const drawerBtnClass =
  'inline-flex items-center gap-1.5 rounded-lg px-2 py-1.5 text-sm font-semibold text-[var(--color-text-secondary)] transition hover:bg-[var(--color-surface-hover)] hover:text-[var(--color-text-primary)]'

/** Back link for full admin pages (usually returns to the dashboard). */
export function AdminBackButton({
  to = '/',
  label = 'Back to dashboard',
}: {
  to?: string
  label?: string
}) {
  return (
    <Link to={to} className={linkClass}>
      <ArrowLeft size={16} strokeWidth={2.25} aria-hidden />
      {label}
    </Link>
  )
}

/** Back control for drawers and floating detail panels. */
export function DrawerBackButton({
  onClick,
  label = 'Back',
}: {
  onClick: () => void
  label?: string
}) {
  return (
    <button type="button" onClick={onClick} className={drawerBtnClass}>
      <ArrowLeft size={18} strokeWidth={2.25} aria-hidden />
      {label}
    </button>
  )
}
