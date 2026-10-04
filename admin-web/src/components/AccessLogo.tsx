import { useState } from 'react'

import { AccessBrandMark } from './AccessBrandMark'

import { useBranding } from '../context/BrandingContext'



const BUNDLED_MARK = '/access-brand-a.png?v=1'



interface Props {

  size: number

  circular?: boolean

  className?: string

}



/** Official ACCESS logo — server custom image, or ribbon A mark. */

export function AccessLogo({ size, circular = false, className = '' }: Props) {

  const { logoUrl } = useBranding()

  const [failedSrc, setFailedSrc] = useState<string | null>(null)



  const primarySrc = logoUrl && failedSrc !== logoUrl ? logoUrl : null

  const bundledSrc = failedSrc === BUNDLED_MARK ? null : BUNDLED_MARK

  const src = primarySrc ?? (circular ? null : bundledSrc)



  const shellClass = circular

    ? 'overflow-hidden rounded-full border border-white/20 bg-[var(--color-surface-elevated)]'

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

          className="h-full w-full object-contain"

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


