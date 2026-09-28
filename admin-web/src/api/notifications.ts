import { apiRequest } from './client'

/** Platform-wide admin notification feed (all users). */
export function fetchNotifications() {
  return apiRequest<Record<string, unknown>[]>('/admin/notifications')
}

export function markNotificationRead(id: number) {
  return apiRequest<Record<string, unknown>>(`/admin/notifications/${id}/read`, {
    method: 'PATCH',
    body: JSON.stringify({}),
  })
}

export function markAllNotificationsRead() {
  return apiRequest<{ message: string }>('/admin/notifications/read-all', {
    method: 'POST',
    body: JSON.stringify({}),
  })
}

export function clearReadNotifications() {
  return apiRequest<{ message: string }>('/admin/notifications/read', {
    method: 'DELETE',
  })
}
