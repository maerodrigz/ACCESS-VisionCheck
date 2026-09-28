import { apiRequest, apiUpload } from './client'
import type { BrandingPayload } from './branding'

export type AdminBrandingPayload = BrandingPayload & {
  updated_by?: string | null
  message?: string
}

export function fetchAdminBranding() {
  return apiRequest<AdminBrandingPayload>('/admin/branding')
}

export function uploadAdminLogo(file: File) {
  return apiUpload<AdminBrandingPayload>('/admin/branding/logo', file)
}

export function resetAdminLogo() {
  return apiRequest<AdminBrandingPayload>('/admin/branding/logo', { method: 'DELETE' })
}
