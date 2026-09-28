import { allNavItems } from '../config/navigation'

const EXTRA_TITLES: Record<string, string> = {
  '/system-configuration': 'System Configuration',
  '/notifications': 'Notification Center',
  '/media/member-uploads': 'Member Uploads',
}

export function pageTitleForPath(pathname: string): string {
  const path = pathname.replace(/\/+$/, '') || '/'
  if (path === '/') return 'Dashboard'

  const exact = allNavItems.find((item) => item.path === path)
  if (exact) return exact.label

  if (EXTRA_TITLES[path]) return EXTRA_TITLES[path]

  const nested = [...allNavItems]
    .filter((item) => item.path !== '/' && path.startsWith(`${item.path}/`))
    .sort((a, b) => b.path.length - a.path.length)[0]
  if (nested) return nested.label

  return 'Admin'
}
