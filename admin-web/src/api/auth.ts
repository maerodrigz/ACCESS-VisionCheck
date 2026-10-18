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

export interface ForgotPasswordSendResult {
  message: string
  dev_code?: string | null
}

export interface ForgotPasswordCompleteResult {
  message: string
}

export async function sendForgotPasswordOtp(email: string): Promise<ForgotPasswordSendResult> {
  return apiRequest<ForgotPasswordSendResult>(
    '/auth/forgot-password/send',
    {
      method: 'POST',
      body: JSON.stringify({ email: email.trim().toLowerCase() }),
    },
    null,
  )
}

export async function completeForgotPasswordReset(input: {
  email: string
  code: string
  newPassword: string
}): Promise<ForgotPasswordCompleteResult> {
  return apiRequest<ForgotPasswordCompleteResult>(
    '/auth/forgot-password/complete',
    {
      method: 'POST',
      body: JSON.stringify({
        email: input.email.trim().toLowerCase(),
        code: input.code.trim(),
        new_password: input.newPassword,
      }),
    },
    null,
  )
}
