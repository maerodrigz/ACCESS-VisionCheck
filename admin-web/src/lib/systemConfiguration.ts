export type SystemConfigSectionId =
  | 'general'
  | 'notifications'
  | 'ai_evaluation'
  | 'media'
  | 'security'
  | 'monitor'

export type SectionSaveState = 'idle' | 'saving' | 'success' | 'error'

export interface SystemSettingsConfig {
  general?: Record<string, unknown>
  notifications?: Record<string, unknown>
  ai_evaluation?: Record<string, unknown>
  media?: Record<string, unknown>
  security?: Record<string, unknown>
  meta?: Record<string, unknown>
  message?: string
}

export interface GeneralFormValues {
  app_name: string
  organization: string
  system_description: string
}

export interface NotificationsFormValues {
  notify_new_documentation_request: boolean
  notify_request_approved: boolean
  notify_request_rejected: boolean
  notify_new_documentation_assignment: boolean
  notify_new_announcement: boolean
  notify_system_alerts: boolean
}

export interface AiFormValues {
  enabled: boolean
}

export interface MediaFormValues {
  event_max_upload_mb: number
  evaluation_max_upload_mb: number
  max_evaluation_uploads_per_day: number
  event_allowed_image_formats: string
  event_allowed_video_formats: string
  evaluation_allowed_image_formats: string
  evaluation_allowed_video_formats: string
  enable_facebook_publishing: boolean
}

export interface SecurityFormValues {
  session_timeout_minutes: number
  min_password_length: number
  max_login_attempts: number
  account_lockout_minutes: number
}

export const SYSTEM_CONFIG_SECTIONS: {
  id: SystemConfigSectionId
  label: string
}[] = [
  { id: 'general', label: 'General' },
  { id: 'notifications', label: 'Notifications' },
  { id: 'ai_evaluation', label: 'AI Evaluation' },
  { id: 'media', label: 'Media' },
  { id: 'security', label: 'Security' },
  { id: 'monitor', label: 'System Monitor' },
]

export const VALID_SECTIONS = new Set<SystemConfigSectionId>(
  SYSTEM_CONFIG_SECTIONS.map((s) => s.id),
)

export const NOTIFICATION_ITEMS: {
  key: keyof NotificationsFormValues
  label: string
  hint: string
}[] = [
  {
    key: 'notify_new_documentation_request',
    label: 'New Documentation Request',
    hint: 'Alert administrators when a requester submits a new documentation request.',
  },
  {
    key: 'notify_request_approved',
    label: 'Request Approved',
    hint: 'Notify the requester when their documentation request is approved.',
  },
  {
    key: 'notify_request_rejected',
    label: 'Request Rejected',
    hint: 'Notify the requester when their documentation request is rejected.',
  },
  {
    key: 'notify_new_documentation_assignment',
    label: 'New Documentation Assignment',
    hint: 'Notify members and administrators when someone is assigned to an event or task.',
  },
  {
    key: 'notify_new_announcement',
    label: 'New Announcement',
    hint: 'Deliver in-app alerts to members when administrators post a new announcement.',
  },
  {
    key: 'notify_system_alerts',
    label: 'System Alerts',
    hint: 'Notify administrators about feedback, uploads, and AI integrity flags.',
  },
]

export const SECURITY_ITEMS: {
  key: keyof SecurityFormValues
  label: string
  hint: string
  min: number
  max: number
  suffix: string
}[] = [
  {
    key: 'session_timeout_minutes',
    label: 'Session Timeout',
    hint: 'How long a signed-in session stays valid before users must sign in again. Applies to new sessions after you save.',
    min: 5,
    max: 480,
    suffix: 'minutes',
  },
  {
    key: 'min_password_length',
    label: 'Password Policy — Minimum Length',
    hint: 'Minimum number of characters required when users create or change passwords. Passwords themselves are never stored or displayed here.',
    min: 6,
    max: 32,
    suffix: 'characters',
  },
  {
    key: 'max_login_attempts',
    label: 'Login Attempt Limit',
    hint: 'Number of consecutive failed sign-in attempts allowed before the account is temporarily locked.',
    min: 3,
    max: 20,
    suffix: 'attempts',
  },
  {
    key: 'account_lockout_minutes',
    label: 'Account Lockout Duration',
    hint: 'How long an account remains locked after exceeding the login attempt limit. Lockout clears automatically when this period ends.',
    min: 5,
    max: 1440,
    suffix: 'minutes',
  },
]

export function sectionFromHash(hash: string): SystemConfigSectionId {
  const id = hash.replace(/^#/, '').trim() as SystemConfigSectionId
  return VALID_SECTIONS.has(id) ? id : 'general'
}

export function formatsToInput(formats?: string[] | null): string {
  if (!formats?.length) return ''
  return formats.join(', ')
}

export function savedGeneralValues(config: SystemSettingsConfig): GeneralFormValues {
  const g = config.general || {}
  return {
    app_name: String(g.app_name || '').trim(),
    organization: String(g.organization || '').trim(),
    system_description: String(g.system_description || '').trim(),
  }
}

export function savedNotificationsValues(config: SystemSettingsConfig): NotificationsFormValues {
  const inApp = (config.notifications?.in_app || {}) as Record<string, boolean>
  const values = {} as NotificationsFormValues
  for (const item of NOTIFICATION_ITEMS) {
    values[item.key] = inApp[item.key] !== false
  }
  return values
}

export function savedAiValues(config: SystemSettingsConfig): AiFormValues {
  const ai = config.ai_evaluation || {}
  return { enabled: ai.enabled !== false }
}

export function savedMediaValues(config: SystemSettingsConfig): MediaFormValues {
  const m = config.media || {}
  const event = (m.event_documentation || {}) as Record<string, unknown>
  const evaluation = (m.member_evaluation || {}) as Record<string, unknown>
  const defaults = (m.defaults || {}) as Record<string, unknown>
  return {
    event_max_upload_mb: Number(event.max_upload_mb ?? defaults.event_max_upload_mb ?? 100),
    evaluation_max_upload_mb: Number(
      evaluation.max_upload_mb ?? defaults.evaluation_max_upload_mb ?? 100,
    ),
    max_evaluation_uploads_per_day: Number(evaluation.max_files_per_day ?? 5),
    event_allowed_image_formats: formatsToInput(
      event.allowed_image_formats as string[] | undefined,
    ),
    event_allowed_video_formats: formatsToInput(
      event.allowed_video_formats as string[] | undefined,
    ),
    evaluation_allowed_image_formats: formatsToInput(
      evaluation.allowed_image_formats as string[] | undefined,
    ),
    evaluation_allowed_video_formats: formatsToInput(
      evaluation.allowed_video_formats as string[] | undefined,
    ),
    enable_facebook_publishing: Boolean(event.enable_facebook_publishing ?? true),
  }
}

export function savedSecurityValues(config: SystemSettingsConfig): SecurityFormValues {
  const s = config.security || {}
  return {
    session_timeout_minutes: Number(s.session_timeout_minutes ?? 60),
    min_password_length: Number(s.min_password_length ?? 8),
    max_login_attempts: Number(s.max_login_attempts ?? 5),
    account_lockout_minutes: Number(s.account_lockout_minutes ?? 30),
  }
}

export function validateGeneralForm(form: GeneralFormValues): Partial<Record<keyof GeneralFormValues, string>> {
  const errors: Partial<Record<keyof GeneralFormValues, string>> = {}
  if (!form.app_name.trim()) errors.app_name = 'System name is required.'
  else if (form.app_name.trim().length > 120) {
    errors.app_name = 'System name must be 120 characters or fewer.'
  }
  if (!form.organization.trim()) errors.organization = 'Organization name is required.'
  else if (form.organization.trim().length > 120) {
    errors.organization = 'Organization name must be 120 characters or fewer.'
  }
  if (!form.system_description.trim()) errors.system_description = 'System description is required.'
  else if (form.system_description.trim().length > 255) {
    errors.system_description = 'System description must be 255 characters or fewer.'
  }
  return errors
}

function validateExtensionCsv(raw: string, label: string): string | null {
  const text = String(raw || '').trim()
  if (!text) return `${label} is required.`
  const parts = text
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean)
  if (!parts.length) return `${label} must include at least one extension.`
  for (const part of parts) {
    const ext = part.startsWith('.') ? part.toLowerCase() : `.${part.toLowerCase()}`
    if (!/^\.[a-z0-9]+$/.test(ext)) return `Invalid extension in ${label}: ${part}`
  }
  return null
}

export function validateMediaForm(
  form: MediaFormValues,
): Partial<Record<keyof MediaFormValues, string>> {
  const errors: Partial<Record<keyof MediaFormValues, string>> = {}
  if (
    !Number.isFinite(form.event_max_upload_mb) ||
    form.event_max_upload_mb < 1 ||
    form.event_max_upload_mb > 500
  ) {
    errors.event_max_upload_mb = 'Event max file size must be between 1 and 500 MB.'
  }
  if (
    !Number.isFinite(form.evaluation_max_upload_mb) ||
    form.evaluation_max_upload_mb < 1 ||
    form.evaluation_max_upload_mb > 500
  ) {
    errors.evaluation_max_upload_mb = 'Evaluation max file size must be between 1 and 500 MB.'
  }
  if (
    !Number.isFinite(form.max_evaluation_uploads_per_day) ||
    form.max_evaluation_uploads_per_day < 1 ||
    form.max_evaluation_uploads_per_day > 100
  ) {
    errors.max_evaluation_uploads_per_day =
      'Maximum evaluation files must be between 1 and 100 per day.'
  }
  const extChecks: [keyof MediaFormValues, string][] = [
    ['event_allowed_image_formats', 'Event image formats'],
    ['event_allowed_video_formats', 'Event video formats'],
    ['evaluation_allowed_image_formats', 'Evaluation image formats'],
    ['evaluation_allowed_video_formats', 'Evaluation video formats'],
  ]
  for (const [key, label] of extChecks) {
    const msg = validateExtensionCsv(String(form[key]), label)
    if (msg) errors[key] = msg
  }
  return errors
}

export function validateSecurityForm(
  form: SecurityFormValues,
  ranges?: Record<string, { min: number; max: number }>,
): Partial<Record<keyof SecurityFormValues, string>> {
  const errors: Partial<Record<keyof SecurityFormValues, string>> = {}
  for (const item of SECURITY_ITEMS) {
    const range = ranges?.[item.key] || { min: item.min, max: item.max }
    const value = form[item.key]
    if (!Number.isFinite(value)) {
      errors[item.key] = `${item.label} must be a number.`
      continue
    }
    if (value < range.min || value > range.max) {
      errors[item.key] = `Enter a value between ${range.min} and ${range.max}.`
    }
  }
  return errors
}

export function buildSecurityChangeSummary(
  next: SecurityFormValues,
  saved: SecurityFormValues,
): string {
  return SECURITY_ITEMS.map((item) => {
    const prev = saved[item.key]
    const value = next[item.key]
    if (prev === value) return null
    return `• ${item.label}: ${prev} → ${value} ${item.suffix}`
  })
    .filter(Boolean)
    .join('\n')
}

export function generalDefaultsHint(config: SystemSettingsConfig): string {
  const defaults = (config.general?.defaults || {}) as Record<string, string>
  if (defaults.app_name && defaults.organization) {
    return `Reset defaults: ${defaults.app_name} · ${defaults.organization}`
  }
  return 'Default values are loaded from the backend configuration.'
}

export function mergeSettingsResponse(data: Record<string, unknown>): SystemSettingsConfig {
  return {
    general: data.general as Record<string, unknown> | undefined,
    notifications: data.notifications as Record<string, unknown> | undefined,
    ai_evaluation: data.ai_evaluation as Record<string, unknown> | undefined,
    media: data.media as Record<string, unknown> | undefined,
    security: data.security as Record<string, unknown> | undefined,
    meta: data.meta as Record<string, unknown> | undefined,
    message: typeof data.message === 'string' ? data.message : undefined,
  }
}

export function formsEqual<T extends Record<string, unknown>>(a: T, b: T): boolean {
  return Object.keys(a).every((key) => String(a[key]) === String(b[key]))
}
