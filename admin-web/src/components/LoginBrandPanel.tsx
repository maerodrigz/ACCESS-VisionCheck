import { Camera, Star, Video } from 'lucide-react'

const FEATURES = [
  { icon: Camera, label: 'Photos' },
  { icon: Video, label: 'Videos' },
  { icon: Star, label: 'Excellence' },
] as const

/** Circular ACCESS emblem (user-supplied asset, transparent outside the ring). */
const ACCESS_LOGO_SRC = '/images/access-logo.png'
/** Official USTP mark; rendered white on the dark photo panel via CSS. */
const USTP_LOGO_SRC = '/images/ustp-logo.png'

export function LoginBrandPanel() {
  return (
    <>
      <div className="login-hero__logos" aria-label="ACCESS and USTP">
        <img
          src={ACCESS_LOGO_SRC}
          alt="ACCESS, Active Certified Computer-Enhance Student Society"
          width={72}
          height={72}
          draggable={false}
          className="login-hero__logo login-hero__logo--access"
        />
        <span className="login-hero__logo-divider" aria-hidden />
        <img
          src={USTP_LOGO_SRC}
          alt="University of Science and Technology of Southern Philippines"
          width={108}
          height={72}
          draggable={false}
          className="login-hero__logo login-hero__logo--ustp"
        />
      </div>

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
