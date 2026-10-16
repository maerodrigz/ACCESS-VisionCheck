import type { LucideIcon } from 'lucide-react'
import {
  Award,
  BarChart3,
  Calendar,
  FileText,
  Home,
  Image,
  ShieldCheck,
  Star,
  UserCog,
  Users,
} from 'lucide-react'

export interface NavItem {
  id: string
  label: string
  path: string
  icon: LucideIcon
}

export interface NavSection {
  label?: string
  items: NavItem[]
}

export const sidebarSections: NavSection[] = [
  {
    items: [{ id: 'dashboard', label: 'Dashboard', path: '/', icon: Home }],
  },
  {
    label: 'DOCUMENTATION',
    items: [
      { id: 'doc-requests', label: 'Documentation Requests', path: '/documentation-requests', icon: FileText },
      { id: 'calendar', label: 'Event Calendar', path: '/event-calendar', icon: Calendar },
      { id: 'members', label: 'Member Management', path: '/members', icon: Users },
      { id: 'media', label: 'Media Gallery', path: '/media', icon: Image },
      { id: 'integrity', label: 'Media Integrity', path: '/media-integrity', icon: ShieldCheck },
    ],
  },
  {
    label: 'PERFORMANCE',
    items: [
      { id: 'feedback', label: 'Requester Feedback', path: '/feedback', icon: Star },
      { id: 'competency', label: 'Competency Management', path: '/competency', icon: Award },
      { id: 'analytics', label: 'Analytics', path: '/analytics', icon: BarChart3 },
    ],
  },
  {
    label: 'SYSTEM',
    items: [{ id: 'account-management', label: 'Accounts', path: '/account-management', icon: UserCog }],
  },
]

export const allNavItems = sidebarSections.flatMap((s) => s.items)
