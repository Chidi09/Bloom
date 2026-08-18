import { chromium } from 'playwright';
import { serve } from 'bun';
import { readFileSync, existsSync, statSync } from 'fs';
import { join, extname } from 'path';

const DIST_DIR = join(import.meta.dir, '../dist');

const MIME_TYPES: Record<string, string> = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.webp': 'image/webp',
  '.woff2': 'font/woff2',
  '.woff': 'font/woff',
  '.xml': 'application/xml',
  '.txt': 'text/plain; charset=utf-8',
};

const server = serve({
  port: 43210,
  fetch(req) {
    const url = new URL(req.url);
    let filePath = join(DIST_DIR, url.pathname);

    if (existsSync(filePath) && statSync(filePath).isDirectory()) {
      filePath = join(filePath, 'index.html');
    } else if (!existsSync(filePath) && existsSync(`${filePath}.html`)) {
      filePath = `${filePath}.html`;
    }

    if (!existsSync(filePath)) {
      return new Response('Not Found', { status: 404 });
    }

    const ext = extname(filePath);
    const contentType = MIME_TYPES[ext] || 'application/octet-stream';
    const content = readFileSync(filePath);

    return new Response(content, {
      headers: { 'Content-Type': contentType },
    });
  },
});

console.log(`Local test server running at http://localhost:43210`);

const VIEWPORTS = [
  { name: 'Mobile Small (iPhone SE)', width: 375, height: 667 },
  { name: 'Mobile Standard (iPhone 14)', width: 390, height: 844 },
  { name: 'Tablet (iPad Mini)', width: 768, height: 1024 },
  { name: 'Desktop Standard', width: 1280, height: 800 },
];

const PATHS_TO_AUDIT = [
  '/',
  '/build',
  '/ship',
  '/ui',
  '/blocks',
  '/themes',
  '/docs/introduction',
  '/docs/framework/quickstart',
  '/docs/server/overview',
  '/docs/server/orm-and-migrations',
  '/docs/transparency/platform-capabilities',
];

async function runAudit() {
  const browser = await chromium.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox'],
  });

  const issues: { page: string; viewport: string; issue: string; details?: any }[] = [];

  for (const vp of VIEWPORTS) {
    console.log(`\n🔍 Auditing Viewport: ${vp.name} (${vp.width}x${vp.height})...`);
    const context = await browser.newContext({
      viewport: { width: vp.width, height: vp.height },
    });
    const page = await context.newPage();

    for (const path of PATHS_TO_AUDIT) {
      try {
        await page.goto(`http://localhost:43210${path}`, { waitUntil: 'domcontentloaded' });
        await page.waitForTimeout(400);

        // 1. Check for page-level horizontal overflow
        const overflow = await page.evaluate(() => {
          const docEl = document.documentElement;
          const body = document.body;
          const scrollWidth = Math.max(docEl.scrollWidth, body.scrollWidth);
          const clientWidth = docEl.clientWidth;
          const hasHorizontalOverflow = scrollWidth > clientWidth + 2;

          // Find specific elements causing horizontal overflow
          const overflowingElements: { tag: string; id: string; className: string; right: number; width: number }[] = [];
          if (hasHorizontalOverflow) {
            const allElements = document.querySelectorAll('*');
            for (const el of allElements) {
              const rect = el.getBoundingClientRect();
              if (rect.right > clientWidth + 2) {
                overflowingElements.push({
                  tag: el.tagName.toLowerCase(),
                  id: el.id,
                  className: typeof el.className === 'string' ? el.className.slice(0, 50) : '',
                  right: Math.round(rect.right),
                  width: Math.round(rect.width),
                });
              }
            }
          }

          return {
            hasHorizontalOverflow,
            scrollWidth,
            clientWidth,
            diff: scrollWidth - clientWidth,
            overflowingElements: overflowingElements.slice(0, 5),
          };
        });

        if (overflow.hasHorizontalOverflow) {
          issues.push({
            page: path,
            viewport: vp.name,
            issue: `Horizontal scroll detected: scrollWidth (${overflow.scrollWidth}px) > clientWidth (${overflow.clientWidth}px) by ${overflow.diff}px`,
            details: overflow.overflowingElements,
          });
        }

        // 2. Check mobile navigation toggle responsiveness if mobile/tablet
        if (vp.width < 1024 && path.startsWith('/docs')) {
          const mobileNavCheck = await page.evaluate(() => {
            const toggle = document.getElementById('bloom-docs-nav-toggle');
            const panel = document.getElementById('bloom-docs-nav-panel');
            return {
              hasToggle: !!toggle,
              isToggleVisible: toggle ? window.getComputedStyle(toggle).display !== 'none' : false,
              hasPanel: !!panel,
            };
          });

          if (!mobileNavCheck.hasToggle || !mobileNavCheck.isToggleVisible) {
            issues.push({
              page: path,
              viewport: vp.name,
              issue: 'Mobile docs navigation toggle button is missing or hidden on small viewport',
            });
          }
        }
      } catch (err: any) {
        issues.push({
          page: path,
          viewport: vp.name,
          issue: `Navigation error: ${err.message}`,
        });
      }
    }

    await context.close();
  }

  await browser.close();
  server.stop();

  console.log('\n================ AUDIT RESULTS ================');
  if (issues.length === 0) {
    console.log('✅ ALL PAGES FULLY RESPONSIVE! 0 horizontal overflows or broken viewports detected.');
  } else {
    console.log(`⚠️ FOUND ${issues.length} RESPONSIVENESS ISSUES:`);
    for (const item of issues) {
      console.log(`\n• [${item.viewport}] Page: ${item.page}`);
      console.log(`  Issue: ${item.issue}`);
      if (item.details && item.details.length > 0) {
        console.log(`  Offending Elements:`, JSON.stringify(item.details, null, 2));
      }
    }
  }

  return issues;
}

runAudit();
