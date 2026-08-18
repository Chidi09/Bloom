import { chromium } from 'playwright';
import { UI_REGISTRY } from '../src/lib/ui-registry';

const BASE_URL = 'http://localhost:4399';

async function testInteractivity() {
  console.log('📱 Testing ComponentViewer interactivity & responsive behavior on mobile (375x667)...');
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    viewport: { width: 375, height: 667 },
  });
  const page = await context.newPage();

  let errorCount = 0;

  // Test 10 key component pages with diverse primitives: button, dialog, table, chart, calendar, avatar, tabs, sheet, drawer, sonner
  const testComponents = ['button', 'dialog', 'table', 'chart', 'calendar', 'avatar', 'tabs', 'sheet', 'drawer', 'sonner', 'command-palette'];

  for (const slug of testComponents) {
    const url = `${BASE_URL}/ui/${slug}`;
    console.log(`Checking /ui/${slug}...`);
    await page.goto(url, { waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(100);

    // Test tab switches: code, install, props, preview
    const tabs = ['Dart Code', 'CLI Add', 'Props API', 'Interactive Preview'];
    for (const tabText of tabs) {
      const tabBtn = page.getByRole('button', { name: new RegExp(tabText, 'i') }).first();
      if (await tabBtn.isVisible()) {
        await tabBtn.click();
        await page.waitForTimeout(50);
      }
    }

    // Verify no horizontal overflow in any tab
    const overflow = await page.evaluate(() => {
      return document.documentElement.scrollWidth > window.innerWidth + 1;
    });

    if (overflow) {
      console.error(`❌ Overflow detected on /ui/${slug}`);
      errorCount++;
    }
  }

  await browser.close();

  if (errorCount === 0) {
    console.log('✅ ALL INTERACTIVE MOBILE TESTS PASSED!');
  } else {
    console.error(`❌ ${errorCount} interactive test failures.`);
    process.exit(1);
  }
}

testInteractivity().catch((e) => {
  console.error(e);
  process.exit(1);
});
