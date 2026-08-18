import { chromium } from 'playwright';

async function diagnose() {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();

  for (const route of ['/', '/blocks', '/build', '/bloom']) {
    await page.goto(`http://localhost:4323${route}`, { waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(500);

    // Dark mode surfaces check
    await page.evaluate(() => {
      document.documentElement.classList.add('dark');
      document.documentElement.classList.remove('light');
    });
    await page.waitForTimeout(300);

    const darkIssues = await page.evaluate(() => {
      const results: any[] = [];
      document.querySelectorAll('*').forEach((el) => {
        const style = window.getComputedStyle(el);
        if (style.backgroundColor === 'rgb(2, 6, 23)' || style.backgroundColor === 'rgb(15, 23, 42)' || style.backgroundColor === 'rgb(13, 17, 23)') {
          results.push({
            tag: el.tagName,
            className: el.className,
            bg: style.backgroundColor,
            text: (el.textContent || '').slice(0, 40).trim(),
          });
        }
      });
      return results;
    });

    console.log(`\n🔍 Dark Mode Surface Issues on ${route}:`, darkIssues);

    // Light mode text contrast check
    await page.evaluate(() => {
      document.documentElement.classList.remove('dark');
      document.documentElement.classList.add('light');
    });
    await page.waitForTimeout(300);

    const lightIssues = await page.evaluate(() => {
      const results: any[] = [];
      document.querySelectorAll('h1, h2, h3, p, span, a').forEach((el) => {
        const style = window.getComputedStyle(el);
        if (style.color === 'rgb(255, 255, 255)' || style.color === 'rgb(248, 250, 252)') {
          let parent = el.parentElement;
          let hasDarkParent = false;
          while (parent) {
            const pStyle = window.getComputedStyle(parent);
            if (pStyle.backgroundColor === 'rgb(0, 0, 0)' || pStyle.backgroundColor.startsWith('rgb(139, 92, 246)') || pStyle.backgroundColor === 'rgb(15, 23, 42)' || pStyle.backgroundColor === 'rgb(2, 6, 23)') {
              hasDarkParent = true;
              break;
            }
            parent = parent.parentElement;
          }
          if (!hasDarkParent && (el.textContent || '').trim().length > 0) {
            results.push({
              tag: el.tagName,
              className: el.className,
              text: (el.textContent || '').slice(0, 40).trim(),
            });
          }
        }
      });
      return results;
    });

    console.log(`🔍 Light Mode Text Contrast Issues on ${route}:`, lightIssues);
  }

  await browser.close();
}

diagnose();
