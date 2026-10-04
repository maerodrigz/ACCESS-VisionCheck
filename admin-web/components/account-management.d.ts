export function initAccountManagement(
  root: HTMLElement,
  options?: {
    apiBase?: string
    getToken?: () => string | null
    getCurrentUser?: () => { id?: number; role?: string } | null
  },
): () => void

declare global {
  interface Window {
    initAccountManagement?: typeof initAccountManagement
  }
}

export {}
