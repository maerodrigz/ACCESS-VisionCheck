import type { LucideIcon } from 'lucide-react'
import {
  BellRing,
  CalendarDays,
  ChartNoAxesCombined,
  FileCheck2,
  GraduationCap,
  Images,
  LayoutDashboard,
  MessageSquareHeart,
  Settings,
  ShieldCheck,
  UsersRound,
} from 'lucide-react'

export interface FeatureHeaderCopy {
  icon: LucideIcon
  title: string
  description: string
}

/** Canonical copy for Admin feature headers (sidebar + related admin surfaces). */
export const FEATURE_HEADERS = {
  dashboard: {
    icon: LayoutDashboard,
    title: 'Dashboard',
    description: 'Monitor platform activities, pending requests, and system performance.',
  },
  documentationRequests: {
    icon: FileCheck2,
    title: 'Documentation Requests',
    description: 'Review, approve, and assign members to organization documentation requests.',
  },
  eventCalendar: {
    icon: CalendarDays,
    title: 'Event Calendar',
    description: 'Track documentation events, schedules, and team coverage in one calendar.',
  },
  competency: {
    icon: GraduationCap,
    title: 'Competency Management',
    description: 'Manage member profiles, skills, rankings, and performance.',
  },
  mediaGallery: {
    icon: Images,
    title: 'Media Gallery',
    description: 'Browse event documentation photos and videos, star picks, and publish.',
  },
  mediaIntegrity: {
    icon: ShieldCheck,
    title: 'Media Integrity',
    description: 'Review media risk assessments, source provenance, and verification decisions.',
  },
  requesterFeedback: {
    icon: MessageSquareHeart,
    title: 'Requester Feedback',
    description: 'Review organization ratings and comments after completed documentation events.',
  },
  analytics: {
    icon: ChartNoAxesCombined,
    title: 'Analytics',
    description: 'Explore platform activity, performance trends, and operational insights.',
  },
  accounts: {
    icon: UsersRound,
    title: 'Accounts',
    description: 'Manage users, roles, registrations, and account access.',
  },
  notifications: {
    icon: BellRing,
    title: 'Notification Center',
    description: 'Review alerts for requests, media integrity, and system events.',
  },
  systemConfiguration: {
    icon: Settings,
    title: 'System Configuration',
    description: 'Configure system-wide settings and administrative preferences.',
  },
} as const satisfies Record<string, FeatureHeaderCopy>
