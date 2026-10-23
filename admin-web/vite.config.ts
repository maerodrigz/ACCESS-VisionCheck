import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

/** Dev-only API upstream (session: $env:VITE_DEV_PROXY_TARGET="http://127.0.0.1:3003"). Default: production port 3001. */
function devProxyTarget(mode: string): string {
  const fileEnv = loadEnv(mode, process.cwd(), '')
  // PowerShell session vars are not in .env files; merge process.env for VITE_* .
  const fromSession = process.env.VITE_DEV_PROXY_TARGET
  const fromFile = fileEnv.VITE_DEV_PROXY_TARGET
  const target = (fromSession || fromFile || 'http://127.0.0.1:3001').replace(/\/$/, '')
  console.log(`[vite] API proxy target: ${target}`)
  return target
}

function apiProxy(target: string) {
  return {
    target,
    changeOrigin: true,
    /** waverep .env ALLOWED_HOSTS lists 127.0.0.1 without port; avoid 400 on :3003. */
    configure: (proxy: { on: (event: string, fn: (...args: unknown[]) => void) => void }) => {
      proxy.on('proxyReq', (proxyReq: { setHeader: (k: string, v: string) => void }) => {
        proxyReq.setHeader('host', '127.0.0.1')
      })
    },
  }
}

export default defineConfig(({ mode }) => {
  const proxyTarget = devProxyTarget(mode)
  return {
    plugins: [react(), tailwindcss()],
    server: {
      port: 5173,
      proxy: {
        '/api': apiProxy(proxyTarget),
        '/uploads': apiProxy(proxyTarget),
      },
    },
  }
})
