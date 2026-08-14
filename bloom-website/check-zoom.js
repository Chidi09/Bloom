const { chromium } = require('playwright');

const artifactDir = '/root/.gemini/antigravity-cli/brain/526da393-fbc2-4fba-877b-475664c1bd21';

(async () => {
  const browser = await chromium.launch();

  // Simulate zoom out by using larger viewport widths (zoom out = more content fits)
  const zoomLevels = [
    { scale: 1.0, width: 375, label: 'mobile_100' },
    { scale: 0.75, width: 500, label: 'mobile_75' },  // 375/0.75
    { scale: 0.5,  width: 750, label: 'mobile_50' },  // 375/0.5
    { scale: 0.33, width: 1136, label: 'mobile_33' }, // 375/0.33
  ];

  for (const { width, label, scale } of zoomLevels) {
    const page = await browser.newPage({ viewport: { width, height: 812 } });
    // Apply CSS zoom via JS injection to simulate browser zoom-out
    await page.addInitScript((s) => {
      document.addEventListener('DOMContentLoaded', () => {
        document.body.style.zoom = s;
      });
    }, scale);
    await page.goto('http://localhost:4321/', { waitUntil: 'networkidle' });
    await page.waitForTimeout(500);
    await page.screenshot({ path: `${artifactDir}/zoom_${label}.png`, fullPage: false });
    
    const overflow = await page.evaluate(() => ({
      docWidth: document.documentElement.scrollWidth,
      bodyWidth: document.body.scrollWidth,
      viewportWidth: window.innerWidth,
    }));
    console.log(`Zoom ${label} (w=${width}): docW=${overflow.docWidth} bodyW=${overflow.bodyWidth} vpW=${overflow.viewportWidth}`);
    await page.close();
  }

  await browser.close();
  console.log('Done.');
})();
