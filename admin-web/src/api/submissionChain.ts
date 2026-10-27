import { apiRequest } from './client'

export type SubmissionChainMediaRow = {
  media_id: number
  file_name: string
  file_type?: string | null
  uploaded_at?: string | null
  review_status?: string | null
  admin_remarks?: string | null
  replaces_media_id?: number | null
  chain_role?: string | null
  replacement_lifecycle?: string | null
  evaluation_id?: number | null
}

export type SubmissionChainEventRow = {
  id: number
  event_type: string
  media_id?: number | null
  actor_user_id?: number | null
  payload?: string | null
  created_at?: string | null
}

export type AdminSubmissionChainTimeline = {
  chain_id: number
  root_media_id: number
  xp_awarded_total: number
  xp_award_locked: boolean
  xp_reconciliation_status?: string | null
  active_replacement_media_id?: number | null
  awaiting_replacement_media_id?: number | null
  media: SubmissionChainMediaRow[]
  events: SubmissionChainEventRow[]
}

export function fetchAdminSubmissionChain(mediaId: number) {
  return apiRequest<AdminSubmissionChainTimeline>(`/admin/media/${mediaId}/submission-chain`)
}
