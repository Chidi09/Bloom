import { chromium } from "@playwright/test";

async function main() {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();

  await page.goto("http://localhost:3000/auth/login", { waitUntil: "networkidle" });

  console.log("Checking initial slide...");
  const tagLocator = page.locator("span.font-mono.tracking-widest");
  const initialTag = await tagLocator.textContent();
  console.log("Initial slide tag:", initialTag);
  await page.screenshot({ path: "tests/carousel-slide-1.png" });

  console.log("Waiting 2.8 seconds for slide 2...");
  await page.waitForTimeout(2800);
  const secondTag = await tagLocator.textContent();
  console.log("Second slide tag:", secondTag);
  await page.screenshot({ path: "tests/carousel-slide-2.png" });

  console.log("Waiting 2.8 seconds for slide 3...");
  await page.waitForTimeout(2800);
  const thirdTag = await tagLocator.textContent();
  console.log("Third slide tag:", thirdTag);
  await page.screenshot({ path: "tests/carousel-slide-3.png" });

  await browser.close();

  if (initialTag !== secondTag && secondTag !== thirdTag) {
    console.log("SUCCESS: Carousel transitions correctly automatically!");
  } else {
    console.error("FAIL: Carousel did not switch slides automatically.");
    process.exit(1);
  }
}

main().catch((err: unknown) => {
  console.error("Carousel test error:", err);
  process.exit(1);
});
