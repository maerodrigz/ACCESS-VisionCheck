import { Camera, Star, Video } from 'lucide-react'

const FEATURES = [
  { icon: Camera, label: 'Photos' },
  { icon: Video, label: 'Videos' },
  { icon: Star, label: 'Excellence' },
] as const

export function LoginBrandPanel() {
  return (
    <>
      <div className="login-brand-stack">
        <div className="login-hero">
          <p className="login-hero__line">Capture.</p>
          <p className="login-hero__line">Create.</p>
          <p className="login-hero__line login-hero__line--accent">Elevate.</p>
          <div className="login-hero__rule" aria-hidden />
          <p className="login-hero__tagline">
            <span className="login-hero__tagline-line">Beyond Documentation</span>
            <span className="login-hero__tagline-line">Towards Excellence.</span>
          </p>
        </div>
      </div>

      <ul className="login-hero__features">
        {FEATURES.map(({ icon: Icon, label }) => (
          <li key={label} className="login-hero__feature">
            <span className="login-hero__feature-icon" aria-hidden>
              <Icon size={17} strokeWidth={1.75} />
            </span>
            <span className="login-hero__feature-label">{label}</span>
          </li>
        ))}
      </ul>
    </>
  )
}
