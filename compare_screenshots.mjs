import { chromium } from 'playwright';

async function main() {
  const browser = await chromium.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const context = await browser.newContext({
    viewport: { width: 1440, height: 1080 },
    deviceScaleFactor: 1,
  });

  console.log('Capturing Astro (port 4321)...');
  const pageAstro = await context.newPage();
  await pageAstro.goto('http://127.0.0.1:4321/', { waitUntil: 'networkidle', timeout: 15000 }).catch(() => {});
  await pageAstro.waitForTimeout(2000);
  await pageAstro.screenshot({ path: '/root/dev/Bloom/astro_home.png', fullPage: false });
  await pageAstro.close();

  console.log('Capturing Bloom Dart (port 3000)...');
  const pageDart = await context.newPage();
  await pageDart.goto('http://127.0.0.1:3000/', { waitUntil: 'networkidle', timeout: 15000 }).catch(() => {});
  await pageDart.waitForTimeout(2000);
  await pageDart.screenshot({ path: '/root/dev/Bloom/bloom_dart_home.png', fullPage: false });
  await pageDart.close();

  await browser.close();
  console.log('Screenshots captured successfully!');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
