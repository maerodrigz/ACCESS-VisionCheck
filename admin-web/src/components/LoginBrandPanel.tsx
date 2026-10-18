/** Design #3 — hero copy on the photographic background (left column). */
const HEADLINES = ['Capture', 'Create', 'Elevate'] as const
const TAGLINE = 'Beyond Documentation Towards Excellence.'

export function LoginBrandPanel({ compact = false }: { compact?: boolean }) {
  return (
    <section
      className={['login-hero', compact ? 'login-hero--compact' : 'login-hero--desktop'].join(' ')}
      aria-label="ACCESS VisionCheck"
    >
      <div className="login-hero__lines">
        {HEADLINES.map((word) => (
          <p key={word} className="login-hero__headline">
            {word}
          </p>
        ))}
      </div>
      <div className="login-hero__rule" aria-hidden />
      <p className="login-hero__tagline">{TAGLINE}</p>
    </section>
  )
}
