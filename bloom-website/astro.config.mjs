import { defineConfig } from 'astro/config';
import preact from '@astrojs/preact';
import tailwind from '@astrojs/tailwind';
import sitemap from '@astrojs/sitemap';

const siteUrl = process.env.VERCEL_PROJECT_PRODUCTION_URL 
  ? `https://${process.env.VERCEL_PROJECT_PRODUCTION_URL}` 
  : (process.env.VERCEL_URL ? `https://${process.env.VERCEL_URL}` : 'https://bloom-platform-ten.vercel.app');

// https://astro.build/config
export default defineConfig({
  site: siteUrl,
  integrations: [
    preact({
      compat: true, // Enables React compatibility for libraries like Lucide & Framer Motion
    }),
    tailwind({
      applyBaseStyles: false,
    }),
    sitemap({
      changefreq: 'weekly',
      priority: 0.7,
      lastmod: new Date(),
      customPages: [
        `${siteUrl}/`,
        `${siteUrl}/build`,
        `${siteUrl}/ship`,
        `${siteUrl}/bloom`,
      ],
    }),
  ],
  vite: {
    server: {
      allowedHosts: true,
    },
    preview: {
      allowedHosts: true,
    },
    resolve: {
      alias: {
        react: 'preact/compat',
        'react-dom/test-utils': 'preact/test-utils',
        'react-dom': 'preact/compat',
        'react/jsx-runtime': 'preact/jsx-runtime',
      },
    },
  },
});
