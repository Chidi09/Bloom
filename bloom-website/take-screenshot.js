const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch();
  
  // Desktop Screenshot
  const page = await browser.newPage({
    viewport: { width: 1440, height: 900 }
  });
  await page.goto('http://localhost:4321/bloom', { waitUntil: 'networkidle' });
  await page.screenshot({ path: '/root/.gemini/antigravity-cli/brain/526da393-fbc2-4fba-877b-475664c1bd21/bloom_desktop.png', fullPage: true });
  await page.close();

  // Mobile Screenshot
  const mobilePage = await browser.newPage({
    viewport: { width: 375, height: 812 }
  });
  await mobilePage.goto('http://localhost:4321/bloom', { waitUntil: 'networkidle' });
  await mobilePage.screenshot({ path: '/root/.gemini/antigravity-cli/brain/526da393-fbc2-4fba-877b-475664c1bd21/bloom_mobile.png', fullPage: true });
  await mobilePage.close();

  await browser.close();
  console.log('Screenshots saved.');
})();
