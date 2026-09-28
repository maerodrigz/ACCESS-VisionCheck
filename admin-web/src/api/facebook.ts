import { apiRequest } from './client'

export interface FacebookShareOpenedResponse {
  id: number
  media_id: number
  share_url?: string
  facebook_sharer_url?: string
  facebook_page_url?: string
  status?: string
}

/** Log that admin opened Facebook to share (browser flow — no Page token required). */
export function logFacebookShareOpened(body: {
  media_id: number
  message?: string
  share_url?: string
}) {
  return apiRequest<FacebookShareOpenedResponse>('/facebook/share/opened', {
    method: 'POST',
    body: JSON.stringify(body),
  })
}

/** Server-side Graph API post (requires FACEBOOK_PAGE_ACCESS_TOKEN in backend .env). */
export function shareToFacebookApi(body: { media_id: number; message?: string }) {
  return apiRequest<FacebookShareOpenedResponse>('/facebook/share', {
    method: 'POST',
    body: JSON.stringify({ ...body, mode: 'api' }),
  })
}

/** Browser share flow — returns sharer URLs from backend. */
export function shareToFacebookBrowser(body: { media_id: number; message?: string }) {
  return apiRequest<FacebookShareOpenedResponse>('/facebook/share', {
    method: 'POST',
    body: JSON.stringify({ ...body, mode: 'browser' }),
  })
}
