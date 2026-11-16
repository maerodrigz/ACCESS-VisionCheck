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
  resend_after_seconds?: number | null
}

export interface ForgotPasswordCompleteResult {
  message: string
}

export async function sendForgotPasswordOtp(phone: string): Promise<ForgotPasswordSendResult> {
  return apiRequest<ForgotPasswordSendResult>(
    '/auth/forgot-password/send',
    {
      method: 'POST',
      body: JSON.stringify({ phone: phone.trim() }),
    },
    null,
  )
}

export async function completeForgotPasswordReset(input: {
  phone: string
  code: string
  newPassword: string
}): Promise<ForgotPasswordCompleteResult> {
  return apiRequest<ForgotPasswordCompleteResult>(
    '/auth/forgot-password/complete',
    {
      method: 'POST',
      body: JSON.stringify({
        phone: input.phone.trim(),
        code: input.code.trim(),
        new_password: input.newPassword,
      }),
    },
    null,
  )
}

export interface PhoneVerifySendResult {
  message: string
  phone: string
  phone_verified?: boolean
  dev_code?: string | null
  resend_after_seconds?: number | null
}

export interface PhoneVerifyCompleteResult {
  message: string
  phone: string
  phone_verified: boolean
}

export async function sendPhoneVerificationOtp(phone: string): Promise<PhoneVerifySendResult> {
  return apiRequest<PhoneVerifySendResult>(
    '/auth/phone/verify/send',
    {
      method: 'POST',
      body: JSON.stringify({ phone: phone.trim() }),
    },
  )
}

export async function completePhoneVerification(input: {
  phone: string
  code: string
}): Promise<PhoneVerifyCompleteResult> {
  return apiRequest<PhoneVerifyCompleteResult>(
    '/auth/phone/verify/complete',
    {
      method: 'POST',
      body: JSON.stringify({
        phone: input.phone.trim(),
        code: input.code.trim(),
      }),
    },
  )
}
