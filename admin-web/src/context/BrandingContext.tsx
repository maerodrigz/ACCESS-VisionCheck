import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react'
import { brandingLogoUrl, fetchBranding, type BrandingPayload } from '../api/branding'

interface BrandingContextValue {
  branding: BrandingPayload | null
  logoUrl: string | null
  appName: string
  tagline: string
  /** Login hero subtitle — prefers API short_tagline (matches Flutter defaults). */
  loginHeroTagline: string
  loading: boolean
  refresh: () => Promise<void>
}

const BrandingContext = createContext<BrandingContextValue | null>(null)

const DEFAULT_APP_NAME = 'ACCESS'
const DEFAULT_TAGLINE = 'Unified Platform for Coordination and Documentation'
const DEFAULT_SHORT_TAGLINE = 'Coordination and Documentation Platform'

export function BrandingProvider({ children }: { children: ReactNode }) {
  const [branding, setBranding] = useState<BrandingPayload | null>(null)
  const [loading, setLoading] = useState(true)

  const refresh = useCallback(async () => {
    setLoading(true)
    try {
      const payload = await fetchBranding()
      setBranding(payload)
    } catch {
      setBranding(null)
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    void refresh()
  }, [refresh])

  const value = useMemo<BrandingContextValue>(
    () => ({
      branding,
      logoUrl: brandingLogoUrl(branding),
      appName: branding?.app_name?.trim() || DEFAULT_APP_NAME,
      tagline: branding?.tagline?.trim() || DEFAULT_TAGLINE,
      loginHeroTagline: branding?.short_tagline?.trim() || DEFAULT_SHORT_TAGLINE,
      loading,
      refresh,
    }),
    [branding, loading, refresh],
  )

  return <BrandingContext.Provider value={value}>{children}</BrandingContext.Provider>
}

export function useBranding() {
  const ctx = useContext(BrandingContext)
  if (!ctx) {
    throw new Error('useBranding must be used within BrandingProvider')
  }
  return ctx
}
