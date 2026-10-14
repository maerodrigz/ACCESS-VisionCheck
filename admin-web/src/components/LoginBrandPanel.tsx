/** Admin login hero — supplied multimedia backdrop + centered org seal branding. */
import { useBranding } from '../context/BrandingContext'
import { AccessOrgSealLogo } from './AccessOrgSealLogo'

function loginTitleLines(appName: string) {
  const title = appName.startsWith('ACCESS') ? 'ACCESS' : appName.split(' ')[0] ?? 'ACCESS'
  const subtitle = appName.includes('VisionCheck')
    ? 'VisionCheck'
    : appName.replace(title, '').trim() || 'VisionCheck'
  return { title, subtitle }
}

export function LoginBrandPanel({ compact = false }: { compact?: boolean }) {
  const { appName, loginHeroTagline } = useBranding()
  const { title, subtitle } = loginTitleLines(appName)

  const sealSize = compact ? 88 : 160
  const accessSize = compact ? '1.25rem' : '2rem'
  const visionSize = compact ? '1.375rem' : '2.25rem'
  const taglineSize = compact ? '14px' : '19px'

  return (
    <div
      className={[
        'login-brand-panel relative flex w-full flex-col items-center justify-center overflow-hidden text-white',
        compact ? 'h-full' : 'min-h-screen lg:min-h-0 lg:h-full',
      ].join(' ')}
    >
      <div className="login-brand-panel__overlay" aria-hidden />

      <div
        className={[
          'login-brand-panel__content relative z-10 flex flex-col items-center px-6 text-center',
          compact ? 'py-2' : 'px-10 py-16',
        ].join(' ')}
      >
        <AccessOrgSealLogo
          size={sealSize}
          showShadow={!compact}
          className="login-brand-seal shrink-0 shadow-lg shadow-black/30"
        />

        <div className={compact ? 'mt-3 leading-tight' : 'mt-6 leading-tight'}>
          <div
            className="font-extrabold tracking-wide text-[#00C4E8]"
            style={{ fontSize: accessSize }}
          >
            {title}
          </div>
          <div
            className="font-bold text-white"
            style={{ fontSize: visionSize, letterSpacing: '-0.02em' }}
          >
            {subtitle}
          </div>
        </div>

        <p
          className="font-medium text-white/90"
          style={{
            fontSize: taglineSize,
            lineHeight: 1.35,
            marginTop: compact ? 8 : 16,
          }}
        >
          {loginHeroTagline}
        </p>
      </div>
    </div>
  )
}
