/**
 * ACCESS VisionCheck — System Configuration (vanilla JS)
 * Initialize with initSystemConfiguration(rootElement, options).
 */

const ICONS = {
  general: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/></svg>',
  notifications:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/></svg>',
  ai: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>',
  media:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="8.5" cy="8.5" r="1.5"/><polyline points="21 15 16 10 5 21"/></svg>',
  security:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>',
  refresh:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="23 4 23 10 17 10"/><path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10"/></svg>',
}

/** @type {{ key: string, label: string, hint: string }[]} */
const NOTIFICATION_ITEMS = [
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
    key: 'notify_evaluation_completed',
    label: 'Evaluation Completed',
    hint: 'Notify members when their media evaluation finishes and a score is available.',
  },
  {
    key: 'notify_new_announcement',
    label: 'New Announcement',
    hint: 'Deliver in-app alerts when administrators broadcast a platform announcement.',
  },
  {
    key: 'notify_system_alerts',
    label: 'System Alerts',
    hint: 'Notify administrators about platform events such as feedback, uploads, and AI integrity flags.',
  },
]

/** @type {{ key: string, label: string, hint: string, min: number, max: number, suffix: string }[]} */
const SECURITY_ITEMS = [
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

/** @type {{ id: string, label: string, icon: keyof typeof ICONS }[]} */
const NAV_SECTIONS = [
  { id: 'general', label: 'General', icon: 'general' },
  { id: 'notifications', label: 'Notifications', icon: 'notifications' },
  { id: 'ai_evaluation', label: 'AI Evaluation', icon: 'ai' },
  { id: 'media', label: 'Media', icon: 'media' },
  { id: 'security', label: 'Security', icon: 'security' },
]

const VALID_NAV_SECTIONS = new Set(NAV_SECTIONS.map((s) => s.id))

/**
 * @returns {string}
 */
function sectionFromHash() {
  if (typeof window === 'undefined') return 'general'
  const hash = window.location.hash.replace(/^#/, '').trim()
  return VALID_NAV_SECTIONS.has(hash) ? hash : 'general'
}

/**
 * @param {string} apiBase
 * @param {() => string | null} getToken
 * @param {string} path
 * @param {RequestInit} [init]
 */
async function apiFetch(apiBase, getToken, path, init = {}) {
  const headers = new Headers(init.headers)
  if (!headers.has('Content-Type') && init.body && !(init.body instanceof FormData)) {
    headers.set('Content-Type', 'application/json')
  }
  const token = getToken()
  if (token) headers.set('Authorization', `Bearer ${token}`)
  const res = await fetch(`${apiBase}${path}`, { ...init, headers })
  let data = null
  const text = await res.text()
  if (text) {
    try {
      data = JSON.parse(text)
    } catch {
      data = text
    }
  }
  if (!res.ok) {
    let msg = `Request failed (${res.status})`
    if (data && typeof data === 'object') {
      if ('detail' in data) {
        const detail = data.detail
        if (typeof detail === 'string') msg = detail
        else if (Array.isArray(detail) && detail.length) {
          msg = detail.map((d) => (d && d.msg ? String(d.msg) : String(d))).join(' ')
        }
      } else if ('message' in data) {
        msg = String(data.message)
      }
    }
    throw new Error(msg)
  }
  return data
}

/**
 * @param {string} html
 */
function escapeHtml(html) {
  return String(html)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
}

/**
 * @param {string} id
 * @param {string} label
 * @param {string} [hint]
 * @param {boolean} checked
 * @param {boolean} [disabled]
 */
function toggleRow(id, label, hint, checked, disabled = false) {
  return `
    <div class="sys-config__row">
      <div class="sys-config__row-text">
        <div class="sys-config__row-label">${escapeHtml(label)}</div>
        ${hint ? `<div class="sys-config__row-hint">${escapeHtml(hint)}</div>` : ''}
      </div>
      <label class="sys-config__toggle">
        <input type="checkbox" data-toggle="${escapeHtml(id)}" ${checked ? 'checked' : ''} ${disabled ? 'disabled' : ''} />
        <span class="sys-config__toggle-track"></span>
      </label>
    </div>`
}

/**
 * @param {string | undefined} msg
 */
function fieldErrorHtml(msg) {
  if (!msg) return '<span class="sys-config__field-error" aria-live="polite"></span>'
  return `<span class="sys-config__field-error" role="alert">${escapeHtml(msg)}</span>`
}

/**
 * @param {string} id
 * @param {string} label
 * @param {string} value
 * @param {string | undefined} error
 * @param {{ multiline?: boolean, hint?: string }} [opts]
 */
function generalField(id, label, value, error, opts = {}) {
  const input = opts.multiline
    ? `<textarea class="sys-config__input sys-config__textarea" id="${escapeHtml(id)}" data-input="${escapeHtml(id)}" rows="3" maxlength="255">${escapeHtml(value)}</textarea>`
    : `<input class="sys-config__input" type="text" id="${escapeHtml(id)}" data-input="${escapeHtml(id)}" value="${escapeHtml(value)}" maxlength="${id === 'app_name' || id === 'organization' ? 120 : 255}" />`

  return `
    <div class="sys-config__field ${error ? 'has-error' : ''}">
      <label class="sys-config__label" for="${escapeHtml(id)}">${escapeHtml(label)} <span class="sys-config__required">*</span></label>
      ${opts.hint ? `<span class="sys-config__hint">${escapeHtml(opts.hint)}</span>` : ''}
      ${input}
      ${fieldErrorHtml(error)}
    </div>`
}

/**
 * @param {{ app_name: string, organization: string, system_description: string }} form
 */
function validateGeneralForm(form) {
  /** @type {Record<string, string>} */
  const errors = {}
  if (!form.app_name.trim()) errors.app_name = 'System name is required.'
  else if (form.app_name.trim().length > 120) errors.app_name = 'System name must be 120 characters or fewer.'

  if (!form.organization.trim()) errors.organization = 'Organization name is required.'
  else if (form.organization.trim().length > 120) errors.organization = 'Organization name must be 120 characters or fewer.'

  if (!form.system_description.trim()) errors.system_description = 'System description is required.'
  else if (form.system_description.trim().length > 255) errors.system_description = 'System description must be 255 characters or fewer.'

  return errors
}

/**
 * @param {string} title
 * @param {string} modelName
 * @param {string} description
 * @param {{ available?: boolean, locked?: boolean }} [opts]
 */
function aiModelBlock(title, modelName, description, opts = {}) {
  const badges = []
  if (opts.locked !== false) {
    badges.push('<span class="sys-config__model-badge">Fixed model</span>')
  }
  if (opts.available === true) {
    badges.push('<span class="sys-config__model-badge sys-config__model-badge--success">Available on server</span>')
  } else if (opts.available === false) {
    badges.push('<span class="sys-config__model-badge sys-config__model-badge--warning">Weights not loaded</span>')
  }
  return `
    <div class="sys-config__model-block">
      <div class="sys-config__model-head">
        <div>
          <div class="sys-config__model-title">${escapeHtml(title)}</div>
          <div class="sys-config__model-name">${escapeHtml(modelName)}</div>
        </div>
        ${badges.length ? `<div class="sys-config__model-badges">${badges.join('')}</div>` : ''}
      </div>
      <p class="sys-config__model-desc">${escapeHtml(description)}</p>
    </div>`
}

/**
 * @param {string} id
 * @param {string} label
 * @param {number} value
 * @param {number} min
 * @param {number} max
 * @param {string} suffix
 */
function numberField(id, label, value, min, max, suffix) {
  return `
    <div class="sys-config__field">
      <label class="sys-config__label" for="${escapeHtml(id)}">${escapeHtml(label)}</label>
      <div class="sys-config__inline-number">
        <input class="sys-config__input" type="number" id="${escapeHtml(id)}" data-number="${escapeHtml(id)}"
          value="${value}" min="${min}" max="${max}" />
        <span>${escapeHtml(suffix)}</span>
      </div>
    </div>`
}

/**
 * @param {string} id
 * @param {string} label
 * @param {number} value
 * @param {number} min
 * @param {number} max
 * @param {string} suffix
 * @param {string} hint
 * @param {string | undefined} error
 */
function securityNumberField(id, label, value, min, max, suffix, hint, error) {
  return `
    <div class="sys-config__field ${error ? 'has-error' : ''}">
      <label class="sys-config__label" for="${escapeHtml(id)}">${escapeHtml(label)}</label>
      <span class="sys-config__hint">${escapeHtml(hint)}</span>
      <div class="sys-config__inline-number">
        <input class="sys-config__input" type="number" id="${escapeHtml(id)}" data-number="${escapeHtml(id)}"
          value="${value}" min="${min}" max="${max}" />
        <span>${escapeHtml(suffix)}</span>
      </div>
      ${fieldErrorHtml(error)}
    </div>`
}

/**
 * @param {{ session_timeout_minutes: number, min_password_length: number, max_login_attempts: number, account_lockout_minutes: number }} form
 * @param {{ ranges?: Record<string, { min: number, max: number }> }} [meta]
 */
function validateSecurityForm(form, meta = {}) {
  /** @type {Record<string, string>} */
  const errors = {}
  for (const item of SECURITY_ITEMS) {
    const range = meta.ranges?.[item.key] || { min: item.min, max: item.max }
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

/**
 * @param {Record<string, number>} next
 * @param {Record<string, number>} saved
 */
function buildSecurityChangeSummary(next, saved) {
  return SECURITY_ITEMS.map((item) => {
    const prev = saved[item.key]
    const value = next[item.key]
    if (prev === value) return null
    return `• ${item.label}: ${prev} → ${value} ${item.suffix}`
  })
    .filter(Boolean)
    .join('\n')
}

/**
 * @param {string[] | undefined} formats
 */
function formatsToInput(formats) {
  if (!formats || !formats.length) return ''
  return formats.join(', ')
}

/**
 * @param {string} raw
 * @param {string} label
 */
function validateExtensionCsv(raw, label) {
  const text = String(raw || '').trim()
  if (!text) return `${label} is required.`
  const parts = text.split(',').map((s) => s.trim()).filter(Boolean)
  if (!parts.length) return `${label} must include at least one extension.`
  for (const part of parts) {
    const ext = part.startsWith('.') ? part.toLowerCase() : `.${part.toLowerCase()}`
    if (!/^\.[a-z0-9]+$/.test(ext)) return `Invalid extension in ${label}: ${part}`
  }
  return null
}

/**
 * @param {{ event_max_upload_mb: number, evaluation_max_upload_mb: number, max_evaluation_uploads_per_day: number, event_allowed_image_formats: string, event_allowed_video_formats: string, evaluation_allowed_image_formats: string, evaluation_allowed_video_formats: string }} form
 */
function validateMediaForm(form) {
  /** @type {Record<string, string>} */
  const errors = {}
  if (!Number.isFinite(form.event_max_upload_mb) || form.event_max_upload_mb < 1 || form.event_max_upload_mb > 500) {
    errors.event_max_upload_mb = 'Event max file size must be between 1 and 500 MB.'
  }
  if (!Number.isFinite(form.evaluation_max_upload_mb) || form.evaluation_max_upload_mb < 1 || form.evaluation_max_upload_mb > 500) {
    errors.evaluation_max_upload_mb = 'Evaluation max file size must be between 1 and 500 MB.'
  }
  if (!Number.isFinite(form.max_evaluation_uploads_per_day) || form.max_evaluation_uploads_per_day < 1 || form.max_evaluation_uploads_per_day > 100) {
    errors.max_evaluation_uploads_per_day = 'Maximum evaluation files must be between 1 and 100 per day.'
  }
  const extChecks = [
    ['event_allowed_image_formats', 'Event image formats'],
    ['event_allowed_video_formats', 'Event video formats'],
    ['evaluation_allowed_image_formats', 'Evaluation image formats'],
    ['evaluation_allowed_video_formats', 'Evaluation video formats'],
  ]
  for (const [key, label] of extChecks) {
    const msg = validateExtensionCsv(form[key], label)
    if (msg) errors[key] = msg
  }
  return errors
}

/**
 * @param {string} id
 * @param {string} label
 * @param {string} value
 * @param {string | undefined} error
 * @param {string} [hint]
 */
function mediaTextField(id, label, value, error, hint) {
  return `
    <div class="sys-config__field ${error ? 'has-error' : ''}">
      <label class="sys-config__label" for="${escapeHtml(id)}">${escapeHtml(label)}</label>
      ${hint ? `<span class="sys-config__hint">${escapeHtml(hint)}</span>` : ''}
      <input class="sys-config__input" type="text" id="${escapeHtml(id)}" data-input="${escapeHtml(id)}" value="${escapeHtml(value)}" />
      ${fieldErrorHtml(error)}
    </div>`
}

/**
 * @param {HTMLElement} root
 * @param {{ apiBase?: string, getToken?: () => string | null, getCurrentUser?: () => { role?: string } | null }} [options]
 */
export function initSystemConfiguration(root, options = {}) {
  const apiBase = (options.apiBase || '/api').replace(/\/$/, '')
  const getToken = options.getToken || (() => localStorage.getItem('access_admin_token'))
  const getCurrentUser =
    options.getCurrentUser ||
    (() => {
      try {
        return JSON.parse(localStorage.getItem('access_admin_user') || 'null')
      } catch {
        return null
      }
    })

  /** @type {Record<string, unknown> | null} */
  let config = null
  let loading = true
  let loadError = null
  /** @type {Record<string, 'idle' | 'saving' | 'success' | 'error'>} */
  const sectionState = {
    general: 'idle',
    notifications: 'idle',
    ai_evaluation: 'idle',
    media: 'idle',
    security: 'idle',
  }
  /** @type {Record<string, string | null>} */
  const sectionError = {
    general: null,
    notifications: null,
    ai_evaluation: null,
    media: null,
    security: null,
  }
  let generalResetting = false
  /** @type {Record<string, string>} */
  let generalFormErrors = {}
  /** @type {{ app_name: string, organization: string, system_description: string } | null} */
  let generalFormDraft = null
  /** @type {Record<string, string>} */
  let mediaFormErrors = {}
  /** @type {Record<string, string | number> | null} */
  let mediaFormDraft = null
  /** @type {Record<string, string>} */
  let securityFormErrors = {}
  /** @type {Record<string, number> | null} */
  let securityFormDraft = null
  /** @type {Record<string, unknown> | null} */
  let securityPendingSave = null
  /** @type {Record<string, boolean> | null} */
  let notificationsFormDraft = null
  /** @type {{ enabled: boolean } | null} */
  let aiFormDraft = null
  /** @type {string} */
  let activeSection = sectionFromHash()
  /** @type {number | null} */
  let toastTimer = null

  function showToast(message, success = true) {
    const existing = document.querySelector('.sys-config__toast')
    if (existing) existing.remove()
    if (toastTimer) clearTimeout(toastTimer)
    const el = document.createElement('div')
    el.className = `sys-config__toast ${success ? 'sys-config__toast--success' : 'sys-config__toast--error'}`
    el.textContent = message
    document.body.appendChild(el)
    toastTimer = window.setTimeout(() => el.remove(), 3200)
  }

  function sectionStatus(section) {
    const state = sectionState[section]
    const err = sectionError[section]
    if (state === 'saving') return '<span class="sys-config__card-status sys-config__card-status--saving">Saving…</span>'
    if (state === 'success') return '<span class="sys-config__card-status sys-config__card-status--success">Saved</span>'
    if (state === 'error' && err)
      return `<span class="sys-config__card-status sys-config__card-status--error">${escapeHtml(err)}</span>`
    return ''
  }

  async function loadConfig() {
    loading = true
    loadError = null
    generalFormDraft = null
    generalFormErrors = {}
    mediaFormDraft = null
    mediaFormErrors = {}
    securityFormDraft = null
    securityFormErrors = {}
    securityPendingSave = null
    notificationsFormDraft = null
    aiFormDraft = null
    render()
    try {
      config = await apiFetch(apiBase, getToken, '/admin/system-settings')
      loading = false
    } catch (err) {
      loadError = err instanceof Error ? err.message : 'Failed to load settings'
      loading = false
    }
    render()
  }

  function readGeneralForm() {
    return {
      app_name: readInput('app_name'),
      organization: readInput('organization'),
      system_description: readInput('system_description'),
    }
  }

  function readNotificationsForm() {
    /** @type {Record<string, boolean>} */
    const body = {}
    for (const item of NOTIFICATION_ITEMS) {
      body[item.key] = readToggle(item.key)
    }
    return body
  }

  function savedNotificationsValues() {
    const inApp = config?.notifications?.in_app || {}
    /** @type {Record<string, boolean>} */
    const body = {}
    for (const item of NOTIFICATION_ITEMS) {
      body[item.key] = inApp[item.key] !== false
    }
    return body
  }

  function readMediaSectionForm() {
    return {
      event_max_upload_mb: readNumber('event_max_upload_mb', 100),
      evaluation_max_upload_mb: readNumber('evaluation_max_upload_mb', 100),
      max_evaluation_uploads_per_day: readNumber('max_evaluation_uploads_per_day', 5),
      event_allowed_image_formats: readInput('event_allowed_image_formats'),
      event_allowed_video_formats: readInput('event_allowed_video_formats'),
      evaluation_allowed_image_formats: readInput('evaluation_allowed_image_formats'),
      evaluation_allowed_video_formats: readInput('evaluation_allowed_video_formats'),
      allow_late_media_uploads: readToggle('allow_late_media_uploads'),
      max_upload_period_days: readNumber('max_upload_period_days', 7),
      require_event_album_before_upload: readToggle('require_event_album_before_upload'),
      enable_facebook_publishing: readToggle('enable_facebook_publishing'),
    }
  }

  function savedMediaValues() {
    const m = config?.media || {}
    const event = m.event_documentation || {}
    const evaluation = m.member_evaluation || {}
    return {
      event_max_upload_mb: Number(event.max_upload_mb ?? m.defaults?.event_max_upload_mb ?? 100),
      evaluation_max_upload_mb: Number(evaluation.max_upload_mb ?? m.defaults?.evaluation_max_upload_mb ?? 100),
      max_evaluation_uploads_per_day: Number(evaluation.max_files_per_day ?? 5),
      event_allowed_image_formats: formatsToInput(event.allowed_image_formats),
      event_allowed_video_formats: formatsToInput(event.allowed_video_formats),
      evaluation_allowed_image_formats: formatsToInput(evaluation.allowed_image_formats),
      evaluation_allowed_video_formats: formatsToInput(evaluation.allowed_video_formats),
      allow_late_media_uploads: Boolean(event.allow_late_media_uploads),
      max_upload_period_days: Number(event.max_upload_period_days ?? 7),
      require_event_album_before_upload: Boolean(event.require_event_album_before_upload),
      enable_facebook_publishing: Boolean(event.enable_facebook_publishing),
    }
  }

  function savedGeneralValues() {
    const g = config?.general || {}
    return {
      app_name: String(g.app_name || '').trim(),
      organization: String(g.organization || '').trim(),
      system_description: String(g.system_description || '').trim(),
    }
  }

  function updateSectionHash(section) {
    if (typeof window === 'undefined') return
    const url = `${window.location.pathname}${window.location.search}#${section}`
    window.history.replaceState(null, '', url)
  }

  /**
   * @param {string} section
   */
  function snapshotSectionDraft(section) {
    if (!config) return
    if (section === 'general' && root.querySelector('[data-input="app_name"]')) {
      generalFormDraft = readGeneralForm()
    }
    if (section === 'notifications' && root.querySelector('[data-toggle="notify_new_documentation_request"]')) {
      notificationsFormDraft = readNotificationsForm()
    }
    if (section === 'ai_evaluation' && root.querySelector('[data-toggle="ai_media_evaluation_enabled"]')) {
      aiFormDraft = { enabled: readToggle('ai_media_evaluation_enabled') }
    }
    if (section === 'media' && root.querySelector('[data-number="event_max_upload_mb"]')) {
      mediaFormDraft = readMediaSectionForm()
    }
    if (section === 'security' && root.querySelector('[data-number="session_timeout_minutes"]')) {
      securityFormDraft = readSecurityForm()
    }
  }

  /**
   * @param {string} section
   */
  function clearSectionDraft(section) {
    if (section === 'general') {
      generalFormDraft = null
      generalFormErrors = {}
      sectionError.general = null
      sectionState.general = 'idle'
    }
    if (section === 'notifications') {
      notificationsFormDraft = null
      sectionError.notifications = null
      sectionState.notifications = 'idle'
    }
    if (section === 'ai_evaluation') {
      aiFormDraft = null
      sectionError.ai_evaluation = null
      sectionState.ai_evaluation = 'idle'
    }
    if (section === 'media') {
      mediaFormDraft = null
      mediaFormErrors = {}
      sectionError.media = null
      sectionState.media = 'idle'
    }
    if (section === 'security') {
      securityFormDraft = null
      securityFormErrors = {}
      securityPendingSave = null
      sectionError.security = null
      sectionState.security = 'idle'
    }
  }

  /**
   * @param {string} section
   */
  function sectionIsDirty(section) {
    if (!config) return false

    if (section === 'general') {
      const saved = savedGeneralValues()
      const current =
        activeSection === 'general' && root.querySelector('[data-input="app_name"]')
          ? readGeneralForm()
          : generalFormDraft || saved
      return (
        current.app_name !== saved.app_name ||
        current.organization !== saved.organization ||
        current.system_description !== saved.system_description
      )
    }

    if (section === 'notifications') {
      const saved = savedNotificationsValues()
      const current =
        activeSection === 'notifications' && root.querySelector('[data-toggle="notify_new_documentation_request"]')
          ? readNotificationsForm()
          : notificationsFormDraft || saved
      return NOTIFICATION_ITEMS.some((item) => current[item.key] !== saved[item.key])
    }

    if (section === 'ai_evaluation') {
      const saved = config.ai_evaluation?.enabled !== false
      const current =
        activeSection === 'ai_evaluation' && root.querySelector('[data-toggle="ai_media_evaluation_enabled"]')
          ? readToggle('ai_media_evaluation_enabled')
          : aiFormDraft ? aiFormDraft.enabled : saved
      return current !== saved
    }

    if (section === 'media') {
      const saved = savedMediaValues()
      const current =
        activeSection === 'media' && root.querySelector('[data-number="event_max_upload_mb"]')
          ? readMediaSectionForm()
          : mediaFormDraft || saved
      return Object.keys(saved).some((key) => String(current[key]) !== String(saved[key]))
    }

    if (section === 'security') {
      if (securityPendingSave) return true
      const saved = savedSecurityValues()
      const current =
        activeSection === 'security' && root.querySelector('[data-number="session_timeout_minutes"]')
          ? readSecurityForm()
          : securityFormDraft || saved
      return SECURITY_ITEMS.some((item) => Number(current[item.key]) !== Number(saved[item.key]))
    }

    return false
  }

  /**
   * @param {string} next
   * @param {{ skipHashUpdate?: boolean }} [opts]
   */
  function tryNavigateSection(next, opts = {}) {
    if (!VALID_NAV_SECTIONS.has(next) || next === activeSection) return

    snapshotSectionDraft(activeSection)
    if (sectionIsDirty(activeSection)) {
      const label = NAV_SECTIONS.find((s) => s.id === activeSection)?.label || activeSection
      if (!window.confirm(`You have unsaved changes in ${label}. Leave without saving?`)) {
        if (!opts.skipHashUpdate) updateSectionHash(activeSection)
        return
      }
      clearSectionDraft(activeSection)
    }

    activeSection = next
    if (!opts.skipHashUpdate) updateSectionHash(next)
    render()
  }

  function onHashChange() {
    const next = sectionFromHash()
    if (next === activeSection) return
    tryNavigateSection(next, { skipHashUpdate: true })
  }

  function readMediaForm() {
    return {
      event_max_upload_mb: readNumber('event_max_upload_mb', 100),
      evaluation_max_upload_mb: readNumber('evaluation_max_upload_mb', 100),
      max_evaluation_uploads_per_day: readNumber('max_evaluation_uploads_per_day', 5),
      event_allowed_image_formats: readInput('event_allowed_image_formats'),
      event_allowed_video_formats: readInput('event_allowed_video_formats'),
      evaluation_allowed_image_formats: readInput('evaluation_allowed_image_formats'),
      evaluation_allowed_video_formats: readInput('evaluation_allowed_video_formats'),
    }
  }

  function readSecurityForm() {
    return {
      session_timeout_minutes: readNumber('session_timeout_minutes', 60),
      min_password_length: readNumber('min_password_length', 8),
      max_login_attempts: readNumber('max_login_attempts', 5),
      account_lockout_minutes: readNumber('account_lockout_minutes', 30),
    }
  }

  function savedSecurityValues() {
    const s = config?.security || {}
    return {
      session_timeout_minutes: Number(s.session_timeout_minutes ?? 60),
      min_password_length: Number(s.min_password_length ?? 8),
      max_login_attempts: Number(s.max_login_attempts ?? 5),
      account_lockout_minutes: Number(s.account_lockout_minutes ?? 30),
    }
  }

  async function confirmSaveSecurity(body) {
    securityPendingSave = null
    securityFormDraft = null
    securityFormErrors = {}
    sectionError.security = null
    await saveSection('security', '/admin/system-settings/security', body)
  }

  async function resetGeneralSettings() {
    if (!window.confirm('Reset general settings to the default values from the server?')) return
    generalResetting = true
    generalFormErrors = {}
    generalFormDraft = null
    sectionError.general = null
    render()
    try {
      const data = await apiFetch(apiBase, getToken, '/admin/system-settings/general/reset', {
        method: 'POST',
      })
      config = data
      sectionState.general = 'success'
      showToast(data.message || 'General settings reset to defaults')
      render()
      window.setTimeout(() => {
        if (sectionState.general === 'success') {
          sectionState.general = 'idle'
          render()
        }
      }, 2500)
    } catch (err) {
      sectionState.general = 'error'
      sectionError.general = err instanceof Error ? err.message : 'Reset failed'
      showToast(sectionError.general, false)
      render()
    } finally {
      generalResetting = false
      render()
    }
  }

  /**
   * @param {string} section
   * @param {string} path
   * @param {Record<string, unknown>} body
   */
  async function saveSection(section, path, body) {
    sectionState[section] = 'saving'
    sectionError[section] = null
    render()
    try {
      const data = await apiFetch(apiBase, getToken, path, {
        method: 'PATCH',
        body: JSON.stringify(body),
      })
      config = data
      generalFormDraft = null
      generalFormErrors = {}
      mediaFormDraft = null
      mediaFormErrors = {}
      securityFormDraft = null
      securityFormErrors = {}
      securityPendingSave = null
      if (section === 'notifications') notificationsFormDraft = null
      if (section === 'ai_evaluation') aiFormDraft = null
      sectionState[section] = 'success'
      showToast(data.message || 'Settings saved')
      render()
      window.setTimeout(() => {
        if (sectionState[section] === 'success') {
          sectionState[section] = 'idle'
          render()
        }
      }, 2500)
    } catch (err) {
      sectionState[section] = 'error'
      sectionError[section] = err instanceof Error ? err.message : 'Save failed'
      showToast(sectionError[section], false)
      render()
    }
  }

  function readToggle(id) {
    const el = root.querySelector(`[data-toggle="${id}"]`)
    return el instanceof HTMLInputElement ? el.checked : false
  }

  function readNumber(id, fallback) {
    const el = root.querySelector(`[data-number="${id}"]`)
    if (!(el instanceof HTMLInputElement)) return fallback
    const n = parseInt(el.value, 10)
    return Number.isNaN(n) ? fallback : n
  }

  function readInput(id, fallback = '') {
    const el = root.querySelector(`[data-input="${id}"]`)
    return el instanceof HTMLInputElement ? el.value.trim() : fallback
  }

  function readSlider(id, fallback) {
    const el = root.querySelector(`[data-slider="${id}"]`)
    if (!(el instanceof HTMLInputElement)) return fallback
    return parseFloat(el.value)
  }

  function bindEvents() {
    root.querySelector('[data-action="refresh"]')?.addEventListener('click', () => {
      snapshotSectionDraft(activeSection)
      if (sectionIsDirty(activeSection)) {
        const label = NAV_SECTIONS.find((s) => s.id === activeSection)?.label || activeSection
        if (!window.confirm(`Discard unsaved changes in ${label} and reload from the server?`)) return
        clearSectionDraft(activeSection)
      }
      loadConfig()
    })

    root.querySelectorAll('[data-nav]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const next = btn.getAttribute('data-nav')
        if (next) tryNavigateSection(next)
      })
    })

    root.querySelector('[data-action="save-general"]')?.addEventListener('click', () => {
      const form = readGeneralForm()
      const errors = validateGeneralForm(form)
      if (Object.keys(errors).length) {
        generalFormErrors = errors
        generalFormDraft = form
        sectionState.general = 'error'
        sectionError.general = 'Fix the highlighted fields before saving.'
        showToast('Please fix the required fields.', false)
        render()
        return
      }
      generalFormDraft = null
      generalFormErrors = {}
      sectionError.general = null
      saveSection('general', '/admin/system-settings/general', {
        app_name: form.app_name.trim(),
        organization: form.organization.trim(),
        system_description: form.system_description.trim(),
      })
    })

    root.querySelector('[data-action="reset-general"]')?.addEventListener('click', () => {
      resetGeneralSettings()
    })

    root.querySelectorAll('[data-input="app_name"], [data-input="organization"], [data-input="system_description"]').forEach((el) => {
      el.addEventListener('input', () => {
        const field = el.getAttribute('data-input')
        if (field && generalFormErrors[field]) {
          delete generalFormErrors[field]
          sectionError.general = null
          sectionState.general = 'idle'
          render()
        }
      })
    })

    root.querySelector('[data-action="save-notifications"]')?.addEventListener('click', () => {
      /** @type {Record<string, boolean>} */
      const body = {}
      for (const item of NOTIFICATION_ITEMS) {
        body[item.key] = readToggle(item.key)
      }
      saveSection('notifications', '/admin/system-settings/notifications', body)
    })

    root.querySelector('[data-action="save-ai"]')?.addEventListener('click', () => {
      saveSection('ai_evaluation', '/admin/system-settings/ai-evaluation', {
        enabled: readToggle('ai_media_evaluation_enabled'),
      })
    })

    root.querySelector('[data-action="save-media"]')?.addEventListener('click', () => {
      const form = readMediaSectionForm()
      const errors = validateMediaForm(form)
      if (Object.keys(errors).length) {
        mediaFormErrors = errors
        mediaFormDraft = form
        sectionState.media = 'error'
        sectionError.media = 'Fix the highlighted fields before saving.'
        showToast('Please fix the media upload settings.', false)
        render()
        return
      }
      mediaFormDraft = null
      mediaFormErrors = {}
      sectionError.media = null
      saveSection('media', '/admin/system-settings/media', {
        event_max_upload_mb: form.event_max_upload_mb,
        evaluation_max_upload_mb: form.evaluation_max_upload_mb,
        max_evaluation_uploads_per_day: form.max_evaluation_uploads_per_day,
        event_allowed_image_formats: form.event_allowed_image_formats,
        event_allowed_video_formats: form.event_allowed_video_formats,
        evaluation_allowed_image_formats: form.evaluation_allowed_image_formats,
        evaluation_allowed_video_formats: form.evaluation_allowed_video_formats,
        allow_late_media_uploads: form.allow_late_media_uploads,
        max_upload_period_days: form.max_upload_period_days,
        require_event_album_before_upload: form.require_event_album_before_upload,
        enable_facebook_publishing: form.enable_facebook_publishing,
      })
    })

    root.querySelector('[data-action="save-security"]')?.addEventListener('click', () => {
      const form = readSecurityForm()
      const meta = config?.security || {}
      const errors = validateSecurityForm(form, meta)
      if (Object.keys(errors).length) {
        securityFormErrors = errors
        securityFormDraft = form
        sectionState.security = 'error'
        sectionError.security = 'Fix the highlighted fields before saving.'
        showToast('Please fix the security settings.', false)
        render()
        return
      }

      const saved = savedSecurityValues()
      const summary = buildSecurityChangeSummary(form, saved)
      if (!summary) {
        showToast('No security changes to save.', false)
        return
      }

      securityFormDraft = form
      securityPendingSave = {
        session_timeout_minutes: form.session_timeout_minutes,
        min_password_length: form.min_password_length,
        max_login_attempts: form.max_login_attempts,
        account_lockout_minutes: form.account_lockout_minutes,
        summary,
      }
      render()
    })

    root.querySelector('[data-action="confirm-security-save"]')?.addEventListener('click', () => {
      if (!securityPendingSave) return
      const body = {
        session_timeout_minutes: securityPendingSave.session_timeout_minutes,
        min_password_length: securityPendingSave.min_password_length,
        max_login_attempts: securityPendingSave.max_login_attempts,
        account_lockout_minutes: securityPendingSave.account_lockout_minutes,
      }
      confirmSaveSecurity(body)
    })

    root.querySelectorAll('[data-action="cancel-security-save"], [data-action="close-security-confirm"]').forEach((el) => {
      el.addEventListener('click', () => {
        securityPendingSave = null
        render()
      })
    })

    root.querySelectorAll(
      '[data-number="session_timeout_minutes"], [data-number="min_password_length"], [data-number="max_login_attempts"], [data-number="account_lockout_minutes"]',
    ).forEach((el) => {
      el.addEventListener('input', () => {
        const field = el.getAttribute('data-number')
        if (field && securityFormErrors[field]) {
          delete securityFormErrors[field]
          sectionError.security = null
          sectionState.security = 'idle'
          render()
        }
      })
    })
  }

  function renderGeneral(g) {
    const values = generalFormDraft || {
      app_name: g.app_name || '',
      organization: g.organization || '',
      system_description: g.system_description || '',
    }
    const defaults = g.defaults || {}
    const defaultsHint =
      defaults.app_name && defaults.organization && defaults.system_description
        ? `Defaults from server: ${defaults.app_name} · ${defaults.organization}`
        : 'Default values are loaded from the backend configuration.'

    return `
      <article class="sys-config__card" data-section="general">
        <div class="sys-config__card-head">
          <div class="sys-config__card-icon">${ICONS.general}</div>
          <div>
            <h2 class="sys-config__card-title">General Settings</h2>
            <p class="sys-config__card-desc">Platform identity shown across ACCESS VisionCheck login, navigation, and member apps.</p>
          </div>
        </div>
        <div class="sys-config__card-body">
          <div class="sys-config__banner sys-config__banner--info">${escapeHtml(defaultsHint)}</div>
          ${generalField('app_name', 'System Name', values.app_name, generalFormErrors.app_name, {
            hint: 'Displayed as the product title in admin and mobile apps.',
          })}
          ${generalField('organization', 'Organization Name', values.organization, generalFormErrors.organization, {
            hint: 'Institution name shown on dashboards and profile screens.',
          })}
          ${generalField(
            'system_description',
            'System Description',
            values.system_description,
            generalFormErrors.system_description,
            {
              multiline: true,
              hint: 'Short description shown on login and branding panels.',
            },
          )}
        </div>
        <div class="sys-config__card-foot">
          <button type="button" class="sys-config__btn sys-config__btn--primary" data-action="save-general" ${sectionState.general === 'saving' || generalResetting ? 'disabled' : ''}>
            ${sectionState.general === 'saving' ? 'Saving…' : 'Save Changes'}
          </button>
          <button type="button" class="sys-config__btn sys-config__btn--ghost" data-action="reset-general" ${sectionState.general === 'saving' || generalResetting ? 'disabled' : ''}>
            ${generalResetting ? 'Resetting…' : 'Reset'}
          </button>
          ${sectionStatus('general')}
        </div>
      </article>`
  }

  function renderNotifications(n) {
    const emailAvailable = Boolean(n.email_available)
    const channelNote = emailAvailable
      ? 'Configure in-app and email delivery for each notification type.'
      : 'In-app notifications only — email delivery is not configured on this server.'

    const values = notificationsFormDraft || savedNotificationsValues()

    const rows = NOTIFICATION_ITEMS.map((item) =>
      toggleRow(item.key, item.label, item.hint, values[item.key] !== false),
    ).join('')

    return `
      <article class="sys-config__card sys-config__card--wide" data-section="notifications">
        <div class="sys-config__card-head">
          <div class="sys-config__card-icon">${ICONS.notifications}</div>
          <div>
            <h2 class="sys-config__card-title">Notification Settings</h2>
            <p class="sys-config__card-desc">Control which platform events create in-app alerts for administrators and members.</p>
          </div>
        </div>
        <div class="sys-config__card-body">
          <div class="sys-config__banner sys-config__banner--info">${escapeHtml(channelNote)}</div>
          <div class="sys-config__notify-group">
            <div class="sys-config__notify-group-head">
              <span class="sys-config__notify-channel">In-App Notifications</span>
            </div>
            ${rows}
          </div>
        </div>
        <div class="sys-config__card-foot">
          <button type="button" class="sys-config__btn sys-config__btn--primary" data-action="save-notifications" ${sectionState.notifications === 'saving' ? 'disabled' : ''}>
            ${sectionState.notifications === 'saving' ? 'Saving…' : 'Save Changes'}
          </button>
          ${sectionStatus('notifications')}
        </div>
      </article>`
  }

  function renderAi(ai) {
    const quality = ai.quality_model || {}
    const feedback = ai.feedback_generation || {}
    const enabled = aiFormDraft ? aiFormDraft.enabled : ai.enabled !== false

    return `
      <article class="sys-config__card" data-section="ai_evaluation">
        <div class="sys-config__card-head">
          <div class="sys-config__card-icon">${ICONS.ai}</div>
          <div>
            <h2 class="sys-config__card-title">AI Evaluation Settings</h2>
            <p class="sys-config__card-desc">Member media quality scoring (EfficientNet-B0) and human-friendly feedback (Gemini). Upload limits are configured in Media Settings.</p>
          </div>
        </div>
        <div class="sys-config__card-body">
          ${toggleRow(
            'ai_media_evaluation_enabled',
            'AI Media Evaluation',
            enabled
              ? 'EfficientNet-B0 scoring and Gemini feedback are active for member evaluation uploads.'
              : 'Member evaluation scoring is paused — uploads that require AI evaluation will be rejected.',
            enabled,
          )}
          ${aiModelBlock(
            'Quality Evaluation Model',
            quality.name || 'EfficientNet-B0',
            quality.description ||
              'EfficientNet-B0 performs technical media quality evaluation and scoring for member uploads.',
            { available: quality.available_on_server, locked: quality.configurable === false },
          )}
          ${aiModelBlock(
            'Feedback Generation',
            feedback.name || 'Gemini',
            feedback.description ||
              'Gemini receives EfficientNet-B0 evaluation results and generates encouraging, human-friendly feedback. It does not change or invent scores.',
            { locked: feedback.configurable === false },
          )}
        </div>
        <div class="sys-config__card-foot">
          <button type="button" class="sys-config__btn sys-config__btn--primary" data-action="save-ai" ${sectionState.ai_evaluation === 'saving' ? 'disabled' : ''}>
            ${sectionState.ai_evaluation === 'saving' ? 'Saving…' : 'Save Changes'}
          </button>
          ${sectionStatus('ai_evaluation')}
        </div>
      </article>`
  }

  function renderMedia(m) {
    const event = m.event_documentation || {}
    const evaluation = m.member_evaluation || {}
    const fb = m.facebook || {}
    const draft = mediaFormDraft

    const eventMaxMb = draft?.event_max_upload_mb ?? event.max_upload_mb ?? m.defaults?.event_max_upload_mb ?? 100
    const evalMaxMb = draft?.evaluation_max_upload_mb ?? evaluation.max_upload_mb ?? m.defaults?.evaluation_max_upload_mb ?? 100
    const maxEvalFiles = draft?.max_evaluation_uploads_per_day ?? evaluation.max_files_per_day ?? 5
    const eventImages = draft?.event_allowed_image_formats ?? formatsToInput(event.allowed_image_formats)
    const eventVideos = draft?.event_allowed_video_formats ?? formatsToInput(event.allowed_video_formats)
    const evalImages = draft?.evaluation_allowed_image_formats ?? formatsToInput(evaluation.allowed_image_formats)
    const evalVideos = draft?.evaluation_allowed_video_formats ?? formatsToInput(evaluation.allowed_video_formats)

    const allowLateUploads = draft?.allow_late_media_uploads ?? event.allow_late_media_uploads ?? true
    const maxUploadDays = draft?.max_upload_period_days ?? event.max_upload_period_days ?? 7
    const requireAlbum = draft?.require_event_album_before_upload ?? event.require_event_album_before_upload ?? true
    const enableFacebook = draft?.enable_facebook_publishing ?? event.enable_facebook_publishing ?? true

    const fbBanner = fb.configured
      ? `<div class="sys-config__banner sys-config__banner--success">Facebook Graph API credentials are configured on the server.</div>`
      : `<div class="sys-config__banner sys-config__banner--warning">Facebook publishing requires FACEBOOK_PAGE_ID and FACEBOOK_PAGE_ACCESS_TOKEN in access_backend/.env. Missing: ${escapeHtml((fb.missing || []).join(', ') || 'credentials')}.</div>`

    return `
      <article class="sys-config__card sys-config__card--wide" data-section="media">
        <div class="sys-config__card-head">
          <div class="sys-config__card-icon">${ICONS.media}</div>
          <div>
            <h2 class="sys-config__card-title">Media Settings</h2>
            <p class="sys-config__card-desc">Upload rules for event documentation and member AI evaluation — these are separate workflows and are enforced independently by the backend.</p>
          </div>
        </div>
        <div class="sys-config__card-body">
          <div class="sys-config__media-grid">
            <section class="sys-config__workflow">
              <div class="sys-config__workflow-head">
                <h3 class="sys-config__workflow-title">Event Documentation</h3>
                <p class="sys-config__workflow-desc">Media uploaded for events, albums, and Facebook publishing approval. Never mixed with member practice evaluations.</p>
              </div>
              <div class="sys-config__field ${mediaFormErrors.event_max_upload_mb ? 'has-error' : ''}">
                <label class="sys-config__label" for="event_max_upload_mb">Maximum Upload File Size</label>
                <span class="sys-config__hint">Applies to event documentation uploads only.</span>
                <div class="sys-config__inline-number">
                  <input class="sys-config__input" type="number" id="event_max_upload_mb" data-number="event_max_upload_mb" value="${eventMaxMb}" min="1" max="500" />
                  <span>MB</span>
                </div>
                ${fieldErrorHtml(mediaFormErrors.event_max_upload_mb)}
              </div>
              ${mediaTextField('event_allowed_image_formats', 'Allowed Image Formats', String(eventImages), mediaFormErrors.event_allowed_image_formats, 'Comma-separated extensions, e.g. .jpg, .jpeg, .png')}
              ${mediaTextField('event_allowed_video_formats', 'Allowed Video Formats', String(eventVideos), mediaFormErrors.event_allowed_video_formats, 'Comma-separated extensions, e.g. .mp4, .mov')}
              ${toggleRow('allow_late_media_uploads', 'Allow Late Media Uploads', 'Permit uploads after the event completion window.', allowLateUploads)}
              ${numberField('max_upload_period_days', 'Maximum Upload Period', maxUploadDays, 1, 90, 'days')}
              ${toggleRow('require_event_album_before_upload', 'Require Event Album Before Upload', 'Members must create an album before uploading files.', requireAlbum)}
              ${toggleRow('enable_facebook_publishing', 'Enable Facebook Publishing', 'Allow administrators to publish approved event media to Facebook.', enableFacebook)}
              ${fbBanner}
            </section>

            <section class="sys-config__workflow sys-config__workflow--evaluation">
              <div class="sys-config__workflow-head">
                <h3 class="sys-config__workflow-title">Member AI Quality Evaluation</h3>
                <p class="sys-config__workflow-desc">Practice uploads scored by EfficientNet-B0 on the server. Gemini feedback is generated separately and never applies to event documentation media.</p>
              </div>
              <div class="sys-config__field ${mediaFormErrors.evaluation_max_upload_mb ? 'has-error' : ''}">
                <label class="sys-config__label" for="evaluation_max_upload_mb">Maximum Upload File Size</label>
                <span class="sys-config__hint">Applies to member evaluation uploads only.</span>
                <div class="sys-config__inline-number">
                  <input class="sys-config__input" type="number" id="evaluation_max_upload_mb" data-number="evaluation_max_upload_mb" value="${evalMaxMb}" min="1" max="500" />
                  <span>MB</span>
                </div>
                ${fieldErrorHtml(mediaFormErrors.evaluation_max_upload_mb)}
              </div>
              <div class="sys-config__field ${mediaFormErrors.max_evaluation_uploads_per_day ? 'has-error' : ''}">
                <label class="sys-config__label" for="max_evaluation_uploads_per_day">Maximum Evaluation Files</label>
                <span class="sys-config__hint">Daily limit per member for AI evaluation submissions.</span>
                <div class="sys-config__inline-number">
                  <input class="sys-config__input" type="number" id="max_evaluation_uploads_per_day" data-number="max_evaluation_uploads_per_day" value="${maxEvalFiles}" min="1" max="100" />
                  <span>files / day</span>
                </div>
                ${fieldErrorHtml(mediaFormErrors.max_evaluation_uploads_per_day)}
              </div>
              ${mediaTextField('evaluation_allowed_image_formats', 'Allowed Image Formats', String(evalImages), mediaFormErrors.evaluation_allowed_image_formats, 'Comma-separated extensions for evaluation photos')}
              ${mediaTextField('evaluation_allowed_video_formats', 'Allowed Video Formats', String(evalVideos), mediaFormErrors.evaluation_allowed_video_formats, 'Comma-separated extensions for evaluation videos')}
            </section>
          </div>
          ${m.storage_usage_percent != null ? `<div class="sys-config__readonly"><span class="sys-config__readonly-label">Storage usage (estimated)</span><span class="sys-config__readonly-value">${Math.round(m.storage_usage_percent)}%</span></div>` : ''}
        </div>
        <div class="sys-config__card-foot">
          <button type="button" class="sys-config__btn sys-config__btn--primary" data-action="save-media" ${sectionState.media === 'saving' ? 'disabled' : ''}>
            ${sectionState.media === 'saving' ? 'Saving…' : 'Save Changes'}
          </button>
          ${sectionStatus('media')}
        </div>
      </article>`
  }

  function renderNavItem(section) {
    const isActive = activeSection === section.id
    const dirty = sectionIsDirty(section.id)
    return `
      <button type="button" class="sys-config__nav-item ${isActive ? 'is-active' : ''} ${dirty ? 'has-unsaved' : ''}"
        data-nav="${section.id}" aria-current="${isActive ? 'page' : 'false'}">
        <span class="sys-config__nav-icon" aria-hidden="true">${ICONS[section.icon]}</span>
        <span class="sys-config__nav-label">${escapeHtml(section.label)}</span>
        ${dirty ? '<span class="sys-config__nav-dot" aria-label="Unsaved changes"></span>' : ''}
      </button>`
  }

  function renderNavigation() {
    const items = NAV_SECTIONS.map((section) => renderNavItem(section)).join('')
    return `
      <aside class="sys-config__nav sys-config__nav--sidebar" aria-label="Settings sections">
        <div class="sys-config__nav-title">Settings</div>
        <div class="sys-config__nav-list">${items}</div>
      </aside>
      <div class="sys-config__nav sys-config__nav--tabs" role="tablist" aria-label="Settings sections">
        ${items}
      </div>`
  }

  function renderUnsavedBanner() {
    if (!sectionIsDirty(activeSection)) return ''
    const label = NAV_SECTIONS.find((s) => s.id === activeSection)?.label || 'This section'
    return `<div class="sys-config__banner sys-config__banner--warning">You have unsaved changes in <strong>${escapeHtml(label)}</strong>. Save your changes before leaving this section.</div>`
  }

  function renderActiveSectionContent(g, n, ai, m, s) {
    switch (activeSection) {
      case 'notifications':
        return renderNotifications(n)
      case 'ai_evaluation':
        return renderAi(ai)
      case 'media':
        return renderMedia(m)
      case 'security':
        return renderSecurity(s)
      case 'general':
      default:
        return renderGeneral(g)
    }
  }

  function renderSecurityConfirmModal() {
    if (!securityPendingSave) return ''
    const summary = String(securityPendingSave.summary || '').replace(/\n/g, '<br />')
    return `
      <div class="sys-config__modal-backdrop" data-action="close-security-confirm">
        <div class="sys-config__modal" role="dialog" aria-labelledby="security-confirm-title" aria-modal="true" onclick="event.stopPropagation()">
          <div class="sys-config__modal-header">
            <h3 id="security-confirm-title" class="sys-config__modal-title">Apply security changes?</h3>
            <button type="button" class="sys-config__modal-close" data-action="close-security-confirm" aria-label="Close">×</button>
          </div>
          <div class="sys-config__modal-body">
            <p class="sys-config__confirm-lead">These settings affect sign-in, sessions, and password rules for all accounts.</p>
            <div class="sys-config__confirm-summary">${summary}</div>
            <p class="sys-config__confirm-note">Existing sessions keep their current expiry until users sign in again. Passwords and authentication secrets are never shown or stored in this panel.</p>
          </div>
          <div class="sys-config__modal-footer">
            <button type="button" class="sys-config__btn sys-config__btn--ghost" data-action="cancel-security-save">Cancel</button>
            <button type="button" class="sys-config__btn sys-config__btn--danger" data-action="confirm-security-save" ${sectionState.security === 'saving' ? 'disabled' : ''}>
              ${sectionState.security === 'saving' ? 'Saving…' : 'Apply Changes'}
            </button>
          </div>
        </div>
      </div>`
  }

  function renderSecurity(s) {
    const defaults = s.defaults || {}
    const values = securityFormDraft || {
      session_timeout_minutes: Number(s.session_timeout_minutes ?? defaults.session_timeout_minutes ?? 60),
      min_password_length: Number(s.min_password_length ?? defaults.min_password_length ?? 8),
      max_login_attempts: Number(s.max_login_attempts ?? defaults.max_login_attempts ?? 5),
      account_lockout_minutes: Number(s.account_lockout_minutes ?? defaults.account_lockout_minutes ?? 30),
    }

    const fields = SECURITY_ITEMS.map((item) =>
      securityNumberField(
        item.key,
        item.label,
        values[item.key],
        item.min,
        item.max,
        item.suffix,
        item.hint,
        securityFormErrors[item.key],
      ),
    ).join('')

    return `
      <article class="sys-config__card sys-config__card--wide" data-section="security">
        <div class="sys-config__card-head">
          <div class="sys-config__card-icon">${ICONS.security}</div>
          <div>
            <h2 class="sys-config__card-title">Security Settings</h2>
            <p class="sys-config__card-desc">Configure session lifetime, password requirements, and account lockout after failed sign-in attempts.</p>
          </div>
        </div>
        <div class="sys-config__card-body">
          <div class="sys-config__banner sys-config__banner--info">Administrator-only. Changes are stored on the server and enforced at sign-in. No passwords, hashes, or tokens are ever displayed here.</div>
          <div class="sys-config__security-grid">${fields}</div>
        </div>
        <div class="sys-config__card-foot">
          <button type="button" class="sys-config__btn sys-config__btn--primary" data-action="save-security" ${sectionState.security === 'saving' ? 'disabled' : ''}>
            ${sectionState.security === 'saving' ? 'Saving…' : 'Save Changes'}
          </button>
          ${sectionStatus('security')}
        </div>
      </article>`
  }

  function render() {
    const user = getCurrentUser()
    const denied = user && user.role && user.role !== 'Admin'

    if (denied) {
      root.innerHTML = `
        <div class="sys-config sys-config__page">
          <div class="sys-config__banner sys-config__banner--error">Administrator access required. System Configuration is only available to administrators.</div>
        </div>`
      return
    }

    if (loading) {
      root.innerHTML = `
        <div class="sys-config sys-config__page">
          <div class="sys-config__loading">
            <div class="sys-config__spinner"></div>
            <span>Loading system settings…</span>
          </div>
        </div>`
      return
    }

    if (loadError) {
      root.innerHTML = `
        <div class="sys-config sys-config__page">
          <div class="sys-config__banner sys-config__banner--error">${escapeHtml(loadError)}</div>
          <button type="button" class="sys-config__btn sys-config__btn--primary" data-action="refresh">Retry</button>
        </div>`
      root.querySelector('[data-action="refresh"]')?.addEventListener('click', () => loadConfig())
      return
    }

    if (!config) return

    const g = config.general || {}
    const n = config.notifications || {}
    const ai = config.ai_evaluation || {}
    const m = config.media || {}
    const s = config.security || {}

    root.innerHTML = `
      <div class="sys-config sys-config__page">
        <header class="sys-config__header">
          <div>
            <h1 class="sys-config__title">System Configuration</h1>
            <p class="sys-config__subtitle">Configure system-wide settings and administrative preferences for ACCESS VisionCheck.</p>
          </div>
          <div class="sys-config__header-actions">
            <button type="button" class="sys-config__btn sys-config__btn--ghost" data-action="refresh">${ICONS.refresh} Refresh</button>
          </div>
        </header>
        <div class="sys-config__layout">
          ${renderNavigation()}
          <main class="sys-config__panel">
            ${renderUnsavedBanner()}
            ${renderActiveSectionContent(g, n, ai, m, s)}
          </main>
        </div>
      </div>
      ${renderSecurityConfirmModal()}`

    bindEvents()
  }

  loadConfig()
  window.addEventListener('hashchange', onHashChange)
  if (!window.location.hash) updateSectionHash(activeSection)

  return () => {
    window.removeEventListener('hashchange', onHashChange)
    if (toastTimer) clearTimeout(toastTimer)
    root.innerHTML = ''
  }
}

if (typeof window !== 'undefined') {
  window.initSystemConfiguration = initSystemConfiguration
}
