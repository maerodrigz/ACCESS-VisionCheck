/** Lock scroll on admin layout `<main>` regions (ref-counted for stacked drawers). */

let lockCount = 0

function mainElements(): HTMLElement[] {
  return Array.from(document.querySelectorAll<HTMLElement>('main'))
}

export function lockMainScroll(): void {
  lockCount += 1
  if (lockCount !== 1) return
  for (const el of mainElements()) {
    el.style.overflow = 'hidden'
  }
}

export function unlockMainScroll(): void {
  if (lockCount <= 0) return
  lockCount -= 1
  if (lockCount !== 0) return
  for (const el of mainElements()) {
    el.style.overflow = ''
  }
}
