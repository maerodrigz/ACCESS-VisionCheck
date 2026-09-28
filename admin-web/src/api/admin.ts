import { apiRequest, apiUpload } from './client'
import type { DashboardStats } from '../types/auth'
import type { AiDetectionSummary, AiReviewHistoryEntry, ReviewStatus } from './media'
import type { AdminAccountUser, AdminUserProfile } from '../lib/accountManagement'
import { parseAdminAccountUser } from '../lib/accountManagement'

export function fetchDashboardStats() {
  return apiRequest<DashboardStats>('/admin/stats')
}

export function fetchServiceRequests() {
  return apiRequest<Record<string, unknown>[]>('/admin/service-requests')
}

export function fetchTasks() {
  return apiRequest<Record<string, unknown>[]>('/admin/tasks')
}

export async function fetchUsers(): Promise<AdminAccountUser[]> {
  const rows = await apiRequest<Record<string, unknown>[]>('/users')
  return rows.map(parseAdminAccountUser)
}

export function createUser(body: {
  name: string
  email: string
  role: string
  skill_level: string | null
  status: string
}) {
  return apiRequest<{ message: string }>('/users', {
    method: 'POST',
    body: JSON.stringify(body),
  })
}

export function updateUser(
  userId: number,
  body: {
    name: string
    email: string
    role: string
    skill_level: string | null
    status: string
  },
) {
  return apiRequest<{ message: string }>(`/users/${userId}`, {
    method: 'PATCH',
    body: JSON.stringify(body),
  })
}

export function fetchUserProfile(userId: number) {
  return apiRequest<AdminUserProfile>(`/users/${userId}/profile`)
}

export function updateUserRole(userId: number, role: string) {
  return apiRequest<{ message: string }>(`/users/${userId}/role`, {
    method: 'PATCH',
    body: JSON.stringify({ role }),
  })
}

export function resetUserPassword(userId: number) {
  return apiRequest<{ message: string; temporary_password: string }>(
    `/users/${userId}/reset-password`,
    { method: 'POST', body: JSON.stringify({}) },
  )
}

export function setUserStatus(userId: number, status: string, rejectionReason?: string) {
  return apiRequest<{ message: string }>(`/users/${userId}/status`, {
    method: 'PATCH',
    body: JSON.stringify({
      status,
      ...(rejectionReason ? { rejection_reason: rejectionReason } : {}),
    }),
  })
}

export function fetchRankings() {
  return apiRequest<Record<string, unknown>[]>('/rankings')
}

export function fetchEvents() {
  return apiRequest<Record<string, unknown>[]>('/admin/events')
}

export function createEvent(body: Record<string, unknown>) {
  return apiRequest<Record<string, unknown>>('/admin/events', {
    method: 'POST',
    body: JSON.stringify(body),
  })
}

export function updateEvent(eventId: number, body: Record<string, unknown>) {
  return apiRequest<Record<string, unknown>>(`/admin/events/${eventId}`, {
    method: 'PATCH',
    body: JSON.stringify(body),
  })
}

export function deleteEvent(eventId: number) {
  return apiRequest<{ message: string }>(`/admin/events/${eventId}`, { method: 'DELETE' })
}

export function fetchMedia() {
  return apiRequest<Record<string, unknown>[]>('/admin/media')
}

export function deleteMedia(mediaId: number) {
  return apiRequest<{ message: string }>(`/admin/media/${mediaId}`, { method: 'DELETE' })
}

export function archiveMediaFile(mediaId: number) {
  return apiRequest<{ message: string }>(`/admin/media/${mediaId}/archive`, {
    method: 'POST',
    body: JSON.stringify({}),
  })
}

export function uploadMediaFile(file: File, requestId: number, displayName?: string) {
  return apiUpload<Record<string, unknown>>('/media/upload', file, {
    request_id: String(requestId),
    ...(displayName ? { file_name: displayName } : {}),
  })
}

export function fetchEvaluations() {
  return apiRequest<Record<string, unknown>[]>('/admin/evaluations')
}

export function fetchEvaluationSummary() {
  return apiRequest<Record<string, unknown>>('/admin/evaluations/summary')
}

export function updateEvaluationRemarks(evaluationId: number, adminRemarks: string | null) {
  return apiRequest<Record<string, unknown>>(`/admin/evaluations/${evaluationId}`, {
    method: 'PATCH',
    body: JSON.stringify({ admin_remarks: adminRemarks }),
  })
}

export function archiveEvaluation(evaluationId: number) {
  return apiRequest<{ message: string }>(`/admin/evaluations/${evaluationId}/archive`, {
    method: 'POST',
    body: JSON.stringify({}),
  })
}

export function fetchFeedback() {
  return apiRequest<Record<string, unknown>[]>('/admin/feedback')
}

export function fetchMemberRatingSummaries() {
  return apiRequest<Record<string, { count: number; average_rating: number | null }>>(
    '/admin/member-ratings/summary',
  )
}

export function fetchMemberRatings(opts?: { memberId?: number; requestId?: number }) {
  const params = new URLSearchParams()
  if (opts?.memberId) params.set('member_id', String(opts.memberId))
  if (opts?.requestId) params.set('request_id', String(opts.requestId))
  const qs = params.toString()
  return apiRequest<Record<string, unknown>[]>(
    qs ? `/admin/member-ratings?${qs}` : '/admin/member-ratings',
  )
}

export function updateFeedbackAdminReview(
  feedbackId: number,
  body: { admin_response?: string | null; review_status?: 'pending' | 'reviewed' | 'archived' },
) {
  return apiRequest<{
    id: number
    request_id: number
    admin_response: string | null
    review_status: string
  }>(`/admin/feedback/${feedbackId}`, {
    method: 'PATCH',
    body: JSON.stringify(body),
  })
}

export function fetchRankingsSummary() {
  return apiRequest<Record<string, unknown>>('/rankings/summary')
}

export function updateRankingRemarks(userId: number, remarks: string, options?: { notifyMember?: boolean }) {
  return apiRequest<{ message: string }>(`/rankings/${userId}/remarks`, {
    method: 'PATCH',
    body: JSON.stringify({
      admin_remarks: remarks,
      notify_member: options?.notifyMember ?? false,
    }),
  })
}

export function updateCompetencyLevel(
  userId: number,
  level: 'Beginner' | 'Intermediate' | 'Advanced' | null,
) {
  return apiRequest<{
    competency_level_override: string | null
    competency_recommended_level: string
    effective_level: string
    skill_level: string
  }>(`/rankings/${userId}/competency-level`, {
    method: 'PATCH',
    body: JSON.stringify({ competency_level: level }),
  })
}

export function fetchMemberRegistrations(status = 'pending') {
  return apiRequest<Record<string, unknown>[]>(`/admin/registrations/members?status=${status}`)
}

export function approveMemberRegistration(userId: number) {
  return apiRequest<{ message: string }>(`/admin/registrations/members/${userId}/approve`, {
    method: 'POST',
    body: JSON.stringify({}),
  })
}

export function rejectMemberRegistration(userId: number, rejectionReason: string) {
  return apiRequest<{ message: string }>(`/admin/registrations/members/${userId}/reject`, {
    method: 'POST',
    body: JSON.stringify({ rejection_reason: rejectionReason }),
  })
}

export function fetchOrganizationRegistrations(status = 'pending') {
  return apiRequest<Record<string, unknown>[]>(
    `/admin/registrations/organizations?status=${status}`,
  )
}

export function approveOrganizationRegistration(userId: number) {
  return apiRequest<{ message: string }>(`/admin/registrations/organizations/${userId}/approve`, {
    method: 'POST',
    body: JSON.stringify({}),
  })
}

export function rejectOrganizationRegistration(userId: number, rejectionReason: string) {
  return apiRequest<{ message: string }>(`/admin/registrations/organizations/${userId}/reject`, {
    method: 'POST',
    body: JSON.stringify({ rejection_reason: rejectionReason }),
  })
}

export function setRequestStatus(
  requestId: number,
  status: string,
  rejectionReason?: string,
) {
  return apiRequest<{ message: string }>(`/service-requests/${requestId}`, {
    method: 'PATCH',
    body: JSON.stringify({
      status,
      ...(rejectionReason ? { rejection_reason: rejectionReason } : {}),
    }),
  })
}

export function assignMemberToRequest(
  requestId: number,
  body: { member_id: number; task_role: string; admin_notes?: string },
) {
  return apiRequest<Record<string, unknown>>(`/admin/service-requests/${requestId}/assign`, {
    method: 'POST',
    body: JSON.stringify(body),
  })
}

export function fetchRecommendedMembers(requestId: number, taskRole: string) {
  const q = new URLSearchParams({ task_role: taskRole })
  return apiRequest<Record<string, unknown>[]>(
    `/admin/service-requests/${requestId}/recommended-members?${q.toString()}`,
  )
}

export function fetchRequestAssignments(requestId: number) {
  return apiRequest<Record<string, unknown>[]>(`/admin/service-requests/${requestId}/assignments`)
}

export function assignDocumentationTeam(
  requestId: number,
  body: {
    photographer_id?: number
    videographer_id?: number
    admin_notes?: string
    replaces_assignment_id?: number
  },
) {
  return apiRequest<Record<string, unknown>>(`/admin/service-requests/${requestId}/assign-team`, {
    method: 'POST',
    body: JSON.stringify(body),
  })
}

export function fetchAiDetectionList() {
  return apiRequest<Record<string, unknown>[]>('/admin/ai-detection')
}

export function fetchAiDetectionSummary() {
  return apiRequest<AiDetectionSummary>('/admin/ai-detection/summary')
}

export function updateAiDetectionReview(
  id: number,
  body: { review_status: ReviewStatus; admin_remarks?: string },
) {
  return apiRequest<Record<string, unknown>>(`/admin/ai-detection/${id}`, {
    method: 'PATCH',
    body: JSON.stringify(body),
  })
}

export function archiveAiDetectionMedia(id: number) {
  return apiRequest<{ message: string }>(`/admin/ai-detection/${id}/archive`, {
    method: 'POST',
    body: JSON.stringify({}),
  })
}

export function fetchAiReviewHistory(aiId: number) {
  return apiRequest<AiReviewHistoryEntry[]>(`/admin/ai-detection/${aiId}/history`)
}
