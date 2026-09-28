import { apiRequest } from './client'

export type MediaCategory = 'event_documentation' | 'member_evaluation'
export type ApprovalStatus = 'pending' | 'approved' | 'rejected' | 'not_applicable'
export type FacebookPublishStatus = 'not_published' | 'publishing' | 'published' | 'failed'

export interface EventMediaRow {
  id: number
  file_name: string
  file_type: string
  file_url: string
  request_id: number | null
  media_category: MediaCategory
  approval_status: ApprovalStatus
  approval_rejection_reason: string | null
  facebook_publish_status: FacebookPublishStatus
  facebook_post_id: string | null
  facebook_published_at: string | null
  event_title: string | null
  event_date: string | null
  event_description: string | null
  uploaded_by: number | null
  uploader_name: string
  uploaded_at: string | null
  is_best_shot?: boolean
  album_name_override?: string | null
}

export interface BulkPublishResult {
  results: {
    media_id: number
    status: string
    facebook_post_id?: string
    facebook_published_at?: string
    publish_mode?: 'multi_photo_post' | 'album'
    error?: string
  }[]
  succeeded: number
  failed: number
  skipped: number
  total: number
  grouped?: boolean
  group_size?: number
  fallback_sequential?: boolean
  feed_grid?: boolean
  feed_post_count?: number
}

export interface FacebookHistoryEntry {
  id: number
  media_id: number
  file_name: string
  event_title: string | null
  message: string | null
  facebook_post_id: string | null
  status: string
  error_message: string | null
  created_at: string | null
  facebook_published_at: string | null
}

export function fetchEventMedia(params?: {
  approval_status?: string
  facebook_publish_status?: string
  request_id?: number
  search?: string
}) {
  const q = new URLSearchParams()
  if (params?.approval_status) q.set('approval_status', params.approval_status)
  if (params?.facebook_publish_status) q.set('facebook_publish_status', params.facebook_publish_status)
  if (params?.request_id) q.set('request_id', String(params.request_id))
  if (params?.search) q.set('search', params.search)
  const qs = q.toString()
  return apiRequest<EventMediaRow[]>(`/admin/event-media${qs ? `?${qs}` : ''}`)
}

export function fetchEventMediaStats() {
  return apiRequest<Record<string, number>>('/admin/event-media/stats')
}

export function updateEventMediaApproval(
  mediaId: number,
  status: 'approved' | 'rejected',
  rejectionReason?: string,
) {
  return apiRequest<EventMediaRow>(`/admin/event-media/${mediaId}/approval`, {
    method: 'PATCH',
    body: JSON.stringify({
      status,
      ...(rejectionReason ? { rejection_reason: rejectionReason } : {}),
    }),
  })
}

export function updateEventMediaCuration(
  mediaId: number,
  body: { is_best_shot?: boolean; album_name_override?: string | null },
) {
  return apiRequest<EventMediaRow>(`/admin/event-media/${mediaId}/curation`, {
    method: 'PATCH',
    body: JSON.stringify(body),
  })
}

export function bulkPublishEventMediaToFacebook(body: { media_ids: number[]; message?: string }) {
  return apiRequest<BulkPublishResult>('/admin/event-media/facebook/publish', {
    method: 'POST',
    body: JSON.stringify(body),
  })
}

export function fetchFacebookPublishHistory(limit = 50) {
  return apiRequest<FacebookHistoryEntry[]>(`/admin/event-media/facebook/history?limit=${limit}`)
}

export interface FacebookConfigStatus {
  configured: boolean
  browser_share_available: boolean
  publishing_enabled?: boolean
  page_id_set: boolean
  access_token_set: boolean
  page_token_valid?: boolean
  token_check?: {
    ok: boolean
    reason?: string
    token_subject_id?: string
    token_subject_name?: string
  }
  missing: string[]
  reminder: string
}

export function fetchFacebookConfigStatus() {
  return apiRequest<FacebookConfigStatus>('/admin/event-media/facebook/status')
}
