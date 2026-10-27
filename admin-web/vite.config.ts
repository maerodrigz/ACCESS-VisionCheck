import type { ClientRequest } from 'node:http'
import { defineConfig, loadEnv, type ProxyOptions } from 'vite'
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

function apiProxy(target: string): ProxyOptions {
  return {
    target,
    changeOrigin: true,
    /** waverep .env ALLOWED_HOSTS lists 127.0.0.1 without port; avoid 400 on :3003. */
    configure: (proxy) => {
      proxy.on('proxyReq', (proxyReq: ClientRequest) => {
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
      // Bind IPv4 so http://127.0.0.1:5173 and localhost both reach the dev server and /api proxy.
      host: '127.0.0.1',
      port: 5173,
      strictPort: false,
      proxy: {
        '/api': apiProxy(proxyTarget),
        '/uploads': apiProxy(proxyTarget),
      },
    },
    preview: {
      host: '127.0.0.1',
      port: 5173,
      proxy: {
        '/api': apiProxy(proxyTarget),
        '/uploads': apiProxy(proxyTarget),
      },
    },
    test: {
      environment: 'node',
    },
  }
})
