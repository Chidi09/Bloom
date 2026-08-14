const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({
    viewport: { width: 375, height: 812 }
  });
  
  await page.goto('http://localhost:4321/bloom', { waitUntil: 'networkidle' });

  const overflowInfo = await page.evaluate(() => {
    const issues = [];
    const elements = document.querySelectorAll('*');
    
    elements.forEach(el => {
      // Ignore html and body for internal scroll check
      if (el.tagName.toLowerCase() === 'html' || el.tagName.toLowerCase() === 'body') return;
      
      const scrollW = el.scrollWidth;
      const clientW = el.clientWidth;
      const hasHorizontalScroll = scrollW > clientW;
      
      const computedStyle = window.getComputedStyle(el);
      const isVisible = clientW > 0 && computedStyle.display !== 'none';
      
      if (isVisible && hasHorizontalScroll) {
        issues.push({
          tag: el.tagName,
          className: el.className,
          text: el.textContent?.substring(0, 50).replace(/\n/g, ' '),
          scrollWidth: scrollW,
          clientWidth: clientW,
          overflowX: computedStyle.overflowX,
        });
      }
    });
    
    return issues;
  });

  console.log(`\nFound ${overflowInfo.length} containers with internal horizontal scroll/overflow on mobile:`);
  for (const issue of overflowInfo) {
    console.log(`- ${issue.tag} class="${issue.className}" | clientWidth: ${issue.clientWidth}px | scrollWidth: ${issue.scrollWidth}px | overflowX: ${issue.overflowX}`);
    console.log(`  Text: "${issue.text}"\n`);
  }

  await browser.close();
})();
