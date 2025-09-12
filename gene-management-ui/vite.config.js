import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import { fileURLToPath, URL } from 'node:url'
import fs from 'fs'
import path from 'path'
import {viteStaticCopy} from "vite-plugin-static-copy";

// Custom middleware for wasm MIME type
const wasmMiddleware = () => {
  return {
    name: 'wasm-middleware',
    configureServer(server) {
      server.middlewares.use((req, res, next) => {
        if (req.url.endsWith('.wasm')) {
          const wasmPath = path.join(__dirname, 'public', path.basename(req.url));
          const wasmFile = fs.readFileSync(wasmPath);
          res.setHeader('Content-Type', 'application/wasm');
          res.end(wasmFile);
          return;
        }
        next();
      });
    },
  };
};

// https://vite.dev/config/
export default defineConfig({
  plugins: [vue(), wasmMiddleware(),
    viteStaticCopy({
      targets: [
        {
          src: 'node_modules/scichart/_wasm/scichart2d.wasm',
          dest: ''
        },
        // {
        //   src: 'node_modules/scichart/_wasm/scichart2d.data',
        //   dest: ''
        // }
      ]
    })
  ],
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
  },
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url))
    }
  }
})

