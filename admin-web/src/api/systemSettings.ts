import { apiRequest } from './client'
import { mergeSettingsResponse, type SystemSettingsConfig } from '../lib/systemConfiguration'

function parseResponse(data: Record<string, unknown>): SystemSettingsConfig & { message?: string } {
  return mergeSettingsResponse(data)
}

export function fetchSystemSettings() {
  return apiRequest<Record<string, unknown>>('/admin/system-settings').then(parseResponse)
}

export function saveGeneralSettings(body: {
  app_name: string
  organization: string
  system_description: string
}) {
  return apiRequest<Record<string, unknown>>('/admin/system-settings/general', {
    method: 'PATCH',
    body: JSON.stringify(body),
  }).then(parseResponse)
}

export function resetGeneralSettings() {
  return apiRequest<Record<string, unknown>>('/admin/system-settings/general/reset', {
    method: 'POST',
    body: JSON.stringify({}),
  }).then(parseResponse)
}

export function saveNotificationSettings(body: Record<string, boolean>) {
  return apiRequest<Record<string, unknown>>('/admin/system-settings/notifications', {
    method: 'PATCH',
    body: JSON.stringify(body),
  }).then(parseResponse)
}

export function saveAiEvaluationSettings(body: { enabled: boolean }) {
  return apiRequest<Record<string, unknown>>('/admin/system-settings/ai-evaluation', {
    method: 'PATCH',
    body: JSON.stringify(body),
  }).then(parseResponse)
}

export function saveMediaSettings(body: Record<string, unknown>) {
  return apiRequest<Record<string, unknown>>('/admin/system-settings/media', {
    method: 'PATCH',
    body: JSON.stringify(body),
  }).then(parseResponse)
}

export function saveSecuritySettings(body: Record<string, number>) {
  return apiRequest<Record<string, unknown>>('/admin/system-settings/security', {
    method: 'PATCH',
    body: JSON.stringify(body),
  }).then(parseResponse)
}
