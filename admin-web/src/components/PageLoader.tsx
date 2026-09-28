interface Props {
  label?: string
}

export function PageLoader({ label = 'Loading page…' }: Props) {
  return (
    <div
      className="flex min-h-[240px] flex-col items-center justify-center gap-3 text-[var(--color-text-secondary)]"
      role="status"
      aria-live="polite"
      aria-busy="true"
    >
      <div
        className="h-8 w-8 animate-spin rounded-full border-2 border-[var(--color-border)] border-t-[var(--color-accent-blue)]"
        aria-hidden="true"
      />
      <span className="text-sm font-semibold">{label}</span>
    </div>
  )
}