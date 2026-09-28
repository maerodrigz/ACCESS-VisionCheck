import type { LucideIcon } from 'lucide-react'
import {
  CheckCircle2,
  ClipboardList,
  Megaphone,
  ShieldAlert,
  Star,
  Upload,
  UserPlus,
  Users,
} from 'lucide-react'

export type ActivityVisualKind =
  | 'check'
  | 'integrity'
  | 'upload'
  | 'user'
  | 'star'
  | 'request'
  | 'media'
  | 'member'
  | 'feedback'
  | 'task'

const ACTIVITY_VISUALS: Record<
  ActivityVisualKind,
  { Icon: LucideIcon; color: string; label: string }
> = {
  check: { Icon: CheckCircle2, color: '#3b82f6', label: 'Approved' },
  request: { Icon: ClipboardList, color: '#3b82f6', label: 'Request' },
  integrity: { Icon: ShieldAlert, color: '#d946ef', label: 'Media integrity' },
  upload: { Icon: Upload, color: '#06b6d4', label: 'Upload' },
  media: { Icon: ShieldAlert, color: '#06b6d4', label: 'Media' },
  user: { Icon: UserPlus, color: '#8b5cf6', label: 'Member' },
  member: { Icon: Users, color: '#8b5cf6', label: 'Member' },
  star: { Icon: Star, color: '#6366f1', label: 'Organization' },
  feedback: { Icon: Megaphone, color: '#f59e0b', label: 'Feedback' },
  task: { Icon: ClipboardList, color: '#6366f1', label: 'Task' },
}

function activityTint(color: string, amount = 18) {
  return `color-mix(in srgb, ${color} ${amount}%, transparent)`
}

export function mapDashboardActivityKind(kind: string): ActivityVisualKind {
  switch (kind) {
    case 'media':
      return 'media'
    case 'member':
      return 'member'
    case 'feedback':
      return 'feedback'
    case 'task':
      return 'task'
    default:
      return 'request'
  }
}

export function ActivityTypeIcon({
  kind,
  size = 'md',
  accentColor,
}: {
  kind: ActivityVisualKind
  size?: 'sm' | 'md'
  accentColor?: string
}) {
  const visual = ACTIVITY_VISUALS[kind] ?? ACTIVITY_VISUALS.upload
  const { Icon } = visual
  const color = accentColor ?? visual.color
  const box = size === 'sm' ? 'h-8 w-8 rounded-lg' : 'h-9 w-9 rounded-full'
  const iconSize = size === 'sm' ? 16 : 15

  return (
    <span
      className={`flex shrink-0 items-center justify-center border ${box}`}
      style={{
        color,
        backgroundColor: activityTint(color),
        borderColor: activityTint(color, 38),
      }}
      title={visual.label}
      aria-hidden
    >
      <Icon size={iconSize} strokeWidth={2.5} />
    </span>
  )
}

export function integrityActivityColor(detectionLabel: string): string {
  const label = detectionLabel.toLowerCase()
  if (label.includes('suspicious')) return '#06b6d4'
  if (label.includes('generated') || label.includes('ai')) return '#d946ef'
  return '#8b5cf6'
}

export function dashboardActivityAccent(kind: string, title = ''): string | undefined {
  switch (kind) {
    case 'media':
      return integrityActivityColor(title)
    case 'member':
      return '#8b5cf6'
    case 'feedback':
      return '#f59e0b'
    case 'task':
      return '#6366f1'
    default:
      return '#3b82f6'
  }
}
