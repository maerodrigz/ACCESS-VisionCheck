import { apiRequest } from './client'

export interface SystemMonitorPayload {
  api_status: string
  database: { connected: boolean; error: string | null; name: string }
  public_url: string
  response_ms: number
  table_counts: Record<string, number>
  audit_logs: {
    id: number
    action: string
    description: string
    user_name: string
    created_at: string | null
  }[]
}

export function fetchSystemMonitor() {
  return apiRequest<SystemMonitorPayload>('/admin/system-monitor')
}

export function broadcastNotification(body: {
  title: string
  message: string
  audience: 'all' | 'member' | 'organization' | 'admin'
}) {
  return apiRequest<{ message: string }>('/admin/notifications/broadcast', {
    method: 'POST',
    body: JSON.stringify(body),
  })
}
