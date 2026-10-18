import { parseDate } from './teamMembers'

export type RequestorRegistrationKind = 'faculty_staff' | 'organization' | 'unknown'

export type RegistrationApprovalTab = 'all' | 'members' | 'faculty_instructors' | 'organizations'

export interface PendingOrganizationRegistration {
  id: number
  organizationName: string
  organizationEmail: string
  requestorType: RequestorRegistrationKind
  requestorTypeLabel: string
  adviserName: string | null
  contactNumber: string | null
  dateRegistered: Date | null
}

function normalizeRequestorType(raw: unknown): RequestorRegistrationKind {
  const value = String(raw ?? '').trim().toLowerCase()
  if (value === 'organization') return 'organization'
  if (value === 'faculty' || value === 'instructor') return 'faculty_staff'
  if (value.includes('faculty') && value.includes('staff')) return 'faculty_staff'
  return 'unknown'
}

export function requestorTypeLabel(kind: RequestorRegistrationKind): string {
  switch (kind) {
    case 'faculty_staff':
      return 'Faculty / staff requestor'
    case 'organization':
      return 'Organization'
    default:
      return 'Requestor'
  }
}

/** Faculty, staff, and legacy faculty/instructor sign-ups (same requestor path). */
export function isFacultyOrInstructor(reg: PendingOrganizationRegistration): boolean {
  return reg.requestorType === 'faculty_staff'
}

export function isOrganizationRequestor(reg: PendingOrganizationRegistration): boolean {
  return reg.requestorType === 'organization' || reg.requestorType === 'unknown'
}

export function parsePendingOrganizationRegistration(
  raw: Record<string, unknown>,
): PendingOrganizationRegistration {
  const requestorType = normalizeRequestorType(raw.requestor_type ?? raw.student_id)
  return {
    id: Number(raw.user_id ?? 0),
    organizationName: String(raw.organization_name ?? ''),
    organizationEmail: String(raw.organization_email ?? ''),
    requestorType,
    requestorTypeLabel: requestorTypeLabel(requestorType),
    adviserName: (raw.adviser_name as string | null) ?? null,
    contactNumber: (raw.contact_number as string | null) ?? null,
    dateRegistered: parseDate(raw.date_registered ?? raw.created_at),
  }
}
