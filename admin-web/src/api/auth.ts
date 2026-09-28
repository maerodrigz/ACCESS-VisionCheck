import { apiRequest, setStoredToken } from './client'
import type { AuthUser, AccessRole } from '../types/auth'

interface LoginResponse {
  token: string
  user: {
    id: number
    name: string
    email: string
    role: string
  }
}

function normalizeRole(role: string): AccessRole {
  const r = role.toLowerCase()
  if (r === 'admin') return 'Admin'
  if (r === 'organization') return 'Organization'
  return 'Member'
}

export async function login(email: string, password: string): Promise<AuthUser> {
  const data = await apiRequest<LoginResponse>(
    '/auth/login',
    {
      method: 'POST',
      body: JSON.stringify({
        email: email.trim().toLowerCase(),
        password,
      }),
    },
    null,
  )

  const user: AuthUser = {
    id: data.user.id,
    name: data.user.name,
    email: data.user.email,
    role: normalizeRole(data.user.role),
    token: data.token,
  }

  if (user.role !== 'Admin') {
    throw new Error('This portal is for administrators only.')
  }

  setStoredToken(data.token)
  return user
}

export function logout() {
  setStoredToken(null)
}

export interface ForgotPasswordResult {
  message: string
  temporary_password?: string | null
  reset?: boolean
}

export async function requestAdminPasswordReset(email: string): Promise<ForgotPasswordResult> {
  return apiRequest<ForgotPasswordResult>(
    '/auth/forgot-password',
    {
      method: 'POST',
      body: JSON.stringify({ email: email.trim().toLowerCase() }),
    },
    null,
  )
}
