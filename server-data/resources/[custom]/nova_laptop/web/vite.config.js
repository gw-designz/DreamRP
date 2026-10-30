import { defineConfig } from 'vite';
// index.html is the NUI page; dui.html is the screen painted on the laptop prop.
export default defineConfig({ base: './', build: { target: 'chrome100', sourcemap: false, rollupOptions: { input: { index: 'index.html', dui: 'dui.html' } } } });
