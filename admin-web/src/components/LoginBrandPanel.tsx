/** Matches Flutter [LoginBrandPanel] — dark gradient hero, no background photo. */
import { AccessBrandMark } from './AccessBrandMark'

const HERO_GRADIENT =
  'linear-gradient(135deg, #050C1C 0%, #0A1628 55%, #0C3340 100%)'

export function LoginBrandPanel({ compact = false }: { compact?: boolean }) {
  const markSize = compact ? 52 : 88
  const titleSize = compact ? '1.25rem' : '2rem'
  const visionSize = compact ? '1.375rem' : '2.25rem'
  const taglineSize = compact ? '12px' : '15px'

  return (
    <div
      className={[
        'relative flex w-full flex-col items-center justify-center overflow-hidden text-white',
        compact ? 'h-full' : 'min-h-screen lg:min-h-0 lg:h-full',
      ].join(' ')}
      style={{ background: HERO_GRADIENT }}
    >
      {!compact && (
        <>
          <div className="login-glow login-glow--cyan" aria-hidden />
          <div className="login-glow login-glow--blue" aria-hidden />
        </>
      )}

      <div
        className={[
          'relative z-10 flex flex-col items-center px-6 text-center',
          compact ? 'py-1' : 'px-14 py-16',
        ].join(' ')}
      >
        <div
          className="login-mark-clip shrink-0"
          style={{ width: markSize, height: markSize }}
        >
          <AccessBrandMark size={markSize} />
        </div>

        <div className="mt-2.5 leading-tight sm:mt-6">
          <div
            className="font-extrabold tracking-wide text-[#00C4E8]"
            style={{ fontSize: titleSize }}
          >
            ACCESS
          </div>
          <div className="font-bold text-white" style={{ fontSize: visionSize, letterSpacing: '-0.02em' }}>
            VisionCheck
          </div>
        </div>

        <p
          className="mt-1.5 font-medium text-white/88 sm:mt-4"
          style={{ fontSize: taglineSize, lineHeight: 1.25 }}
        >
          Campus Documentation Platform
        </p>
      </div>
    </div>
  )
}
