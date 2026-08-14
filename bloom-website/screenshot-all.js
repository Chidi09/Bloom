const { chromium } = require('playwright');
const path = require('path');

const artifactDir = '/root/.gemini/antigravity-cli/brain/526da393-fbc2-4fba-877b-475664c1bd21';

(async () => {
  const browser = await chromium.launch();
  const pages = ['/', '/bloom', '/build', '/ship'];

  for (const route of pages) {
    const page = await browser.newPage({ viewport: { width: 375, height: 812 } });
    await page.goto(`http://localhost:4321${route}`, { waitUntil: 'networkidle' });
    const name = route === '/' ? 'index' : route.replace('/', '');
    await page.screenshot({ path: `${artifactDir}/mobile_${name}.png`, fullPage: true });
    await page.close();
    console.log(`Captured ${route}`);
  }

  await browser.close();
  console.log('All screenshots saved.');
})();
