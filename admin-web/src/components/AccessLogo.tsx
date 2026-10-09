import { useState } from 'react'

import { AccessBrandMark } from './AccessBrandMark'

import { useBranding } from '../context/BrandingContext'

/** Ribbon A mark (non-circular surfaces). */
const BUNDLED_MARK = '/access-brand-a.png?v=1'
/** Circular launcher / app icon (matches Flutter `access_app_icon`). */
const BUNDLED_APP_ICON = '/access_logo.png?v=1'

interface Props {
  size: number
  circular?: boolean
  className?: string
}

/** Official ACCESS logo — server custom image, app icon, or ribbon mark fallback. */
export function AccessLogo({ size, circular = false, className = '' }: Props) {
  const { logoUrl } = useBranding()
  const [failedSrc, setFailedSrc] = useState<string | null>(null)

  const bundledDefault = circular ? BUNDLED_APP_ICON : BUNDLED_MARK
  const primarySrc = logoUrl && failedSrc !== logoUrl ? logoUrl : null
  const bundledSrc = failedSrc === bundledDefault ? null : bundledDefault
  const src = primarySrc ?? bundledSrc

  const shellClass = circular
    ? 'overflow-hidden rounded-full border border-white/20 bg-white'
    : 'overflow-hidden rounded-2xl bg-transparent'

  if (src) {
    return (
      <div
        className={`relative shrink-0 ${shellClass} ${className}`}
        style={{ width: size, height: size }}
      >
        <img
          src={src}
          alt="ACCESS VisionCheck"
          draggable={false}
          className={circular ? 'h-full w-full object-cover' : 'h-full w-full object-contain'}
          onError={() => setFailedSrc(src)}
        />
      </div>
    )
  }

  return (
    <div
      className={`relative flex shrink-0 items-center justify-center ${shellClass} ${className}`}
      style={{ width: size, height: size }}
    >
      <AccessBrandMark size={size * 0.92} />
    </div>
  )
}
