import { Link } from 'react-router-dom'
import { AccessBrandMark } from './AccessBrandMark'

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
}

/** App logo lockup — ribbon A mark + ACCESS VisionCheck wordmark. */
export function AccessBrand({
  variant = 'horizontal',
  markSize = 44,
  linkToHome = false,
  className = '',
  compact = false,
}: AccessBrandProps) {
  const titleClass =
    variant === 'stacked'
      ? 'text-[2rem] font-extrabold tracking-tight text-[var(--color-accent-cyan)] sm:text-[2.125rem]'
      : compact
        ? 'text-[13px] font-extrabold tracking-tight text-[var(--color-accent-cyan)]'
        : 'text-[17px] font-extrabold tracking-tight text-[var(--color-accent-cyan)]'

  const subtitleClass =
    variant === 'stacked'
      ? 'text-xl font-semibold text-white sm:text-[1.35rem]'
      : compact
        ? 'text-[11px] font-semibold text-white/90'
        : 'text-[15px] font-semibold text-white/90'

  const wordmark = (
    <div className={variant === 'stacked' ? 'text-center leading-tight' : 'leading-tight'}>
      <div className={titleClass}>{APP_TITLE}</div>
      <div className={subtitleClass}>{APP_SUBTITLE}</div>
    </div>
  )

  const content =
    variant === 'stacked' ? (
      <div className={`flex flex-col items-center gap-4 ${className}`}>
        <AccessBrandMark size={markSize} />
        {wordmark}
      </div>
    ) : (
      <div className={`flex items-center ${compact ? 'gap-2' : 'gap-3'} ${className}`}>
        <AccessBrandMark size={markSize} />
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
