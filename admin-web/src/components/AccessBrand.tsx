import { Link } from 'react-router-dom'
import { AccessBrandMark } from './AccessBrandMark'
import { AccessLogo } from './AccessLogo'

const APP_TITLE = 'ACCESS'
const APP_SUBTITLE = 'VisionCheck'
const APP_NAME = `${APP_TITLE} ${APP_SUBTITLE}`

interface AccessBrandProps {
  /** Horizontal lockup for sidebar; stacked for login hero. */
  variant?: 'horizontal' | 'stacked'
  markSize?: number
  linkToHome?: boolean
  className?: string
  /** Tighter wordmark for narrow sidebar. */
  compact?: boolean
  /** Cyan sidebar: white ACCESS + primary blue VisionCheck. */
  onCyanBackground?: boolean
}

/** App logo lockup — ribbon A mark + ACCESS VisionCheck wordmark. */
export function AccessBrand({
  variant = 'horizontal',
  markSize = 44,
  linkToHome = false,
  className = '',
  compact = false,
  onCyanBackground = false,
}: AccessBrandProps) {
  const titleClass =
    variant === 'stacked'
      ? 'text-[2rem] font-extrabold tracking-tight text-[var(--color-accent-cyan)] sm:text-[2.125rem]'
      : onCyanBackground
        ? compact
          ? 'text-[12px] font-extrabold tracking-tight text-white drop-shadow-[0_1px_2px_rgba(0,0,0,0.22)]'
          : 'text-[17px] font-extrabold tracking-tight text-white drop-shadow-[0_1px_2px_rgba(0,0,0,0.22)]'
        : compact
          ? 'text-[13px] font-extrabold tracking-tight text-[var(--color-accent-cyan)]'
          : 'text-[17px] font-extrabold tracking-tight text-[var(--color-accent-cyan)]'

  const subtitleClass =
    variant === 'stacked'
      ? 'text-xl font-semibold text-white sm:text-[1.35rem]'
      : onCyanBackground
        ? compact
          ? 'text-[10px] font-extrabold text-[var(--color-accent-primary)] drop-shadow-[0_1px_1px_rgba(255,255,255,0.35)]'
          : 'text-[15px] font-extrabold text-[var(--color-accent-primary)] drop-shadow-[0_1px_1px_rgba(255,255,255,0.35)]'
        : compact
          ? 'text-[11px] font-semibold text-white/90'
          : 'text-[15px] font-semibold text-white/90'

  const wordmark = (
    <div className={variant === 'stacked' ? 'text-center leading-tight' : 'leading-tight'}>
      <div className={titleClass}>{APP_TITLE}</div>
      <div className={subtitleClass}>{APP_SUBTITLE}</div>
    </div>
  )

  const mark = compact ? (
    <AccessLogo size={markSize} circular />
  ) : (
    <AccessBrandMark size={markSize} />
  )

  const content =
    variant === 'stacked' ? (
      <div className={`flex flex-col items-center gap-4 ${className}`}>
        <AccessBrandMark size={markSize} />
        {wordmark}
      </div>
    ) : (
      <div className={`flex items-center ${compact ? 'gap-2' : 'gap-3'} ${className}`}>
        {mark}
        {wordmark}
      </div>
    )

  if (linkToHome) {
    return (
      <Link
        to="/"
        className="block rounded-xl transition hover:opacity-90"
        aria-label={`${APP_NAME} home`}
      >
        {content}
      </Link>
    )
  }

  return content
}

export { APP_NAME, APP_SUBTITLE, APP_TITLE }
