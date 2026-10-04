/** Thin ACCESS cyan strip for card headers (matches sidebar brand). */
export function CardTopAccent() {
  return (
    <div
      className="w-full shrink-0"
      style={{
        height: 'var(--card-top-accent-height)',
        background:
          'linear-gradient(90deg, var(--color-sidebar-top), var(--color-card-top-accent), var(--color-sidebar-bottom))',
      }}
      aria-hidden
    />
  )
}
