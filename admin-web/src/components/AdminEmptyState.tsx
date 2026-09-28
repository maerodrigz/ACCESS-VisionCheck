import type { ReactNode } from 'react'

interface Props {
  title?: string
  children: ReactNode
  className?: string
}

/** Centered empty placeholder for tables and list panels. */
export function AdminEmptyState({
  title = 'Nothing here yet',
  children,
  className = '',
}: Props) {
  return (
    <div
      className={`rounded-[var(--card-radius)] border border-dashed border-[var(--color-border)] bg-[var(--color-surface)] px-4 py-10 text-center ${className}`}
      role="status"
    >
      <p className="text-sm font-bold text-[var(--color-text-primary)]">{title}</p>
      <div className="mt-1 text-sm text-[var(--color-text-secondary)]">{children}</div>
    </div>
  )
}
