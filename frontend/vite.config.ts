import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig(({ mode }) => {
  const proxy = {
    '/api': {
      target: loadEnv(mode, process.cwd(), 'VITE_').VITE_BACKEND_TARGET || 'http://127.0.0.1:3000',
      changeOrigin: true,
      rewrite: (path: string) => path.replace(/^\/api(?=\/|$)/, '') || '/',
    },
  }
  return {
    plugins: [react()],
    server: {
      host: '127.0.0.1',
      port: 5183,
      strictPort: true,
      proxy,
    },
    preview: {
      host: '127.0.0.1',
      port: 4173,
      proxy,
    },
  }
})
