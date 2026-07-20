import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')
  const apiTarget =
    env.VITE_API_PROXY_TARGET ||
    env.VITE_API_HOST ||
    'https://crm-1-foi4.onrender.com'

  return {
    plugins: [react(), tailwindcss()],
    server: {
      port: 5177,
      proxy: {
        '/api': {
          target: apiTarget,
          changeOrigin: true,
          secure: true,
        },
      },
    },
  }
})
