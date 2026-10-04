interface Props {
  size?: number
  showShadow?: boolean
  /** Insets raster so outer ring stays inside the circle (matches Flutter). */
  paddingFraction?: number
  className?: string
}

const SEAL_SRC = '/access-org-seal.jpg'
const RIBBON_FALLBACK_SRC = '/access-brand-a.svg?v=1'

function clampInset(size: number, paddingFraction: number) {
  const inset = size * paddingFraction
  return Math.min(14, Math.max(2, inset))
}

/** Circular org seal — parity with Flutter [AccessOrgSealLogo]. */
export function AccessOrgSealLogo({
  size = 40,
  showShadow = true,
  paddingFraction = 0.05,
  className = '',
}: Props) {
  const inset = clampInset(size, paddingFraction)
  const inner = size - inset * 2

  const disk = (
    <div
      className={`relative shrink-0 overflow-hidden rounded-full bg-white ${className}`}
      style={{ width: size, height: size }}
    >
      <div
        className="absolute inset-0 flex items-center justify-center"
        style={{ padding: inset }}
      >
        <img
          src={SEAL_SRC}
          alt="ACCESS, Active Certified Computer-Enhance Student Society, USTP Oroquieta"
          width={inner}
          height={inner}
          draggable={false}
          className="block max-h-full max-w-full object-contain"
          onError={(e) => {
            const img = e.currentTarget
            if (img.src.includes('access-brand-a')) return
            img.src = RIBBON_FALLBACK_SRC
          }}
        />
      </div>
    </div>
  )

  if (!showShadow) return disk

  return (
    <div
      className="shrink-0 rounded-full"
      style={{
        width: size,
        height: size,
        boxShadow: `0 ${size * 0.06}px ${size * 0.18}px rgba(0, 0, 0, 0.22)`,
      }}
    >
      {disk}
    </div>
  )
}
