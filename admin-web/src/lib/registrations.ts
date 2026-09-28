import { parseDate } from './teamMembers'

export type RequestorRegistrationKind = 'faculty' | 'instructor' | 'organization' | 'unknown'

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
  if (value === 'faculty') return 'faculty'
  if (value === 'instructor') return 'instructor'
  if (value === 'organization') return 'organization'
  return 'unknown'
}

export function requestorTypeLabel(kind: RequestorRegistrationKind): string {
  switch (kind) {
    case 'faculty':
      return 'Faculty'
    case 'instructor':
      return 'Instructor'
    case 'organization':
      return 'Organization'
    default:
      return 'Requestor'
  }
}

export function isFacultyOrInstructor(reg: PendingOrganizationRegistration): boolean {
  return reg.requestorType === 'faculty' || reg.requestorType === 'instructor'
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
