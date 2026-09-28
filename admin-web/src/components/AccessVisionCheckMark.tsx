interface Props {
  size?: number
  className?: string
  showBubbles?: boolean
}

/** Default ACCESS VisionCheck mark — cyan→blue tile with photo symbol. */
export function AccessVisionCheckMark({ size = 64, className = '', showBubbles = true }: Props) {
  const tile = size * 0.78
  const radius = size * 0.22
  const icon = tile * 0.44

  return (
    <div
      className={`relative inline-flex items-center justify-center ${className}`}
      style={{ width: size, height: size }}
      aria-hidden
    >
      {showBubbles && (
        <>
      <span
        className="absolute rounded-full bg-[#00c4e8]/25"
        style={{ width: size * 0.22, height: size * 0.22, left: size * 0.06, bottom: size * 0.1 }}
      />
      <span
        className="absolute rounded-full bg-[#00c4e8]/20"
        style={{ width: size * 0.18, height: size * 0.18, right: size * 0.04, bottom: size * 0.14 }}
      />
      <span
        className="absolute rounded-full bg-[#00c4e8]/16"
        style={{ width: size * 0.14, height: size * 0.14, left: size * 0.28, bottom: size * 0.02 }}
      />
        </>
      )}
      <div
        className="relative flex items-center justify-center shadow-[0_6px_18px_rgba(0,82,212,0.22)]"
        style={{
          width: tile,
          height: tile,
          borderRadius: radius,
          background: 'linear-gradient(135deg, #00c4e8 0%, #0052d4 100%)',
        }}
      >
        <svg width={icon} height={icon} viewBox="0 0 24 24" fill="none" aria-hidden>
          <path
            d="M8.5 5h7A3.5 3.5 0 0 1 19 8.5v7A3.5 3.5 0 0 1 15.5 19h-7A3.5 3.5 0 0 1 5 15.5v-7A3.5 3.5 0 0 1 8.5 5Z"
            stroke="white"
            strokeWidth="1.8"
          />
          <path
            d="M8.5 14.5 11 11.5l2 2 2.5-3 3 3.5"
            stroke="white"
            strokeWidth="1.8"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
          <circle cx="9.25" cy="9.25" r="1.15" fill="white" />
        </svg>
      </div>
    </div>
  )
}
