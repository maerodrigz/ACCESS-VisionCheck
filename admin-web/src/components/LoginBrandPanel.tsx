/** Matches Flutter [LoginBrandPanel] — dark gradient hero, no background photo. */
import { useBranding } from '../context/BrandingContext'
import { AccessLogo } from './AccessLogo'
import { AccessOrgSealLogo } from './AccessOrgSealLogo'

const HERO_GRADIENT =
  'linear-gradient(135deg, #050C1C 0%, #0A1628 55%, #0C3340 100%)'

function loginTitleLines(appName: string) {
  const title = appName.startsWith('ACCESS') ? 'ACCESS' : appName.split(' ')[0] ?? 'ACCESS'
  const subtitle = appName.includes('VisionCheck')
    ? 'VisionCheck'
    : appName.replace(title, '').trim() || 'VisionCheck'
  return { title, subtitle }
}

export function LoginBrandPanel({ compact = false }: { compact?: boolean }) {
  const { appName, loginHeroTagline, logoUrl } = useBranding()
  const { title, subtitle } = loginTitleLines(appName)

  const markSize = compact ? 72 : 120
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
        {logoUrl ? (
          <AccessLogo
            size={markSize}
            circular
            className="login-app-icon shrink-0 shadow-lg shadow-black/25"
          />
        ) : (
          <AccessOrgSealLogo
            size={markSize}
            showShadow={compact}
            className="login-app-icon shrink-0 shadow-lg shadow-black/25"
          />
        )}

        <div className="mt-2.5 leading-tight sm:mt-6">
          <div
            className="font-extrabold tracking-wide text-[#00C4E8]"
            style={{ fontSize: titleSize }}
          >
            {title}
          </div>
          <div className="font-bold text-white" style={{ fontSize: visionSize, letterSpacing: '-0.02em' }}>
            {subtitle}
          </div>
        </div>

        <p
          className="mt-1.5 font-medium text-white/88 sm:mt-4"
          style={{ fontSize: taglineSize, lineHeight: 1.25 }}
        >
          {loginHeroTagline}
        </p>
      </div>
    </div>
  )
}
