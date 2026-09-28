export type AccessRole = 'Admin' | 'Member' | 'Organization'

export interface AuthUser {
  id: number
  name: string
  email: string
  role: AccessRole
  token: string
  profileImage?: string | null
}

export interface DashboardStats {
  pending_requests: number
  active_members: number
  pending_members: number
  media_uploads: number
  total_evaluations: number
  ai_flagged: number
  total_events: number
  feedback_count: number
  avg_feedback_rating?: number | null
  task_assignments?: number
  pending_assignments?: number
  accepted_assignments?: number
  declined_assignments?: number
  /** Member-confirmed assignments (legacy name). */
  completed_tasks?: number
  new_members_30d?: number
  new_members_prev_30d?: number
}
