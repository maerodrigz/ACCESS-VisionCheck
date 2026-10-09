import type { CompetencyMember } from './competency'

export type ProfileMetricState =
  | { kind: 'value'; value: number; hint?: string }
  | { kind: 'na'; label: string }

export function memberHasEvaluatedMedia(member: CompetencyMember): boolean {
  return member.mediaUploadTotal > 0 || member.profile.recentUploads.length > 0
}

export function profileOverallPerformance(member: CompetencyMember): ProfileMetricState {
  const hasMedia = memberHasEvaluatedMedia(member)
  const hasTasks = member.profile.completedTasks > 0 || member.profile.assignedTasks > 0
  const hasRequesterRatings = member.profile.requesterRatingCount > 0
  if (!hasMedia && !hasTasks && !hasRequesterRatings) {
    return { kind: 'na', label: 'Not Yet Assessed' }
  }
  const hint =
    !hasMedia && (hasTasks || hasRequesterRatings)
      ? 'Based on participation and ratings; no evaluated media uploads yet.'
      : undefined
  return { kind: 'value', value: member.profile.performanceScore, hint }
}

export function profileMediaAcceptance(member: CompetencyMember): ProfileMetricState {
  if (member.mediaUploadTotal <= 0) {
    return { kind: 'na', label: 'N/A' }
  }
  return { kind: 'value', value: member.mediaAcceptanceRate }
}

export function profileSkillScore(member: CompetencyMember): ProfileMetricState {
  if (!memberHasEvaluatedMedia(member)) {
    return {
      kind: 'na',
      label: 'Not Yet Assessed',
    }
  }
  return {
    kind: 'value',
    value: member.assessment.skillScore,
    hint: 'Combined media quality and integrity weighting from existing records.',
  }
}

export function isProvisionalAssignmentRecommendation(member: CompetencyMember): boolean {
  return (
    member.currentLevel === 'beginner' &&
    member.mediaUploadTotal === 0 &&
    member.profile.completedTasks < 5
  )
}

export function integrityProfileCopy(member: CompetencyMember): { title: string; body: string } {
  if (member.integrityViolations > 0) {
    return {
      title: `${member.integrityViolations} confirmed violation${member.integrityViolations === 1 ? '' : 's'}`,
      body: 'Review Media Integrity before large event assignments.',
    }
  }
  if (member.integrityWarnings > 0) {
    return {
      title: 'Pending integrity review',
      body: `${member.integrityWarnings} item${member.integrityWarnings === 1 ? '' : 's'} need admin review in Media Integrity. This is not a confirmed violation.`,
    }
  }
  return {
    title: 'No Recorded Integrity Violations',
    body: 'No confirmed integrity violations have been recorded for this member.',
  }
}

export function displayStrengths(member: CompetencyMember): string[] {
  return member.strengths
}

export function displayImprovements(member: CompetencyMember): string[] {
  return member.areasForImprovement
}

export function displayTraining(member: CompetencyMember): string[] {
  return member.trainingRecommendations
}
