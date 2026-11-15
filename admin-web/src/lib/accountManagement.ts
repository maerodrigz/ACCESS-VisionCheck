import { roleDisplayLabel } from './roles'

export type AccountRole = 'Admin' | 'Member' | 'Organization'
/** Display key for Account Status column (enablement + registration). */
export type AccountStatusKey = 'active' | 'inactive' | 'suspended' | 'disabled'
/** Registration workflow only — used by create/edit account form. */
export type RegistrationStatusKey = 'active' | 'inactive' | 'suspended'

export type PresenceFilter = 'all' | 'online' | 'offline' | 'inactive' | 'disabled'

export interface AdminAccountUser {
  user_id: number
  name: string
  email: string
  role: AccountRole
  status: string
  is_active?: boolean
  skill_level?: string | null
  skill_effective_tier?: string | null
  /** Quality Skill Classification (Photo) — not XP / progression tier. */
  quality_skill_photo_title?: string | null
  quality_skill_video_title?: string | null
  quality_skill_photo_average?: number | null
  quality_skill_video_average?: number | null
  quality_skill_photo_evaluations?: number | null
  quality_skill_video_evaluations?: number | null
  created_at?: string | null
  removed_at?: string | null
  student_id?: string | null
  contact_number?: string | null
  profile_image?: string | null
  last_active?: string | null
  account_status?: string | null
  presence?: string | null
  is_online?: boolean
  is_inactive?: boolean
  last_seen_at?: string | null
  last_login_at?: string | null
  assigned_tasks?: number
  completed_tasks?: number
  primary_task_role?: string | null
}

export interface ProfileActivity {
  kind: string
  label: string
  detail?: string | null
  occurred_at?: string | null
}

export interface AdminUserProfile extends AdminAccountUser {
  recent_activity?: ProfileActivity[]
}

export interface AccountFormValues {
  name: string
  email: string
  role: AccountRole
  skillLevel: string
  accountStatus: RegistrationStatusKey
}

export const ACCOUNT_ROLES: AccountRole[] = ['Admin', 'Member', 'Organization']

export const SKILL_LEVELS = [
  'Novice',
  'Beginner',
  'Intermediate',
  'Advanced',
  'Expert',
  'Master',
] as const

export const CREATE_STATUSES: {
  value: RegistrationStatusKey
  label: string
  api: string
}[] = [
  { value: 'active', label: 'Active', api: 'approved' },
  { value: 'inactive', label: 'Inactive', api: 'pending' },
  { value: 'suspended', label: 'Suspended', api: 'rejected' },
]

export function parseAdminAccountUser(raw: Record<string, unknown>): AdminAccountUser {
  return {
    user_id: Number(raw.user_id ?? raw.id ?? 0),
    name: String(raw.name ?? raw.fullname ?? ''),
    email: String(raw.email ?? ''),
    role: (String(raw.role ?? 'Member') as AccountRole) || 'Member',
    status: String(raw.status ?? 'pending'),
    is_active: raw.is_active != null ? Boolean(raw.is_active) : undefined,
    skill_level: raw.skill_level != null ? String(raw.skill_level) : null,
    skill_effective_tier:
      raw.skill_effective_tier != null ? String(raw.skill_effective_tier) : null,
    quality_skill_photo_title:
      raw.quality_skill_photo_title != null ? String(raw.quality_skill_photo_title) : null,
    quality_skill_video_title:
      raw.quality_skill_video_title != null ? String(raw.quality_skill_video_title) : null,
    quality_skill_photo_average:
      raw.quality_skill_photo_average != null
        ? Number(raw.quality_skill_photo_average)
        : null,
    quality_skill_video_average:
      raw.quality_skill_video_average != null
        ? Number(raw.quality_skill_video_average)
        : null,
    quality_skill_photo_evaluations:
      raw.quality_skill_photo_evaluations != null
        ? Number(raw.quality_skill_photo_evaluations)
        : null,
    quality_skill_video_evaluations:
      raw.quality_skill_video_evaluations != null
        ? Number(raw.quality_skill_video_evaluations)
        : null,
    created_at: raw.created_at != null ? String(raw.created_at) : null,
    removed_at: raw.removed_at != null ? String(raw.removed_at) : null,
    student_id: raw.student_id != null ? String(raw.student_id) : null,
    contact_number: raw.contact_number != null ? String(raw.contact_number) : null,
    profile_image:
      raw.profile_image != null && String(raw.profile_image).trim()
        ? String(raw.profile_image).trim()
        : raw.profileImage != null && String(raw.profileImage).trim()
          ? String(raw.profileImage).trim()
          : null,
    last_active: raw.last_active != null ? String(raw.last_active) : null,
    account_status: raw.account_status != null ? String(raw.account_status) : null,
    presence: raw.presence != null ? String(raw.presence) : null,
    is_online: raw.is_online != null ? Boolean(raw.is_online) : false,
    is_inactive: raw.is_inactive != null ? Boolean(raw.is_inactive) : false,
    last_seen_at: raw.last_seen_at != null ? String(raw.last_seen_at) : null,
    last_login_at: raw.last_login_at != null ? String(raw.last_login_at) : null,
    assigned_tasks: raw.assigned_tasks != null ? Number(raw.assigned_tasks) : undefined,
    completed_tasks: raw.completed_tasks != null ? Number(raw.completed_tasks) : undefined,
    primary_task_role:
      raw.primary_task_role != null ? String(raw.primary_task_role) : null,
  }
}

export function isAccountDisabled(user: AdminAccountUser): boolean {
  return user.is_active === false || Boolean(user.removed_at) || user.account_status === 'Disabled'
}

export function isAccountOnline(user: AdminAccountUser): boolean {
  if (isAccountDisabled(user)) return false
  if (user.is_online != null) return Boolean(user.is_online)
  return String(user.presence || '').toLowerCase() === 'online'
}

export function presenceSummary(users: AdminAccountUser[]) {
  const members = users.filter((u) => u.role === 'Member' || u.role === 'Organization')
  let online = 0
  let offline = 0
  let inactive = 0
  let disabled = 0
  for (const u of members) {
    if (isAccountDisabled(u)) {
      disabled += 1
      continue
    }
    if (isAccountOnline(u)) online += 1
    else offline += 1
    if (u.is_inactive) inactive += 1
  }
  return { total: members.length, online, offline, inactive, disabled }
}

/** Registration workflow status (pending / approved / rejected) — not is_active. */
export function registrationStatusKey(user: AdminAccountUser): RegistrationStatusKey {
  const s = String(user.status || '').toLowerCase()
  if (s === 'rejected' || s === 'suspended') return 'suspended'
  if (s === 'approved') return 'active'
  return 'inactive'
}

/**
 * Account Status for Admin Member Management.
 * Disabled (is_active=false) wins over registration labels so it matches Member Profile.
 */
export function accountStatusKey(user: AdminAccountUser): AccountStatusKey {
  if (isAccountDisabled(user)) return 'disabled'
  return registrationStatusKey(user)
}

export function statusLabel(key: AccountStatusKey): string {
  switch (key) {
    case 'active':
      return 'Active'
    case 'disabled':
      return 'Disabled'
    case 'suspended':
      return 'Suspended'
    default:
      return 'Inactive'
  }
}

export function accountRoleLabel(role: string): string {
  if (role === 'Admin' || role === 'Member' || role === 'Organization') {
    return roleDisplayLabel(role)
  }
  return role || 'Member'
}

export function isRequestorRole(role: string): boolean {
  return role === 'Organization'
}

export function partitionAccounts(rows: AdminAccountUser[]) {
  const members: AdminAccountUser[] = []
  const requestors: AdminAccountUser[] = []
  const administrators: AdminAccountUser[] = []
  for (const u of rows) {
    if (u.role === 'Organization') requestors.push(u)
    else if (u.role === 'Admin') administrators.push(u)
    else members.push(u)
  }
  return { members, requestors, administrators }
}

export function countActiveAdmins(users: AdminAccountUser[]): number {
  return users.filter((u) => u.role === 'Admin' && accountStatusKey(u) === 'active').length
}

export function isProtectedAdmin(user: AdminAccountUser, users: AdminAccountUser[]): boolean {
  return user.role === 'Admin' && countActiveAdmins(users) <= 1
}

export function canChangePrivilegedFields(
  user: AdminAccountUser,
  users: AdminAccountUser[],
): boolean {
  return !isProtectedAdmin(user, users)
}

export function formatAccountDate(raw?: string | null): string {
  if (!raw) return 'N/A'
  const d = new Date(String(raw))
  if (Number.isNaN(d.getTime())) return 'N/A'
  return d.toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' })
}

export function formatAccountDateTime(raw?: string | null): string {
  if (!raw) return 'N/A'
  const d = new Date(String(raw))
  if (Number.isNaN(d.getTime())) return 'N/A'
  return d.toLocaleString(undefined, {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  })
}

export function initialsFromName(name: string): string {
  return name
    .split(/\s+/)
    .map((p) => p[0])
    .join('')
    .slice(0, 2)
    .toUpperCase()
}

export function mapStatusToApi(uiStatus: RegistrationStatusKey | AccountStatusKey): string {
  if (uiStatus === 'disabled') return 'approved'
  return CREATE_STATUSES.find((s) => s.value === uiStatus)?.api || 'pending'
}

function isValidEmail(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())
}

function isDuplicateEmail(
  users: AdminAccountUser[],
  email: string,
  excludeUserId: number | null = null,
): boolean {
  const norm = email.trim().toLowerCase()
  return users.some((u) => {
    if (excludeUserId != null && u.user_id === excludeUserId) return false
    return String(u.email || '').toLowerCase() === norm
  })
}

export function validateAccountForm(
  users: AdminAccountUser[],
  form: AccountFormValues,
  excludeUserId: number | null = null,
): Partial<Record<keyof AccountFormValues, string>> {
  const errors: Partial<Record<keyof AccountFormValues, string>> = {}
  const name = form.name.trim()
  const email = form.email.trim()

  if (!name) errors.name = 'Full name is required.'
  else if (name.length < 2) errors.name = 'Full name must be at least 2 characters.'

  if (!email) errors.email = 'Email address is required.'
  else if (!isValidEmail(email)) errors.email = 'Enter a valid email address.'
  else if (isDuplicateEmail(users, email, excludeUserId)) {
    errors.email = 'This email is already registered.'
  }

  if (!form.role || !ACCOUNT_ROLES.includes(form.role)) {
    errors.role = 'Select a valid role.'
  }

  if (!isRequestorRole(form.role)) {
    if (!form.skillLevel || !SKILL_LEVELS.includes(form.skillLevel as (typeof SKILL_LEVELS)[number])) {
      errors.skillLevel = 'Select an administrative competency level.'
    }
  }

  if (!form.accountStatus || !CREATE_STATUSES.some((s) => s.value === form.accountStatus)) {
    errors.accountStatus = 'Select an account status.'
  }

  return errors
}

export function defaultAccountForm(role: AccountRole = 'Member'): AccountFormValues {
  return {
    name: '',
    email: '',
    role,
    skillLevel: 'Novice',
    accountStatus: 'active',
  }
}

export function formFromUser(user: AdminAccountUser): AccountFormValues {
  return {
    name: user.name,
    email: user.email,
    role: user.role,
    skillLevel:
      user.skill_level && SKILL_LEVELS.includes(user.skill_level as (typeof SKILL_LEVELS)[number])
        ? user.skill_level
        : 'Novice',
    accountStatus: registrationStatusKey(user),
  }
}

export function filterAccounts(
  users: AdminAccountUser[],
  search: string,
  roleFilter: string,
  statusFilter: string,
  presenceFilter: PresenceFilter = 'all',
): AdminAccountUser[] {
  return users.filter((u) => {
    const q = search.trim().toLowerCase()
    if (roleFilter !== 'all' && u.role !== roleFilter) return false
    if (statusFilter !== 'all' && accountStatusKey(u) !== statusFilter) return false
    if (presenceFilter === 'disabled') {
      if (!isAccountDisabled(u)) return false
    } else if (presenceFilter === 'online') {
      if (!isAccountOnline(u)) return false
    } else if (presenceFilter === 'offline') {
      if (isAccountDisabled(u) || isAccountOnline(u)) return false
    } else if (presenceFilter === 'inactive') {
      if (!u.is_inactive || isAccountDisabled(u)) return false
    }
    if (!q) return true
    return u.name.toLowerCase().includes(q) || u.email.toLowerCase().includes(q)
  })
}

export function accountSummaryText(filtered: AdminAccountUser[]): string {
  const { members, requestors, administrators } = partitionAccounts(filtered)
  const parts: string[] = []
  if (members.length) parts.push(`${members.length} member${members.length === 1 ? '' : 's'}`)
  if (requestors.length) {
    parts.push(`${requestors.length} requestor${requestors.length === 1 ? '' : 's'}`)
  }
  if (administrators.length) {
    parts.push(`${administrators.length} administrator${administrators.length === 1 ? '' : 's'}`)
  }
  return parts.join(' · ')
}
