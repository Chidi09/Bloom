const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({
    viewport: { width: 375, height: 812 }
  });
  
  await page.goto('http://localhost:4321/bloom', { waitUntil: 'networkidle' });

  const overflowInfo = await page.evaluate(() => {
    const docWidth = document.documentElement.scrollWidth;
    const bodyWidth = document.body.scrollWidth;
    const viewportWidth = window.innerWidth;
    
    const issues = [];
    const elements = document.querySelectorAll('*');
    
    elements.forEach(el => {
      const rect = el.getBoundingClientRect();
      const isVisible = rect.width > 0 && rect.height > 0 && window.getComputedStyle(el).display !== 'none';
      
      if (isVisible) {
        if (rect.right > viewportWidth + 1 || rect.width > viewportWidth + 1) {
          issues.push({
            tag: el.tagName,
            className: el.className,
            text: el.textContent?.substring(0, 50).replace(/\n/g, ' '),
            width: rect.width,
            right: rect.right,
          });
        }
      }
    });
    
    return { docWidth, bodyWidth, viewportWidth, issues };
  });

  console.log(`Viewport: ${overflowInfo.viewportWidth}px`);
  console.log(`Document ScrollWidth: ${overflowInfo.docWidth}px`);
  console.log(`Body ScrollWidth: ${overflowInfo.bodyWidth}px`);
  
  if (overflowInfo.docWidth > overflowInfo.viewportWidth || overflowInfo.bodyWidth > overflowInfo.viewportWidth) {
    console.log('PAGE HAS HORIZONTAL OVERFLOW!');
  } else {
    console.log('No global horizontal overflow detected.');
  }

  console.log(`\nFound ${overflowInfo.issues.length} elements exceeding viewport bounds:`);
  for (const issue of overflowInfo.issues) {
    console.log(`- ${issue.tag} class="${issue.className}" | Width: ${issue.width}px | Right: ${issue.right}px`);
    console.log(`  Text: "${issue.text}"\n`);
  }

  await browser.close();
})();
