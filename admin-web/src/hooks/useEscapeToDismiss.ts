import { useEffect } from 'react'

/** Call `onDismiss` when Escape is pressed. */
export function useEscapeToDismiss(
  enabled: boolean,
  onDismiss: () => void,
  options?: {
    /** When true, ignore Escape while any `[aria-modal="true"]` dialog is open. */
    skipWhenModalOpen?: boolean
  },
) {
  const skipWhenModalOpen = options?.skipWhenModalOpen ?? false

  useEffect(() => {
    if (!enabled) return
    function onKeyDown(e: KeyboardEvent) {
      if (e.key !== 'Escape') return
      if (skipWhenModalOpen && document.querySelector('[aria-modal="true"]')) return
      e.preventDefault()
      onDismiss()
    }
    window.addEventListener('keydown', onKeyDown)
    return () => window.removeEventListener('keydown', onKeyDown)
  }, [enabled, onDismiss, skipWhenModalOpen])
}
