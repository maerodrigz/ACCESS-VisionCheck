import { Navigate, useLocation } from 'react-router-dom'

/**
 * Compatibility: old Member Management URLs land on the unified Competency workspace.
 * Preserves search/query (q, view, member) and defaults to the Member Overview tab (`tab=directory`).
 */
export function MembersToCompetencyRedirect() {
  const { search } = useLocation()
  const params = new URLSearchParams(search)
  if (params.get('view') === 'pending') {
    return <Navigate to="/account-management?view=registrations&tab=members" replace />
  }
  if (!params.get('tab')) {
    params.set('tab', 'directory')
  }
  const qs = params.toString()
  return <Navigate to={qs ? `/competency?${qs}` : '/competency?tab=directory'} replace />
}
