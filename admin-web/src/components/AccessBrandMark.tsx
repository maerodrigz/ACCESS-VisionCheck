interface Props {
  size?: number
  className?: string
}

/** Official ACCESS ribbon "A" mark — vector SVG (no raster box on light surfaces). */
export function AccessBrandMark({ size = 40, className = '' }: Props) {
  return (
    <img
      src="/access-brand-a.svg?v=1"
      alt="ACCESS VisionCheck"
      width={size}
      height={size}
      draggable={false}
      className={`block shrink-0 object-contain ${className}`}
    />
  )
}
