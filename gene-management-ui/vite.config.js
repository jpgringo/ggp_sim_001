import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// https://vite.dev/config/
export default defineConfig({
  plugins: [vue()],
  css: {
    devSourcemap: true
  },
  server: {
    proxy: {
      '/api': {
        target: 'http://localhost:4000', // your Elixir API server
        changeOrigin: true,
        rewrite: (path) => path, // optional if you want to preserve `/api`
      },
      '/ws': {
        target: 'ws://localhost:4000',
        ws: true,
      }
    }
  }
})

