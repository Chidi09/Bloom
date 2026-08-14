const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
  
  await page.goto('http://localhost:4321/', { waitUntil: 'networkidle' });
  
  // Click theme toggle button
  const toggleBtn = page.locator('button[aria-label*="theme"], button[aria-label*="Theme"]').first();
  if (await toggleBtn.count() > 0) {
    await toggleBtn.click();
    await page.waitForTimeout(300);
  } else {
    // Manually trigger light mode via JS
    await page.evaluate(() => {
      document.documentElement.classList.remove('dark');
      document.documentElement.classList.add('light');
      localStorage.setItem('bloom-theme', 'light');
    });
    await page.waitForTimeout(300);
  }
  
  await page.screenshot({ path: '/root/dev/Bloom/og_images/lightmode_index.png', fullPage: true });
  
  // Check /bloom in light mode
  await page.goto('http://localhost:4321/bloom', { waitUntil: 'networkidle' });
  await page.evaluate(() => {
    document.documentElement.classList.remove('dark');
    document.documentElement.classList.add('light');
  });
  await page.waitForTimeout(300);
  await page.screenshot({ path: '/root/dev/Bloom/og_images/lightmode_bloom.png', fullPage: true });

  await browser.close();
  console.log('Light mode screenshots captured.');
})();
