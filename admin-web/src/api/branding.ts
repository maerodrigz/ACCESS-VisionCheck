import { API_BASE } from './client'

export interface BrandingPayload {
  logo_url?: string | null
  updated_at?: string | null
  is_custom?: boolean
  app_name?: string
  tagline?: string
  short_tagline?: string
  organization?: string
  web_admin_title?: string
  names_custom?: boolean
}

export async function fetchBranding(): Promise<BrandingPayload> {
  const res = await fetch(`${API_BASE}/branding`)
  if (!res.ok) {
    throw new Error(`Failed to load branding (${res.status})`)
  }
  return res.json() as Promise<BrandingPayload>
}

/** Resolve logo path from public branding API (matches Flutter [BrandingController]). */
export function brandingLogoUrl(payload: BrandingPayload | null | undefined): string | null {
  const path = payload?.logo_url?.trim()
  if (!path) return null
  if (path.startsWith('http://') || path.startsWith('https://')) return path
  const normalized = path.startsWith('/') ? path : `/${path}`
  const stamp = payload?.updated_at?.trim()
  if (stamp) {
    const sep = normalized.includes('?') ? '&' : '?'
    return `${normalized}${sep}v=${encodeURIComponent(stamp)}`
  }
  return normalized
}
