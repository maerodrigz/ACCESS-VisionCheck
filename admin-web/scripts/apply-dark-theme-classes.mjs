import fs from 'node:fs'
import path from 'node:path'

const root = path.resolve('src')
const replacements = [
  [/hover:bg-slate-50\b/g, 'hover:bg-[var(--color-surface-hover)]'],
  [/hover:bg-slate-100\b/g, 'hover:bg-[var(--color-surface-hover)]'],
  [/hover:bg-slate-200\/60/g, 'hover:bg-[var(--color-surface-hover)]'],
  [/bg-slate-50\/80/g, 'bg-[var(--color-surface-muted)]'],
  [/bg-slate-50\/60/g, 'bg-[var(--color-surface-muted)]'],
  [/bg-slate-50\b/g, 'bg-[var(--color-surface-muted)]'],
  [/bg-slate-100\b/g, 'bg-[var(--color-surface-muted)]'],
  [/text-slate-500\b/g, 'text-[var(--color-text-muted)]'],
  [/text-slate-400\b/g, 'text-[var(--color-text-muted)]'],
  [/text-slate-300\b/g, 'text-[var(--color-text-muted)]'],
  [/border-slate-200\b/g, 'border-[var(--color-border)]'],
  [/border-\[#e2e8f0\]/g, 'border-[var(--color-border)]'],
  [/divide-slate-100\b/g, 'divide-[var(--color-border-subtle)]'],
  [/bg-\[#F8FAFC\]/g, 'bg-[var(--color-content-bg)]'],
  [/bg-\[#f8fafc\]/g, 'bg-[var(--color-content-bg)]'],
  [
    /\bbg-white\b(?!\/)/g,
    'bg-[var(--color-surface-elevated)]',
  ],
  [/rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700/g, 'rounded-xl border border-red-500/30 bg-red-500/10 px-4 py-3 text-sm text-red-300'],
  [/rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700/g, 'rounded-lg border border-red-500/30 bg-red-500/10 px-3 py-2 text-sm text-red-300'],
  [/rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700/g, 'rounded-xl border border-red-500/30 bg-red-500/10 px-4 py-3 text-sm text-red-300'],
  [/bg-blue-50\/80/g, 'bg-[var(--color-accent-blue)]/10'],
  [/bg-blue-50\/60/g, 'bg-[var(--color-accent-blue)]/10'],
  [/bg-blue-50\/40/g, 'bg-[var(--color-accent-blue)]/10'],
  [/bg-blue-50\b/g, 'bg-[var(--color-accent-blue)]/15'],
  [/border-blue-200\b/g, 'border-[var(--color-accent-blue)]/30'],
  [/border-blue-100\b/g, 'border-[var(--color-accent-blue)]/20'],
  [/text-\[#64748b\]/g, 'text-[var(--color-text-secondary)]'],
  [/text-\[#0f2744\]/g, 'text-[var(--color-text-primary)]'],
  [/rounded-lg bg-red-50 px-3 py-1\.5 text-xs font-semibold text-red-600 hover:bg-red-100/g, 'rounded-lg border border-red-500/30 bg-red-500/10 px-3 py-1.5 text-xs font-semibold text-red-300 hover:bg-red-500/20'],
  [/border-green-200 bg-green-50 text-green-700 hover:bg-green-100/g, 'border-green-500/30 bg-green-500/10 text-green-300 hover:bg-green-500/20'],
  [/border-red-200 text-red-600 hover:bg-red-50/g, 'border-red-500/30 text-red-300 hover:bg-red-500/10'],
  [/border-blue-200\/80 bg-blue-50\/40/g, 'border-[var(--color-accent-blue)]/20 bg-[var(--color-accent-blue)]/10'],
  [/bg-amber-50 text-amber-700/g, 'bg-amber-500/15 text-amber-300'],
]

function walk(dir, files = []) {
  for (const name of fs.readdirSync(dir)) {
    const full = path.join(dir, name)
    const stat = fs.statSync(full)
    if (stat.isDirectory()) walk(full, files)
    else if (/\.(tsx|ts|css)$/.test(name)) files.push(full)
  }
  return files
}

let changed = 0
for (const file of walk(root)) {
  const before = fs.readFileSync(file, 'utf8')
  let after = before
  for (const [pattern, value] of replacements) {
    after = after.replace(pattern, value)
  }
  if (after !== before) {
    fs.writeFileSync(file, after)
    changed++
    console.log('updated', path.relative(root, file))
  }
}
console.log(`done: ${changed} files`)
