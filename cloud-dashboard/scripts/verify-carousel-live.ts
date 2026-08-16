import { chromium } from "@playwright/test";

async function main() {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext();
  const page = await context.newPage();

  console.log("Navigating to /auth/login...");
  await page.goto("http://localhost:3000/auth/login", { waitUntil: "networkidle" });

  const activeSlides: string[] = [];

  for (let i = 0; i < 4; i++) {
    // Read the visible slide headline / tag
    const heading = await page.locator("h2.font-heading").textContent();
    const tag = await page.locator("span.font-mono.tracking-widest").textContent();
    console.log(`[Step ${i + 1}] Active Slide: ${tag} - ${heading}`);
    activeSlides.push(tag || "");

    await page.screenshot({ path: `tests/carousel-step-${i + 1}.png` });

    if (i < 3) {
      console.log("Waiting 2.8s for next transition...");
      await page.waitForTimeout(2800);
    }
  }

  await browser.close();

  console.log("Observed slides sequence:", activeSlides);
  const uniqueSlides = new Set(activeSlides);
  if (uniqueSlides.size >= 3) {
    console.log("✅ Carousel successfully cycled through all slides!");
  } else {
    console.error("❌ Carousel did not cycle through all slides.");
    process.exit(1);
  }
}

main().catch((err: unknown) => {
  console.error("Verification failed:", err);
  process.exit(1);
});
