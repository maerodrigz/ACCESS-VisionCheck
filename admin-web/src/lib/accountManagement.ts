import { roleDisplayLabel } from './roles'

export type AccountRole = 'Admin' | 'Member' | 'Organization'
export type AccountStatusKey = 'active' | 'inactive' | 'suspended'

export interface AdminAccountUser {
  user_id: number
  name: string
  email: string
  role: AccountRole
  status: string
  is_active?: boolean
  skill_level?: string | null
  created_at?: string | null
  removed_at?: string | null
  student_id?: string | null
  contact_number?: string | null
  profile_image?: string | null
  last_active?: string | null
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
  accountStatus: AccountStatusKey
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
  value: AccountStatusKey
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
    created_at: raw.created_at != null ? String(raw.created_at) : null,
    removed_at: raw.removed_at != null ? String(raw.removed_at) : null,
    student_id: raw.student_id != null ? String(raw.student_id) : null,
    contact_number: raw.contact_number != null ? String(raw.contact_number) : null,
    profile_image: raw.profile_image != null ? String(raw.profile_image) : null,
    last_active: raw.last_active != null ? String(raw.last_active) : null,
    assigned_tasks: raw.assigned_tasks != null ? Number(raw.assigned_tasks) : undefined,
    completed_tasks: raw.completed_tasks != null ? Number(raw.completed_tasks) : undefined,
    primary_task_role:
      raw.primary_task_role != null ? String(raw.primary_task_role) : null,
  }
}

export function accountStatusKey(user: AdminAccountUser): AccountStatusKey {
  if (user.removed_at || user.is_active === false) return 'inactive'
  const s = String(user.status || '').toLowerCase()
  if (s === 'rejected' || s === 'suspended') return 'suspended'
  if (s === 'approved') return 'active'
  return 'inactive'
}

export function statusLabel(key: AccountStatusKey): string {
  switch (key) {
    case 'active':
      return 'Active'
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

export function mapStatusToApi(uiStatus: AccountStatusKey): string {
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
      errors.skillLevel = 'Select a skill level.'
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
    accountStatus: accountStatusKey(user),
  }
}

export function filterAccounts(
  users: AdminAccountUser[],
  search: string,
  roleFilter: string,
  statusFilter: string,
): AdminAccountUser[] {
  return users.filter((u) => {
    const q = search.trim().toLowerCase()
    if (roleFilter !== 'all' && u.role !== roleFilter) return false
    if (statusFilter !== 'all' && accountStatusKey(u) !== statusFilter) return false
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
