import type { SubmissionChainMediaRow } from '../api/submissionChain'

export function chainMediaRoleLabel(item: SubmissionChainMediaRow, rootMediaId: number): string {
  if (item.media_id === rootMediaId) return 'Original submission'
  if (item.replacement_lifecycle === 'active') return 'Active replacement'
  if (item.replacement_lifecycle === 'superseded') return 'Replacement accepted'
  if (item.replacement_lifecycle === 'terminal') return 'Replacement rejected'
  if (item.replaces_media_id != null) return 'Replacement attempt'
  return 'Linked media'
}

export function formatChainEventType(eventType: string): string {
  return eventType.replace(/_/g, ' ')
}
