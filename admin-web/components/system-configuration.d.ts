export function initSystemConfiguration(
  root: HTMLElement,
  options?: {
    apiBase?: string
    getToken?: () => string | null
    getCurrentUser?: () => { role?: string } | null
  },
): () => void

declare global {
  interface Window {
    initSystemConfiguration?: typeof initSystemConfiguration
  }
}

export {}
