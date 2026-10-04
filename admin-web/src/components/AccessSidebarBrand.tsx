import { AccessOrgSealLogo } from './AccessOrgSealLogo'
import { useBranding } from '../context/BrandingContext'

interface AccessSidebarBrandProps {
  compact?: boolean
  logoSize?: number
}

/** Sidebar branding — org logo + ACCESS VisionCheck wordmark (matches Flutter). */
export function AccessSidebarBrand({ compact = false, logoSize = 64 }: AccessSidebarBrandProps) {
  const { appName } = useBranding()
  const title = appName.startsWith('ACCESS') ? 'ACCESS' : appName.split(' ')[0] ?? 'ACCESS'
  const subtitle = appName.includes('VisionCheck')
    ? 'VisionCheck'
    : appName.replace(title, '').trim() || 'VisionCheck'

  const logo = <AccessOrgSealLogo size={logoSize} showShadow={false} />

  if (compact) {
    return <div className="flex justify-center">{logo}</div>
  }

  return (
    <div className="flex min-w-0 items-center gap-3">
      {logo}
      <div className="min-w-0">
        <div className="truncate text-lg font-extrabold tracking-tight text-white">{title}</div>
        <div className="truncate text-[15px] font-bold text-white/90">{subtitle}</div>
      </div>
    </div>
  )
}
