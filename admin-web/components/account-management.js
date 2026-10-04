/**
 * ACCESS VisionCheck — Account Management (vanilla JS)
 * Initialize with initAccountManagement(rootElement, options).
 */

const PAGE_SIZE = 10
const ROLES = ['Admin', 'Member', 'Organization']
const SKILL_LEVELS = ['Novice', 'Beginner', 'Intermediate', 'Advanced', 'Expert', 'Master']
const CREATE_STATUSES = [
  { value: 'active', label: 'Active', api: 'approved' },
  { value: 'inactive', label: 'Inactive', api: 'pending' },
  { value: 'suspended', label: 'Suspended', api: 'rejected' },
]

/** @typedef {{ user_id: number, name: string, email: string, role: string, status: string, is_active?: boolean, skill_level?: string | null, created_at?: string | null, removed_at?: string | null, student_id?: string | null, contact_number?: string | null, profile_image?: string | null, last_active?: string | null, assigned_tasks?: number, completed_tasks?: number, primary_task_role?: string | null }} AdminUser */

/** @typedef {{ kind: string, label: string, detail?: string | null, occurred_at?: string | null }} ProfileActivity */

/**
 * @param {AdminUser} user
 */
function accountStatusKey(user) {
  if (user.removed_at || user.is_active === false) return 'inactive'
  const s = String(user.status || '').toLowerCase()
  if (s === 'rejected' || s === 'suspended') return 'suspended'
  if (s === 'approved') return 'active'
  return 'inactive'
}

/**
 * @param {string} key
 */
function statusLabel(key) {
  switch (key) {
    case 'active':
      return 'Active'
    case 'suspended':
      return 'Suspended'
    default:
      return 'Inactive'
  }
}

/**
 * @param {string} role
 */
function roleLabel(role) {
  switch (role) {
    case 'Admin':
      return 'System Administrator'
    case 'Organization':
      return 'Admin / Officer'
    default:
      return role || 'Member'
  }
}

function formatDateTime(raw) {
  if (!raw) return '—'
  const d = new Date(String(raw))
  if (Number.isNaN(d.getTime())) return '—'
  return d.toLocaleString(undefined, {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  })
}

/**
 * @param {string} apiBase
 * @param {string | null | undefined} path
 */
function resolveMediaUrl(apiBase, path) {
  if (!path) return ''
  if (path.startsWith('http://') || path.startsWith('https://')) return path
  const normalized = path.startsWith('/') ? path : `/${path}`
  const origin = apiBase.replace(/\/api\/?$/, '')
  return `${origin}${normalized}`
}

/**
 * @param {string | null | undefined} raw
 */
function formatDate(raw) {
  if (!raw) return '—'
  const d = new Date(String(raw))
  if (Number.isNaN(d.getTime())) return '—'
  return d.toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' })
}

/**
 * @param {string} apiBase
 * @param {() => string | null} getToken
 * @param {string} path
 * @param {RequestInit} [init]
 */
async function apiFetch(apiBase, getToken, path, init = {}) {
  const headers = new Headers(init.headers)
  if (!headers.has('Content-Type') && init.body) headers.set('Content-Type', 'application/json')
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
    const msg =
      data && typeof data === 'object' && 'detail' in data ? String(data.detail) : `Request failed (${res.status})`
    throw new Error(msg)
  }
  return data
}

/**
 * @param {HTMLElement} root
 * @param {{ apiBase?: string, getToken?: () => string | null }} [options]
 */
export function initAccountManagement(root, options = {}) {
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

  /** @type {AdminUser[]} */
  let allUsers = []
  let search = ''
  let roleFilter = 'all'
  let statusFilter = 'all'
  let page = 1
  let loading = false
  let error = null
  /** @type {number | null} */
  let openMenuId = null
  /** @type {{ userId: number | null, loading: boolean, error: string | null, user: AdminUser | null, activity: ProfileActivity[] }} */
  let profileView = { userId: null, loading: false, error: null, user: null, activity: [] }
  let showAddModal = false
  /** @type {{ name: string, email: string, role: string, skillLevel: string, accountStatus: string }} */
  let addForm = { name: '', email: '', role: 'Member', skillLevel: 'Novice', accountStatus: 'active' }
  /** @type {Record<string, string>} */
  let addFormErrors = {}
  let addFormSaving = false
  /** @type {string | null} */
  let addFormApiError = null
  /** @type {AdminUser | null} */
  let editUser = null
  /** @type {{ name: string, email: string, role: string, skillLevel: string, accountStatus: string }} */
  let editForm = { name: '', email: '', role: 'Member', skillLevel: 'Novice', accountStatus: 'active' }
  /** @type {Record<string, string>} */
  let editFormErrors = {}
  let editFormSaving = false
  /** @type {string | null} */
  let editFormApiError = null
  /** @type {{ kind: string, user: AdminUser, role?: string, loading?: boolean, error?: string | null, temporaryPassword?: string } | null} */
  let actionModal = null

  function resetAddForm() {
    addForm = { name: '', email: '', role: 'Member', skillLevel: 'Novice', accountStatus: 'active' }
    addFormErrors = {}
    addFormSaving = false
    addFormApiError = null
  }

  function closeProfile() {
    profileView = { userId: null, loading: false, error: null, user: null, activity: [] }
    render()
  }

  /**
   * @param {number} userId
   */
  async function openProfile(userId) {
    openMenuId = null
    profileView = { userId, loading: true, error: null, user: null, activity: [] }
    render()
    try {
      const data = await apiFetch(apiBase, getToken, `/users/${userId}/profile`)
      profileView = {
        userId,
        loading: false,
        error: null,
        user: /** @type {AdminUser} */ (data),
        activity: Array.isArray(data.recent_activity) ? data.recent_activity : [],
      }
    } catch (err) {
      profileView = {
        userId,
        loading: false,
        error: err instanceof Error ? err.message : 'Failed to load profile',
        user: null,
        activity: [],
      }
    }
    render()
  }

  function openEditFromProfile() {
    const u = profileView.user
    if (!u) return
    closeProfile()
    openEditModal(u)
  }

  function openAddModal() {
    resetAddForm()
    showAddModal = true
    render()
  }

  function closeAddModal() {
    if (addFormSaving) return
    showAddModal = false
    resetAddForm()
    render()
  }

  /**
   * @param {AdminUser} user
   */
  function uiStatusFromUser(user) {
    return accountStatusKey(user)
  }

  /**
   * @param {AdminUser[]} users
   */
  function countActiveAdmins(users) {
    return users.filter((u) => u.role === 'Admin' && accountStatusKey(u) === 'active').length
  }

  /**
   * @param {AdminUser} user
   * @param {AdminUser[]} users
   */
  function isProtectedAdmin(user, users) {
    return user.role === 'Admin' && countActiveAdmins(users) <= 1
  }

  /**
   * @param {AdminUser} user
   */
  function openEditModal(user) {
    editUser = user
    editForm = {
      name: user.name,
      email: user.email,
      role: user.role,
      skillLevel: user.skill_level && SKILL_LEVELS.includes(user.skill_level) ? user.skill_level : 'Novice',
      accountStatus: uiStatusFromUser(user),
    }
    editFormErrors = {}
    editFormSaving = false
    editFormApiError = null
    render()
  }

  function closeActionModal() {
    if (actionModal?.loading) return
    actionModal = null
    render()
  }

  function closeEditModal() {
    if (editFormSaving) return
    editUser = null
    editFormErrors = {}
    editFormApiError = null
    render()
  }

  /**
   * @param {AdminUser} user
   */
  function canChangePrivilegedFields(user) {
    return !isProtectedAdmin(user, allUsers)
  }

  /**
   * @param {string} action
   * @param {number} userId
   * @param {string} icon
   * @param {string} label
   * @param {{ danger?: boolean, disabled?: boolean, title?: string }} [opts]
   */
  function menuItem(action, userId, icon, label, opts = {}) {
    const danger = opts.danger ? ' account-mgmt__menu-item--danger' : ''
    const disabled = opts.disabled ? ' disabled aria-disabled="true"' : ''
    const title = opts.title ? ` title="${escapeAttr(opts.title)}"` : ''
    return `
      <button type="button" role="menuitem" class="account-mgmt__menu-item${danger}" data-action="${action}" data-user-id="${userId}"${disabled}${title}>
        <i data-lucide="${icon}" class="account-mgmt__menu-icon" aria-hidden="true"></i>
        <span>${escapeHtml(label)}</span>
      </button>`
  }

  root.classList.add('account-mgmt')
  root.setAttribute('data-account-management', '')

  function render() {
    const filtered = allUsers.filter((u) => {
      const q = search.trim().toLowerCase()
      if (roleFilter !== 'all' && u.role !== roleFilter) return false
      if (statusFilter !== 'all' && accountStatusKey(u) !== statusFilter) return false
      if (!q) return true
      return u.name.toLowerCase().includes(q) || u.email.toLowerCase().includes(q)
    })

    const totalPages = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE))
    if (page > totalPages) page = totalPages
    const start = (page - 1) * PAGE_SIZE
    const pageRows = filtered.slice(start, start + PAGE_SIZE)

    root.innerHTML = `
      <div class="account-mgmt__page">
        <header class="account-mgmt__header">
          <div class="account-mgmt__header-text">
            <h1 class="account-mgmt__title">Account Management</h1>
            <p class="account-mgmt__subtitle">Manage users, roles, and account access.</p>
          </div>
          <button type="button" class="account-mgmt__btn account-mgmt__btn--primary" data-action="add-account">
            <i data-lucide="user-plus" aria-hidden="true"></i>
            Add Account
          </button>
        </header>

        <div class="account-mgmt__toolbar">
          <div class="account-mgmt__search-wrap">
            <i data-lucide="search" class="account-mgmt__search-icon" aria-hidden="true"></i>
            <input
              type="search"
              class="account-mgmt__search"
              placeholder="Search name or email…"
              value="${escapeAttr(search)}"
              data-input="search"
              aria-label="Search users"
            />
          </div>
          <div class="account-mgmt__filters">
            <label class="account-mgmt__filter">
              <span class="account-mgmt__filter-label">Role</span>
              <select class="account-mgmt__select" data-filter="role">
                <option value="all"${roleFilter === 'all' ? ' selected' : ''}>All roles</option>
                ${ROLES.map((r) => `<option value="${r}"${roleFilter === r ? ' selected' : ''}>${escapeHtml(roleLabel(r))}</option>`).join('')}
              </select>
            </label>
            <label class="account-mgmt__filter">
              <span class="account-mgmt__filter-label">Status</span>
              <select class="account-mgmt__select" data-filter="status">
                <option value="all"${statusFilter === 'all' ? ' selected' : ''}>All statuses</option>
                <option value="active"${statusFilter === 'active' ? ' selected' : ''}>Active</option>
                <option value="inactive"${statusFilter === 'inactive' ? ' selected' : ''}>Inactive</option>
                <option value="suspended"${statusFilter === 'suspended' ? ' selected' : ''}>Suspended</option>
              </select>
            </label>
            <button type="button" class="account-mgmt__btn account-mgmt__btn--ghost" data-action="refresh" ${loading ? 'disabled' : ''}>
              <i data-lucide="refresh-cw" class="${loading ? 'account-mgmt__spin' : ''}" aria-hidden="true"></i>
              Refresh
            </button>
          </div>
        </div>

        ${error ? `<div class="account-mgmt__alert account-mgmt__alert--error" role="alert">${escapeHtml(error)}</div>` : ''}

        <div class="account-mgmt__card">
          ${loading && allUsers.length === 0 ? renderLoading() : filtered.length === 0 ? renderEmpty() : renderTable(pageRows)}
        </div>

        ${
          filtered.length > 0
            ? `
          <footer class="account-mgmt__pagination">
            <span class="account-mgmt__page-info">
              Showing ${start + 1}–${Math.min(start + PAGE_SIZE, filtered.length)} of ${filtered.length}
            </span>
            <div class="account-mgmt__page-btns">
              <button type="button" class="account-mgmt__btn account-mgmt__btn--ghost" data-page="prev" ${page <= 1 ? 'disabled' : ''}>Previous</button>
              <span class="account-mgmt__page-num">Page ${page} of ${totalPages}</span>
              <button type="button" class="account-mgmt__btn account-mgmt__btn--ghost" data-page="next" ${page >= totalPages ? 'disabled' : ''}>Next</button>
            </div>
          </footer>`
            : ''
        }

        ${profileView.userId != null ? renderProfileModal(profileView) : ''}
        ${showAddModal ? renderAddModal() : ''}
        ${editUser ? renderEditModal(editUser) : ''}
        ${actionModal ? renderActionModal(actionModal) : ''}
        ${openMenuId != null ? `<div class="account-mgmt__menu-backdrop" data-action="close-menu"></div>` : ''}
      </div>
    `

    refreshIcons(root)
    bindEvents()
    if (showAddModal) bindAddFormEvents()
    if (editUser) bindEditFormEvents()
  }

  function renderLoading() {
    return `
      <div class="account-mgmt__state account-mgmt__state--loading">
        <i data-lucide="loader-circle" class="account-mgmt__spin account-mgmt__state-icon" aria-hidden="true"></i>
        <p>Loading accounts…</p>
      </div>
    `
  }

  function renderEmpty() {
    return `
      <div class="account-mgmt__state account-mgmt__state--empty">
        <i data-lucide="users" class="account-mgmt__state-icon" aria-hidden="true"></i>
        <p class="account-mgmt__state-title">No users found</p>
        <p class="account-mgmt__state-desc">${search || roleFilter !== 'all' || statusFilter !== 'all' ? 'Try adjusting your search or filters.' : 'Add the first account to get started.'}</p>
        <button type="button" class="account-mgmt__btn account-mgmt__btn--primary" data-action="add-account">+ Add Account</button>
      </div>
    `
  }

  /**
   * @param {AdminUser[]} rows
   */
  function renderTable(rows) {
    return `
      <div class="account-mgmt__table-wrap">
        <table class="account-mgmt__table">
          <thead>
            <tr>
              <th>Name</th>
              <th>Email</th>
              <th>Role</th>
              <th>Skill Level</th>
              <th>Status</th>
              <th>Date Joined</th>
              <th class="account-mgmt__th-actions">Actions</th>
            </tr>
          </thead>
          <tbody>
            ${rows.map((u) => renderRow(u)).join('')}
          </tbody>
        </table>
      </div>
    `
  }

  /**
   * @param {AdminUser} u
   */
  function renderRow(u) {
    const sk = accountStatusKey(u)
    const menuOpen = openMenuId === u.user_id
    const protectedAdmin = !canChangePrivilegedFields(u)
    const activateLabel = sk === 'active' ? 'Deactivate Account' : 'Activate Account'
    const initials = u.name
      .split(/\s+/)
      .map((p) => p[0])
      .join('')
      .slice(0, 2)
      .toUpperCase()
    return `
      <tr data-user-id="${u.user_id}">
        <td>
          <div class="account-mgmt__name-cell">
            <span class="account-mgmt__avatar" aria-hidden="true">${escapeHtml(initials || '?')}</span>
            <span class="account-mgmt__name">${escapeHtml(u.name)}</span>
          </div>
        </td>
        <td class="account-mgmt__email">${escapeHtml(u.email)}</td>
        <td>${roleBadge(u.role)}</td>
        <td>${escapeHtml(u.skill_level || '—')}</td>
        <td>${statusBadge(sk)}</td>
        <td>${formatDate(u.created_at)}</td>
        <td class="account-mgmt__actions-cell">
          <div class="account-mgmt__menu-wrap">
            <button
              type="button"
              class="account-mgmt__menu-trigger${menuOpen ? ' account-mgmt__menu-trigger--open' : ''}"
              data-action="toggle-menu"
              data-user-id="${u.user_id}"
              aria-label="Actions for ${escapeAttr(u.name)}"
              aria-expanded="${menuOpen}"
              aria-haspopup="menu"
            >
              <i data-lucide="more-vertical" aria-hidden="true"></i>
            </button>
            ${
              menuOpen
                ? `
              <div class="account-mgmt__menu" role="menu" aria-label="Account actions">
                ${menuItem('view-profile', u.user_id, 'user', 'View Profile')}
                ${menuItem('edit-account', u.user_id, 'user-cog', 'Edit Account')}
                ${menuItem(
                  'change-role',
                  u.user_id,
                  'shield',
                  'Change Role',
                  protectedAdmin
                    ? { disabled: true, title: 'Cannot change role for the last active administrator.' }
                    : {},
                )}
                ${menuItem('reset-password', u.user_id, 'key-round', 'Reset Password')}
                <hr class="account-mgmt__menu-divider" />
                ${menuItem(
                  'toggle-active',
                  u.user_id,
                  sk === 'active' ? 'user-x' : 'user-check',
                  activateLabel,
                  {
                    danger: sk === 'active',
                    disabled: protectedAdmin && sk === 'active',
                    title:
                      protectedAdmin && sk === 'active'
                        ? 'Cannot deactivate the last active administrator.'
                        : undefined,
                  },
                )}
              </div>`
                : ''
            }
          </div>
        </td>
      </tr>
    `
  }

  /**
   * @param {string} role
   */
  function roleBadge(role) {
    const cls =
      role === 'Admin' ? 'account-mgmt__badge--admin' : role === 'Organization' ? 'account-mgmt__badge--org' : 'account-mgmt__badge--member'
    return `<span class="account-mgmt__badge ${cls}">${escapeHtml(roleLabel(role))}</span>`
  }

  /**
   * @param {string} key
   */
  function statusBadge(key) {
    const cls =
      key === 'active' ? 'account-mgmt__badge--active' : key === 'suspended' ? 'account-mgmt__badge--suspended' : 'account-mgmt__badge--inactive'
    return `<span class="account-mgmt__badge ${cls}">${statusLabel(key)}</span>`
  }

  /**
   * @param {{ kind: string, user: AdminUser, role?: string, loading?: boolean, error?: string | null, temporaryPassword?: string }} modal
   */
  function renderActionModal(modal) {
    const u = modal.user
    const loading = modal.loading === true
    const err = modal.error

    if (modal.kind === 'reset-success') {
      return `
        <div class="account-mgmt__modal-backdrop" data-action="close-action">
          <div class="account-mgmt__modal account-mgmt__modal--form" role="dialog" aria-labelledby="reset-success-title" aria-modal="true" onclick="event.stopPropagation()">
            <div class="account-mgmt__modal-header">
              <h2 id="reset-success-title">Password Reset</h2>
              <button type="button" class="account-mgmt__modal-close" data-action="close-action" aria-label="Close">
                <i data-lucide="x" aria-hidden="true"></i>
              </button>
            </div>
            <div class="account-mgmt__modal-body">
              <p class="account-mgmt__confirm-text">Temporary password for <strong>${escapeHtml(u.name)}</strong>. Copy it now — it won&apos;t be shown again.</p>
              <div class="account-mgmt__temp-password">${escapeHtml(modal.temporaryPassword || '')}</div>
            </div>
            <div class="account-mgmt__modal-footer">
              <button type="button" class="account-mgmt__btn account-mgmt__btn--primary" data-action="close-action">Done</button>
            </div>
          </div>
        </div>
      `
    }

    if (modal.kind === 'change-role') {
      const role = modal.role || u.role
      return `
        <div class="account-mgmt__modal-backdrop" data-action="close-action">
          <div class="account-mgmt__modal account-mgmt__modal--form" role="dialog" aria-labelledby="change-role-title" aria-modal="true" onclick="event.stopPropagation()">
            <div class="account-mgmt__modal-header">
              <h2 id="change-role-title">Change Role</h2>
              <button type="button" class="account-mgmt__modal-close" data-action="close-action" aria-label="Close" ${loading ? 'disabled' : ''}>
                <i data-lucide="x" aria-hidden="true"></i>
              </button>
            </div>
            ${err ? `<div class="account-mgmt__form-alert" role="alert">${escapeHtml(err)}</div>` : ''}
            <div class="account-mgmt__modal-body">
              <p class="account-mgmt__confirm-text">Update role for <strong>${escapeHtml(u.name)}</strong></p>
              <label class="account-mgmt__field">
                <span>Role</span>
                <select data-action="action-role-select" ${loading ? 'disabled' : ''}>
                  ${ROLES.map((r) => `<option value="${r}"${role === r ? ' selected' : ''}>${escapeHtml(roleLabel(r))}</option>`).join('')}
                </select>
              </label>
            </div>
            <div class="account-mgmt__modal-footer">
              <button type="button" class="account-mgmt__btn account-mgmt__btn--ghost" data-action="close-action" ${loading ? 'disabled' : ''}>Cancel</button>
              <button type="button" class="account-mgmt__btn account-mgmt__btn--primary" data-action="confirm-action" ${loading ? 'disabled' : ''}>
                ${loading ? '<span class="account-mgmt__btn-spinner account-mgmt__spin" aria-hidden="true"></span> Saving…' : 'Save Role'}
              </button>
            </div>
          </div>
        </div>
      `
    }

    const configs = {
      'confirm-deactivate': {
        title: 'Deactivate Account',
        text: `Deactivate <strong>${escapeHtml(u.name)}</strong>? They will not be able to sign in until reactivated.`,
        confirm: 'Deactivate Account',
        danger: true,
      },
      'confirm-activate': {
        title: 'Activate Account',
        text: `Activate <strong>${escapeHtml(u.name)}</strong>? They will be able to sign in again.`,
        confirm: 'Activate Account',
        danger: false,
      },
      'confirm-reset-password': {
        title: 'Reset Password',
        text: `Reset password for <strong>${escapeHtml(u.name)}</strong>? A new temporary password will be generated.`,
        confirm: 'Reset Password',
        danger: true,
      },
    }
    const cfg = configs[/** @type {keyof typeof configs} */ (modal.kind)]
    if (!cfg) return ''

    return `
      <div class="account-mgmt__modal-backdrop" data-action="close-action">
        <div class="account-mgmt__modal account-mgmt__modal--form" role="dialog" aria-labelledby="action-title" aria-modal="true" onclick="event.stopPropagation()">
          <div class="account-mgmt__modal-header">
            <h2 id="action-title">${cfg.title}</h2>
            <button type="button" class="account-mgmt__modal-close" data-action="close-action" aria-label="Close" ${loading ? 'disabled' : ''}>
              <i data-lucide="x" aria-hidden="true"></i>
            </button>
          </div>
          ${err ? `<div class="account-mgmt__form-alert" role="alert">${escapeHtml(err)}</div>` : ''}
          <div class="account-mgmt__modal-body">
            <p class="account-mgmt__confirm-text">${cfg.text}</p>
          </div>
          <div class="account-mgmt__modal-footer">
            <button type="button" class="account-mgmt__btn account-mgmt__btn--ghost" data-action="close-action" ${loading ? 'disabled' : ''}>Cancel</button>
            <button type="button" class="account-mgmt__btn ${cfg.danger ? 'account-mgmt__btn--danger' : 'account-mgmt__btn--primary'}" data-action="confirm-action" ${loading ? 'disabled' : ''}>
              ${loading ? '<span class="account-mgmt__btn-spinner account-mgmt__spin" aria-hidden="true"></span> Working…' : cfg.confirm}
            </button>
          </div>
        </div>
      </div>
    `
  }

  /**
   * @param {{ userId: number | null, loading: boolean, error: string | null, user: AdminUser | null, activity: ProfileActivity[] }} view
   */
  function renderProfileModal(view) {
    const loading = view.loading
    const err = view.error
    const u = view.user
    const activity = view.activity || []

    return `
      <div class="account-mgmt__modal-backdrop" data-action="close-profile">
        <div class="account-mgmt__modal account-mgmt__modal--profile" role="dialog" aria-labelledby="profile-title" aria-modal="true" onclick="event.stopPropagation()">
          <div class="account-mgmt__modal-header">
            <h2 id="profile-title">User Profile</h2>
            <button type="button" class="account-mgmt__modal-close" data-action="close-profile" aria-label="Close">
              <i data-lucide="x" aria-hidden="true"></i>
            </button>
          </div>
          <div class="account-mgmt__modal-body account-mgmt__profile-body">
            ${
              loading
                ? `
              <div class="account-mgmt__profile-loading">
                <i data-lucide="loader-circle" class="account-mgmt__spin account-mgmt__state-icon" aria-hidden="true"></i>
                <p>Loading profile…</p>
              </div>`
                : err
                  ? `
              <div class="account-mgmt__profile-error">
                <i data-lucide="alert-circle" class="account-mgmt__state-icon" aria-hidden="true"></i>
                <p class="account-mgmt__state-title">Could not load profile</p>
                <p class="account-mgmt__state-desc">${escapeHtml(err)}</p>
                <button type="button" class="account-mgmt__btn account-mgmt__btn--ghost" data-action="retry-profile">Try again</button>
              </div>`
                  : u
                    ? renderProfileContent(u, activity)
                    : ''
            }
          </div>
          ${
            u && !loading
              ? `
            <div class="account-mgmt__modal-footer">
              <button type="button" class="account-mgmt__btn account-mgmt__btn--ghost" data-action="close-profile">Close</button>
              <button type="button" class="account-mgmt__btn account-mgmt__btn--primary" data-action="profile-edit">
                <i data-lucide="user-cog" aria-hidden="true"></i>
                Edit Account
              </button>
            </div>`
              : `
            <div class="account-mgmt__modal-footer">
              <button type="button" class="account-mgmt__btn account-mgmt__btn--ghost" data-action="close-profile">Close</button>
            </div>`
          }
        </div>
      </div>
    `
  }

  /**
   * @param {AdminUser} u
   * @param {ProfileActivity[]} activity
   */
  function renderProfileContent(u, activity) {
    const avatarUrl = resolveMediaUrl(apiBase, u.profile_image)
    const initials = u.name
      .split(/\s+/)
      .map((p) => p[0])
      .join('')
      .slice(0, 2)
      .toUpperCase()
    const sk = accountStatusKey(u)

    return `
      <div class="account-mgmt__profile-card">
        <div class="account-mgmt__profile-hero">
          ${
            avatarUrl
              ? `<img src="${escapeAttr(avatarUrl)}" alt="" class="account-mgmt__profile-avatar account-mgmt__profile-avatar--img" />`
              : `<div class="account-mgmt__profile-avatar" aria-hidden="true">${escapeHtml(initials || '?')}</div>`
          }
          <div class="account-mgmt__profile-hero-text">
            <h3 class="account-mgmt__profile-name">${escapeHtml(u.name)}</h3>
            <p class="account-mgmt__profile-email">${escapeHtml(u.email)}</p>
            <div class="account-mgmt__profile-badges">
              ${roleBadge(u.role)}
              ${statusBadge(sk)}
            </div>
          </div>
        </div>

        <div class="account-mgmt__profile-grid">
          <div class="account-mgmt__profile-stat">
            <span class="account-mgmt__profile-stat-label">Skill Level</span>
            <span class="account-mgmt__profile-stat-value">${escapeHtml(u.skill_level || '—')}</span>
          </div>
          <div class="account-mgmt__profile-stat">
            <span class="account-mgmt__profile-stat-label">Date Joined</span>
            <span class="account-mgmt__profile-stat-value">${formatDate(u.created_at)}</span>
          </div>
          <div class="account-mgmt__profile-stat">
            <span class="account-mgmt__profile-stat-label">Last Active</span>
            <span class="account-mgmt__profile-stat-value">${formatDateTime(u.last_active)}</span>
          </div>
          <div class="account-mgmt__profile-stat">
            <span class="account-mgmt__profile-stat-label">Tasks Completed</span>
            <span class="account-mgmt__profile-stat-value">${u.completed_tasks ?? 0} / ${u.assigned_tasks ?? 0}</span>
          </div>
        </div>

        ${
          u.primary_task_role
            ? `<p class="account-mgmt__profile-meta"><strong>Primary role:</strong> ${escapeHtml(u.primary_task_role)}</p>`
            : ''
        }
        ${u.student_id ? `<p class="account-mgmt__profile-meta"><strong>Student ID:</strong> ${escapeHtml(u.student_id)}</p>` : ''}
        ${u.contact_number ? `<p class="account-mgmt__profile-meta"><strong>Contact:</strong> ${escapeHtml(u.contact_number)}</p>` : ''}

        <div class="account-mgmt__profile-activity">
          <h4 class="account-mgmt__profile-activity-title">Recent activity</h4>
          ${
            activity.length === 0
              ? `<p class="account-mgmt__profile-activity-empty">No recent login or audit activity recorded.</p>`
              : `<ul class="account-mgmt__activity-list">
                  ${activity
                    .map(
                      (item) => `
                    <li class="account-mgmt__activity-item">
                      <span class="account-mgmt__activity-icon" aria-hidden="true">
                        <i data-lucide="${item.kind === 'login' ? 'log-in' : 'activity'}" aria-hidden="true"></i>
                      </span>
                      <div class="account-mgmt__activity-text">
                        <div class="account-mgmt__activity-label">${escapeHtml(item.label)}</div>
                        ${item.detail ? `<div class="account-mgmt__activity-detail">${escapeHtml(item.detail)}</div>` : ''}
                        <div class="account-mgmt__activity-time">${formatDateTime(item.occurred_at)}</div>
                      </div>
                    </li>`,
                    )
                    .join('')}
                </ul>`
          }
        </div>
      </div>
    `
  }

  function renderAddModal() {
    return `
      <div class="account-mgmt__modal-backdrop" data-action="close-add">
        <div class="account-mgmt__modal account-mgmt__modal--form account-mgmt__modal--wide" role="dialog" aria-labelledby="add-title" aria-modal="true" onclick="event.stopPropagation()">
          <div class="account-mgmt__modal-header">
            <div>
              <h2 id="add-title">Add Account</h2>
              <p class="account-mgmt__modal-subtitle">Create a new user with role, skill level, and access status.</p>
            </div>
            <button type="button" class="account-mgmt__modal-close" data-action="close-add" aria-label="Close" ${addFormSaving ? 'disabled' : ''}>
              <i data-lucide="x" aria-hidden="true"></i>
            </button>
          </div>
          ${
            addFormApiError
              ? `<div class="account-mgmt__form-alert" role="alert">${escapeHtml(addFormApiError)}</div>`
              : ''
          }
          <form class="account-mgmt__form account-mgmt__form--grid" data-form="add-account" novalidate>
            <div class="account-mgmt__field ${addFormErrors.name ? 'has-error' : ''}">
              <label for="add-name">Full Name <span class="account-mgmt__required">*</span></label>
              <input
                id="add-name"
                type="text"
                name="name"
                data-field="name"
                value="${escapeAttr(addForm.name)}"
                autocomplete="name"
                placeholder="e.g. Juan Dela Cruz"
                ${addFormSaving ? 'disabled' : ''}
              />
              ${fieldErrorHtml(addFormErrors, 'name')}
            </div>
            <div class="account-mgmt__field ${addFormErrors.email ? 'has-error' : ''}">
              <label for="add-email">Email Address <span class="account-mgmt__required">*</span></label>
              <input
                id="add-email"
                type="email"
                name="email"
                data-field="email"
                value="${escapeAttr(addForm.email)}"
                autocomplete="email"
                placeholder="name@access.edu"
                ${addFormSaving ? 'disabled' : ''}
              />
              ${fieldErrorHtml(addFormErrors, 'email')}
            </div>
            <div class="account-mgmt__field ${addFormErrors.role ? 'has-error' : ''}">
              <label for="add-role">Role <span class="account-mgmt__required">*</span></label>
              <select id="add-role" name="role" data-field="role" ${addFormSaving ? 'disabled' : ''}>
                ${ROLES.map((r) => `<option value="${r}"${addForm.role === r ? ' selected' : ''}>${escapeHtml(roleLabel(r))}</option>`).join('')}
              </select>
              ${fieldErrorHtml(addFormErrors, 'role')}
            </div>
            <div class="account-mgmt__field ${addFormErrors.skillLevel ? 'has-error' : ''}">
              <label for="add-skill">Skill Level <span class="account-mgmt__required">*</span></label>
              <select id="add-skill" name="skillLevel" data-field="skillLevel" ${addFormSaving ? 'disabled' : ''}>
                ${SKILL_LEVELS.map((s) => `<option value="${s}"${addForm.skillLevel === s ? ' selected' : ''}>${escapeHtml(s)}</option>`).join('')}
              </select>
              ${fieldErrorHtml(addFormErrors, 'skillLevel')}
            </div>
            <div class="account-mgmt__field account-mgmt__field--full ${addFormErrors.accountStatus ? 'has-error' : ''}">
              <label for="add-status">Account Status <span class="account-mgmt__required">*</span></label>
              <select id="add-status" name="accountStatus" data-field="accountStatus" ${addFormSaving ? 'disabled' : ''}>
                ${CREATE_STATUSES.map((s) => `<option value="${s.value}"${addForm.accountStatus === s.value ? ' selected' : ''}>${escapeHtml(s.label)}</option>`).join('')}
              </select>
              ${fieldErrorHtml(addFormErrors, 'accountStatus')}
              <p class="account-mgmt__field-hint">Active users can sign in immediately. Inactive accounts stay pending. Suspended accounts are blocked.</p>
            </div>
            <div class="account-mgmt__modal-footer account-mgmt__field--full">
              <button type="button" class="account-mgmt__btn account-mgmt__btn--ghost" data-action="close-add" ${addFormSaving ? 'disabled' : ''}>Cancel</button>
              <button type="submit" class="account-mgmt__btn account-mgmt__btn--primary" ${addFormSaving ? 'disabled' : ''}>
                ${addFormSaving ? '<span class="account-mgmt__btn-spinner account-mgmt__spin" aria-hidden="true"></span> Creating…' : 'Create Account'}
              </button>
            </div>
          </form>
        </div>
      </div>
    `
  }

  /**
   * @param {AdminUser} user
   */
  function renderEditModal(user) {
    const protectedAdmin = isProtectedAdmin(user, allUsers)
    return `
      <div class="account-mgmt__modal-backdrop" data-action="close-edit">
        <div class="account-mgmt__modal account-mgmt__modal--form account-mgmt__modal--wide" role="dialog" aria-labelledby="edit-title" aria-modal="true" onclick="event.stopPropagation()">
          <div class="account-mgmt__modal-header">
            <div>
              <h2 id="edit-title">Edit Account</h2>
              <p class="account-mgmt__modal-subtitle">Update ${escapeHtml(user.name)}&apos;s profile, role, and access.</p>
            </div>
            <button type="button" class="account-mgmt__modal-close" data-action="close-edit" aria-label="Close" ${editFormSaving ? 'disabled' : ''}>
              <i data-lucide="x" aria-hidden="true"></i>
            </button>
          </div>
          ${
            protectedAdmin
              ? `<div class="account-mgmt__form-alert account-mgmt__form-alert--info" role="status">This is the last active administrator. Role and account status are protected.</div>`
              : ''
          }
          ${
            editFormApiError
              ? `<div class="account-mgmt__form-alert" role="alert">${escapeHtml(editFormApiError)}</div>`
              : ''
          }
          <form class="account-mgmt__form account-mgmt__form--grid" data-form="edit-account" novalidate>
            <div class="account-mgmt__field ${editFormErrors.name ? 'has-error' : ''}">
              <label for="edit-name">Full Name <span class="account-mgmt__required">*</span></label>
              <input id="edit-name" type="text" name="name" data-field="name" value="${escapeAttr(editForm.name)}" autocomplete="name" ${editFormSaving ? 'disabled' : ''} />
              ${fieldErrorHtml(editFormErrors, 'name')}
            </div>
            <div class="account-mgmt__field ${editFormErrors.email ? 'has-error' : ''}">
              <label for="edit-email">Email Address <span class="account-mgmt__required">*</span></label>
              <input id="edit-email" type="email" name="email" data-field="email" value="${escapeAttr(editForm.email)}" autocomplete="email" ${editFormSaving ? 'disabled' : ''} />
              ${fieldErrorHtml(editFormErrors, 'email')}
            </div>
            <div class="account-mgmt__field ${editFormErrors.role ? 'has-error' : ''}">
              <label for="edit-role">Role <span class="account-mgmt__required">*</span></label>
              <select id="edit-role" name="role" data-field="role" ${editFormSaving || protectedAdmin ? 'disabled' : ''}>
                ${ROLES.map((r) => `<option value="${r}"${editForm.role === r ? ' selected' : ''}>${escapeHtml(roleLabel(r))}</option>`).join('')}
              </select>
              ${fieldErrorHtml(editFormErrors, 'role')}
            </div>
            <div class="account-mgmt__field ${editFormErrors.skillLevel ? 'has-error' : ''}">
              <label for="edit-skill">Skill Level <span class="account-mgmt__required">*</span></label>
              <select id="edit-skill" name="skillLevel" data-field="skillLevel" ${editFormSaving ? 'disabled' : ''}>
                ${SKILL_LEVELS.map((s) => `<option value="${s}"${editForm.skillLevel === s ? ' selected' : ''}>${escapeHtml(s)}</option>`).join('')}
              </select>
              ${fieldErrorHtml(editFormErrors, 'skillLevel')}
            </div>
            <div class="account-mgmt__field account-mgmt__field--full ${editFormErrors.accountStatus ? 'has-error' : ''}">
              <label for="edit-status">Account Status <span class="account-mgmt__required">*</span></label>
              <select id="edit-status" name="accountStatus" data-field="accountStatus" ${editFormSaving || protectedAdmin ? 'disabled' : ''}>
                ${CREATE_STATUSES.map((s) => `<option value="${s.value}"${editForm.accountStatus === s.value ? ' selected' : ''}>${escapeHtml(s.label)}</option>`).join('')}
              </select>
              ${fieldErrorHtml(editFormErrors, 'accountStatus')}
            </div>
            <div class="account-mgmt__modal-footer account-mgmt__field--full">
              <button type="button" class="account-mgmt__btn account-mgmt__btn--ghost" data-action="close-edit" ${editFormSaving ? 'disabled' : ''}>Cancel</button>
              <button type="submit" class="account-mgmt__btn account-mgmt__btn--primary" ${editFormSaving ? 'disabled' : ''}>
                ${editFormSaving ? '<span class="account-mgmt__btn-spinner account-mgmt__spin" aria-hidden="true"></span> Saving…' : 'Save Changes'}
              </button>
            </div>
          </form>
        </div>
      </div>
    `
  }

  /**
   * @param {Record<string, string>} errors
   * @param {string} field
   */
  function fieldErrorHtml(errors, field) {
    const msg = errors[field]
    if (!msg) return '<span class="account-mgmt__field-error" aria-live="polite"></span>'
    return `<span class="account-mgmt__field-error" role="alert">${escapeHtml(msg)}</span>`
  }

  /**
   * @param {AdminUser[]} users
   * @param {{ name: string, email: string, role: string, skillLevel: string, accountStatus: string }} form
   * @param {number | null} [excludeUserId]
   */
  function validateAccountForm(users, form, excludeUserId = null) {
    /** @type {Record<string, string>} */
    const errors = {}
    const name = form.name.trim()
    const email = form.email.trim()

    if (!name) errors.name = 'Full name is required.'
    else if (name.length < 2) errors.name = 'Full name must be at least 2 characters.'

    if (!email) errors.email = 'Email address is required.'
    else if (!isValidEmail(email)) errors.email = 'Enter a valid email address.'
    else if (isDuplicateEmail(users, email, excludeUserId)) errors.email = 'This email is already registered.'

    if (!form.role || !ROLES.includes(form.role)) errors.role = 'Select a valid role.'

    if (!form.skillLevel || !SKILL_LEVELS.includes(form.skillLevel)) {
      errors.skillLevel = 'Select a skill level.'
    }

    if (!form.accountStatus || !CREATE_STATUSES.some((s) => s.value === form.accountStatus)) {
      errors.accountStatus = 'Select an account status.'
    }

    return errors
  }

  /**
   * @param {AdminUser[]} users
   * @param {typeof addForm} form
   */
  function validateAddForm(users, form) {
    return validateAccountForm(users, form)
  }

  /**
   * @param {AdminUser[]} users
   * @param {typeof editForm} form
   * @param {number} userId
   */
  function validateEditForm(users, form, userId) {
    return validateAccountForm(users, form, userId)
  }

  /**
   * @param {string} email
   */
  function isValidEmail(email) {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())
  }

  /**
   * @param {AdminUser[]} users
   * @param {string} email
   * @param {number | null} [excludeUserId]
   */
  function isDuplicateEmail(users, email, excludeUserId = null) {
    const norm = email.trim().toLowerCase()
    return users.some((u) => {
      if (excludeUserId != null && u.user_id === excludeUserId) return false
      return String(u.email || '').toLowerCase() === norm
    })
  }

  /**
   * @param {string} uiStatus
   */
  function mapStatusToApi(uiStatus) {
    return CREATE_STATUSES.find((s) => s.value === uiStatus)?.api || 'pending'
  }

  function syncAddFormFromDom() {
    const form = root.querySelector('[data-form="add-account"]')
    if (!form) return
    /** @type {HTMLInputElement | null} */
    const nameEl = form.querySelector('[data-field="name"]')
    /** @type {HTMLInputElement | null} */
    const emailEl = form.querySelector('[data-field="email"]')
    /** @type {HTMLSelectElement | null} */
    const roleEl = form.querySelector('[data-field="role"]')
    /** @type {HTMLSelectElement | null} */
    const skillEl = form.querySelector('[data-field="skillLevel"]')
    /** @type {HTMLSelectElement | null} */
    const statusEl = form.querySelector('[data-field="accountStatus"]')
    addForm = {
      name: nameEl?.value ?? addForm.name,
      email: emailEl?.value ?? addForm.email,
      role: roleEl?.value ?? addForm.role,
      skillLevel: skillEl?.value ?? addForm.skillLevel,
      accountStatus: statusEl?.value ?? addForm.accountStatus,
    }
  }

  function bindAddFormEvents() {
    bindAccountFormEvents('add-account', {
      syncFromDom: syncAddFormFromDom,
      getErrors: () => addFormErrors,
      setErrors: (e) => {
        addFormErrors = e
      },
      clearApiError: () => {
        if (addFormApiError) addFormApiError = null
      },
      validate: () => validateAddForm(allUsers, addForm),
    })
  }

  function syncEditFormFromDom() {
    const form = root.querySelector('[data-form="edit-account"]')
    if (!form) return
    /** @type {HTMLInputElement | null} */
    const nameEl = form.querySelector('[data-field="name"]')
    /** @type {HTMLInputElement | null} */
    const emailEl = form.querySelector('[data-field="email"]')
    /** @type {HTMLSelectElement | null} */
    const roleEl = form.querySelector('[data-field="role"]')
    /** @type {HTMLSelectElement | null} */
    const skillEl = form.querySelector('[data-field="skillLevel"]')
    /** @type {HTMLSelectElement | null} */
    const statusEl = form.querySelector('[data-field="accountStatus"]')
    editForm = {
      name: nameEl?.value ?? editForm.name,
      email: emailEl?.value ?? editForm.email,
      role: roleEl?.value ?? editForm.role,
      skillLevel: skillEl?.value ?? editForm.skillLevel,
      accountStatus: statusEl?.value ?? editForm.accountStatus,
    }
  }

  function bindEditFormEvents() {
    bindAccountFormEvents('edit-account', {
      syncFromDom: syncEditFormFromDom,
      getErrors: () => editFormErrors,
      setErrors: (e) => {
        editFormErrors = e
      },
      clearApiError: () => {
        if (editFormApiError) editFormApiError = null
      },
      validate: () => (editUser ? validateEditForm(allUsers, editForm, editUser.user_id) : {}),
    })

    root.querySelector('[data-form="edit-account"]')?.addEventListener('submit', (e) => {
      e.preventDefault()
      handleSaveEdit()
    })
  }

  /**
   * @param {string} formName
   * @param {{ syncFromDom: () => void, getErrors: () => Record<string, string>, setErrors: (e: Record<string, string>) => void, clearApiError: () => void, validate: () => Record<string, string> }} opts
   */
  function bindAccountFormEvents(formName, opts) {
    const form = root.querySelector(`[data-form="${formName}"]`)
    if (!form) return

    form.querySelectorAll('[data-field]').forEach((el) => {
      el.addEventListener('input', () => {
        opts.syncFromDom()
        const field = /** @type {HTMLElement} */ (el).dataset.field
        const errors = opts.getErrors()
        if (field && errors[field]) {
          delete errors[field]
          opts.setErrors(errors)
          render()
        } else {
          opts.clearApiError()
          render()
        }
      })
      el.addEventListener('change', () => {
        opts.syncFromDom()
        const field = /** @type {HTMLElement} */ (el).dataset.field
        const errors = opts.getErrors()
        if (field && errors[field]) {
          delete errors[field]
          opts.setErrors(errors)
          render()
        }
      })
      el.addEventListener('blur', () => {
        opts.syncFromDom()
        const fieldErrors = opts.validate()
        const field = /** @type {HTMLElement} */ (el).dataset.field
        if (field && fieldErrors[field]) {
          const errors = opts.getErrors()
          errors[field] = fieldErrors[field]
          opts.setErrors(errors)
          render()
        }
      })
    })
  }

  function bindEvents() {
    root.querySelector('[data-input="search"]')?.addEventListener('input', (e) => {
      search = /** @type {HTMLInputElement} */ (e.target).value
      page = 1
      render()
    })

    root.querySelector('[data-filter="role"]')?.addEventListener('change', (e) => {
      roleFilter = /** @type {HTMLSelectElement} */ (e.target).value
      page = 1
      render()
    })

    root.querySelector('[data-filter="status"]')?.addEventListener('change', (e) => {
      statusFilter = /** @type {HTMLSelectElement} */ (e.target).value
      page = 1
      render()
    })

    root.querySelector('[data-action="refresh"]')?.addEventListener('click', () => loadUsers())

    root.querySelector('[data-page="prev"]')?.addEventListener('click', () => {
      page = Math.max(1, page - 1)
      render()
    })

    root.querySelector('[data-page="next"]')?.addEventListener('click', () => {
      page += 1
      render()
    })

    root.querySelectorAll('[data-action="add-account"]').forEach((btn) => {
      btn.addEventListener('click', () => openAddModal())
    })

    root.querySelectorAll('[data-action="close-add"]').forEach((btn) => {
      btn.addEventListener('click', () => closeAddModal())
    })

    root.querySelectorAll('[data-action="close-edit"]').forEach((btn) => {
      btn.addEventListener('click', () => closeEditModal())
    })

    root.querySelectorAll('[data-action="close-action"]').forEach((btn) => {
      btn.addEventListener('click', () => closeActionModal())
    })

    root.querySelector('[data-action="action-role-select"]')?.addEventListener('change', (e) => {
      if (!actionModal) return
      actionModal.role = /** @type {HTMLSelectElement} */ (e.target).value
    })

    root.querySelectorAll('[data-action="confirm-action"]').forEach((btn) => {
      btn.addEventListener('click', () => executeActionModal())
    })

    root.querySelectorAll('[data-action="close-profile"]').forEach((btn) => {
      btn.addEventListener('click', () => closeProfile())
    })

    root.querySelectorAll('[data-action="retry-profile"]').forEach((btn) => {
      btn.addEventListener('click', () => {
        if (profileView.userId != null) openProfile(profileView.userId)
      })
    })

    root.querySelectorAll('[data-action="profile-edit"]').forEach((btn) => {
      btn.addEventListener('click', () => openEditFromProfile())
    })

    root.querySelectorAll('[data-action="close-menu"]').forEach((btn) => {
      btn.addEventListener('click', () => {
        openMenuId = null
        render()
      })
    })

    root.querySelectorAll('[data-action="toggle-menu"]').forEach((btn) => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation()
        const id = Number(/** @type {HTMLElement} */ (btn).dataset.userId)
        openMenuId = openMenuId === id ? null : id
        render()
      })
    })

    root.querySelectorAll('[data-action="view-profile"]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const id = Number(/** @type {HTMLElement} */ (btn).dataset.userId)
        if (id) openProfile(id)
      })
    })

    root.querySelectorAll('[data-action="edit-account"]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const id = Number(/** @type {HTMLElement} */ (btn).dataset.userId)
        const u = allUsers.find((x) => x.user_id === id)
        openMenuId = null
        if (u) openEditModal(u)
      })
    })

    root.querySelectorAll('[data-action="change-role"]').forEach((btn) => {
      btn.addEventListener('click', () => {
        if (btn.hasAttribute('disabled')) return
        const id = Number(/** @type {HTMLElement} */ (btn).dataset.userId)
        const u = allUsers.find((x) => x.user_id === id)
        openMenuId = null
        if (u && canChangePrivilegedFields(u)) {
          actionModal = { kind: 'change-role', user: u, role: u.role }
          render()
        }
      })
    })

    root.querySelectorAll('[data-action="reset-password"]').forEach((btn) => {
      btn.addEventListener('click', () => {
        if (btn.hasAttribute('disabled')) return
        const id = Number(/** @type {HTMLElement} */ (btn).dataset.userId)
        const u = allUsers.find((x) => x.user_id === id)
        openMenuId = null
        if (u) {
          actionModal = { kind: 'confirm-reset-password', user: u }
          render()
        }
      })
    })

    root.querySelectorAll('[data-action="toggle-active"]').forEach((btn) => {
      btn.addEventListener('click', () => {
        if (btn.hasAttribute('disabled')) return
        const id = Number(/** @type {HTMLElement} */ (btn).dataset.userId)
        const u = allUsers.find((x) => x.user_id === id)
        openMenuId = null
        if (!u) return
        const sk = accountStatusKey(u)
        if (sk === 'active' && !canChangePrivilegedFields(u)) {
          toastError('Cannot deactivate the last active administrator.')
          render()
          return
        }
        actionModal = {
          kind: sk === 'active' ? 'confirm-deactivate' : 'confirm-activate',
          user: u,
        }
        render()
      })
    })

    root.querySelector('[data-form="add-account"]')?.addEventListener('submit', (e) => {
      e.preventDefault()
      handleAddAccount(/** @type {HTMLFormElement} */ (e.currentTarget))
    })
  }

  async function executeActionModal() {
    if (!actionModal || actionModal.loading) return
    const modal = actionModal
    const u = modal.user

    actionModal = { ...modal, loading: true, error: null }
    render()

    try {
      if (modal.kind === 'confirm-deactivate') {
        await apiFetch(apiBase, getToken, `/users/${u.user_id}/status`, {
          method: 'PATCH',
          body: JSON.stringify({
            status: 'rejected',
            rejection_reason: 'Deactivated by administrator',
          }),
        })
        actionModal = null
        toast(`Account deactivated for ${u.name}`)
        await loadUsers()
        return
      }

      if (modal.kind === 'confirm-activate') {
        await apiFetch(apiBase, getToken, `/users/${u.user_id}/status`, {
          method: 'PATCH',
          body: JSON.stringify({ status: 'approved' }),
        })
        actionModal = null
        toast(`Account activated for ${u.name}`)
        await loadUsers()
        return
      }

      if (modal.kind === 'confirm-reset-password') {
        const result = await apiFetch(apiBase, getToken, `/users/${u.user_id}/reset-password`, {
          method: 'POST',
          body: JSON.stringify({}),
        })
        actionModal = {
          kind: 'reset-success',
          user: u,
          temporaryPassword: String(result?.temporary_password || ''),
        }
        render()
        return
      }

      if (modal.kind === 'change-role') {
        const select = root.querySelector('[data-action="action-role-select"]')
        const role = select ? /** @type {HTMLSelectElement} */ (select).value : modal.role || u.role
        if (!ROLES.includes(role)) {
          actionModal = { ...modal, loading: false, error: 'Select a valid role.' }
          render()
          return
        }
        await apiFetch(apiBase, getToken, `/users/${u.user_id}/role`, {
          method: 'PATCH',
          body: JSON.stringify({ role }),
        })
        actionModal = null
        toast(`Role updated to ${roleLabel(role)}`)
        await loadUsers()
      }
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Action failed'
      actionModal = { ...modal, loading: false, error: message }
      render()
    }
  }

  /**
   * @param {string} msg
   */
  function toastError(msg) {
    let el = root.querySelector('.account-mgmt__toast--error')
    if (!el) {
      el = document.createElement('div')
      el.className = 'account-mgmt__toast account-mgmt__toast--error'
      root.appendChild(el)
    }
    el.textContent = msg
    el.classList.add('is-visible')
    window.setTimeout(() => el?.classList.remove('is-visible'), 4200)
  }

  async function handleSaveEdit() {
    if (!editUser) return
    syncEditFormFromDom()
    editFormApiError = null
    editFormErrors = validateEditForm(allUsers, editForm, editUser.user_id)
    if (Object.keys(editFormErrors).length > 0) {
      render()
      return
    }

    editFormSaving = true
    render()

    const body = {
      name: editForm.name.trim(),
      email: editForm.email.trim(),
      role: editForm.role,
      skill_level: editForm.skillLevel,
      status: mapStatusToApi(editForm.accountStatus),
    }

    try {
      await apiFetch(apiBase, getToken, `/users/${editUser.user_id}`, {
        method: 'PATCH',
        body: JSON.stringify(body),
      })
      const savedName = editForm.name.trim()
      editUser = null
      editFormErrors = {}
      editFormApiError = null
      editFormSaving = false
      toast(`Account updated for ${savedName}`)
      await loadUsers()
    } catch (err) {
      editFormSaving = false
      const message = err instanceof Error ? err.message : 'Failed to update account'
      if (/email already/i.test(message)) {
        editFormErrors.email = 'This email is already registered.'
      } else if (/last administrator/i.test(message)) {
        editFormApiError = message
      } else {
        editFormApiError = message
      }
      render()
    }
  }

  /**
   * @param {HTMLFormElement} form
   */
  async function handleAddAccount(form) {
    syncAddFormFromDom()
    addFormApiError = null
    addFormErrors = validateAddForm(allUsers, addForm)
    if (Object.keys(addFormErrors).length > 0) {
      render()
      return
    }

    addFormSaving = true
    render()

    const body = {
      name: addForm.name.trim(),
      email: addForm.email.trim(),
      role: addForm.role,
      skill_level: addForm.skillLevel,
      status: mapStatusToApi(addForm.accountStatus),
    }

    try {
      await apiFetch(apiBase, getToken, '/users', {
        method: 'POST',
        body: JSON.stringify(body),
      })
      showAddModal = false
      resetAddForm()
      toast('Account created successfully')
      await loadUsers()
    } catch (err) {
      addFormSaving = false
      const message = err instanceof Error ? err.message : 'Failed to create account'
      if (/email already/i.test(message)) {
        addFormErrors.email = 'This email is already registered.'
      } else {
        addFormApiError = message
      }
      render()
    }
  }

  /**
   * @param {string} msg
   */
  function toast(msg) {
    let el = root.querySelector('.account-mgmt__toast')
    if (!el) {
      el = document.createElement('div')
      el.className = 'account-mgmt__toast'
      root.appendChild(el)
    }
    el.textContent = msg
    el.classList.add('is-visible')
    window.setTimeout(() => el?.classList.remove('is-visible'), 3200)
  }

  async function loadUsers() {
    loading = true
    error = null
    render()
    try {
      const data = await apiFetch(apiBase, getToken, '/users')
      allUsers = Array.isArray(data) ? data : []
    } catch (err) {
      error = err instanceof Error ? err.message : 'Failed to load users'
      allUsers = []
    } finally {
      loading = false
      render()
    }
  }

  loadUsers()

  /** @type {(e: KeyboardEvent) => void} */
  const onKey = (e) => {
    if (e.key === 'Escape') {
      openMenuId = null
      if (profileView.userId != null) closeProfile()
      else if (actionModal && !actionModal.loading) closeActionModal()
      else if (showAddModal && !addFormSaving) closeAddModal()
      else if (editUser && !editFormSaving) closeEditModal()
      else render()
    }
  }
  document.addEventListener('keydown', onKey)

  return function destroy() {
    document.removeEventListener('keydown', onKey)
    root.innerHTML = ''
    root.classList.remove('account-mgmt')
    root.removeAttribute('data-account-management')
  }
}

/**
 * @param {string} s
 */
function escapeHtml(s) {
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
}

/**
 * @param {string} s
 */
function escapeAttr(s) {
  return escapeHtml(s).replace(/'/g, '&#39;')
}

/**
 * @param {HTMLElement} root
 */
function refreshIcons(root) {
  const lucide = /** @type {{ createIcons?: (opts?: object) => void } | undefined} */ (globalThis.lucide)
  lucide?.createIcons?.({ attrs: { 'stroke-width': 2 }, root })
}

if (typeof globalThis !== 'undefined') {
  globalThis.initAccountManagement = initAccountManagement
}
