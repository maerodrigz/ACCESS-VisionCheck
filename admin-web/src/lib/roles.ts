import type { AuthUser } from '../types/auth'

export function roleDisplayLabel(role: AuthUser['role']): string {
  switch (role) {
    case 'Admin':
      return 'System Administrator'
    case 'Organization':
      return 'Requestor'
    case 'Member':
      return 'Member'
    default:
      return role
  }
}
