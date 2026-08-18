import { chromium } from 'playwright';
import { UI_REGISTRY } from '../src/lib/ui-registry';
import { DOCS_PAGE_METAS } from '../src/lib/llms-generator';

const BASE_URL = 'http://localhost:4399';

const VIEWPORTS = [
  { name: 'iPhone SE (375x667)', width: 375, height: 667 },
  { name: 'iPhone 14 / Pixel (390x844)', width: 390, height: 844 },
  { name: 'Small Mobile (360x740)', width: 360, height: 740 },
];

async function runAudit() {
  console.log('🚀 Launching Playwright Mobile Audit...');

  const browser = await chromium.launch({ headless: true });
  const issues: { url: string; viewport: string; issue: string; details?: any }[] = [];

  // Assemble list of URLs to test
  const urls = [
    '/',
    '/build',
    '/ship',
    '/bloom',
    '/blocks',
    '/themes',
    '/ui',
    '/privacy',
    '/terms',
    ...UI_REGISTRY.map((c) => `/ui/${c.slug}`),
    ...DOCS_PAGE_METAS.map((m) => m.route.startsWith('/') ? m.route : '/' + m.route),
  ];

  console.log(`Auditing ${urls.length} pages across ${VIEWPORTS.length} mobile viewports...`);

  for (const vp of VIEWPORTS) {
    const context = await browser.newContext({
      viewport: { width: vp.width, height: vp.height },
      userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148',
    });
    const page = await context.newPage();

    for (const path of urls) {
      const fullUrl = `${BASE_URL}${path}`;
      try {
        const res = await page.goto(fullUrl, { waitUntil: 'domcontentloaded', timeout: 10000 });
        if (!res || res.status() >= 400) {
          issues.push({
            url: path,
            viewport: vp.name,
            issue: `HTTP Error: ${res?.status()}`,
          });
          continue;
        }

        // Wait brief moment for hydration
        await page.waitForTimeout(150);

        // Check horizontal overflow
        const overflowData = await page.evaluate(() => {
          const docEl = document.documentElement;
          const body = document.body;
          const windowWidth = window.innerWidth;
          const scrollWidth = Math.max(docEl.scrollWidth, body.scrollWidth);
          const hasOverflow = scrollWidth > windowWidth + 1; // 1px threshold for rounding

          let overflowingElements: { tag: string; id: string; className: string; scrollWidth: number; clientWidth: number }[] = [];

          if (hasOverflow) {
            const allElements = document.querySelectorAll('*');
            allElements.forEach((el) => {
              const rect = el.getBoundingClientRect();
              if (rect.right > windowWidth + 1) {
                overflowingElements.push({
                  tag: el.tagName.toLowerCase(),
                  id: el.id,
                  className: el.className ? (typeof el.className === 'string' ? el.className.slice(0, 80) : '') : '',
                  scrollWidth: el.scrollWidth,
                  clientWidth: el.clientWidth,
                });
              }
            });
          }

          return {
            windowWidth,
            scrollWidth,
            hasOverflow,
            overflowingCount: overflowingElements.length,
            sampleOverflows: overflowingElements.slice(0, 5),
          };
        });

        if (overflowData.hasOverflow) {
          issues.push({
            url: path,
            viewport: vp.name,
            issue: `Horizontal page overflow: windowWidth=${overflowData.windowWidth}, scrollWidth=${overflowData.scrollWidth} (delta: ${overflowData.scrollWidth - overflowData.windowWidth}px)`,
            details: overflowData.sampleOverflows,
          });
        }
      } catch (err: any) {
        issues.push({
          url: path,
          viewport: vp.name,
          issue: `Exception: ${err.message}`,
        });
      }
    }

    await context.close();
  }

  await browser.close();

  console.log('\n=======================================');
  console.log(`AUDIT COMPLETE: Found ${issues.length} issue(s)`);
  console.log('=======================================');
  if (issues.length > 0) {
    for (const iss of issues) {
      console.log(`❌ [${iss.viewport}] ${iss.url}: ${iss.issue}`);
      if (iss.details && iss.details.length > 0) {
        console.log('   Sample overflowing elements:');
        for (const el of iss.details) {
          console.log(`   - <${el.tag} id="${el.id}" class="${el.className}"> (width: ${el.scrollWidth}px)`);
        }
      }
    }
  } else {
    console.log('✅ ALL PAGES PASSED ZERO HORIZONTAL OVERFLOW CHECKS!');
  }
}

runAudit().catch(console.error);
