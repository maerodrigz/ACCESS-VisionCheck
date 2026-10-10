import { useEffect, type ReactNode } from 'react'

const STORAGE_KEY = 'access_admin_theme'

/** Admin web uses light theme only. */
export function applyTheme() {
  document.documentElement.dataset.theme = 'light'
}

export function ThemeProvider({ children }: { children: ReactNode }) {
  useEffect(() => {
    applyTheme()
    try {
      localStorage.setItem(STORAGE_KEY, 'light')
    } catch {
      /* private browsing */
    }
  }, [])

  return children
}
