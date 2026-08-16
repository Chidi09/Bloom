import { chromium } from "@playwright/test";

const BASE_URL = "https://sponsor-cells-borders-airfare.trycloudflare.com";

async function main() {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext();
  const page = await context.newPage();

  console.log(`Testing public tunnel: ${BASE_URL}/onboarding...`);
  await page.goto(`${BASE_URL}/onboarding`, { waitUntil: "networkidle" });
  await page.screenshot({ path: "tests/tunnel-onboarding.png", fullPage: true });

  const title = await page.title();
  const headerText = await page.locator("h2, h1, .font-heading").first().textContent();
  console.log(`Page Title: ${title}`);
  console.log(`Heading: ${headerText}`);

  console.log(`Testing public tunnel: ${BASE_URL}/auth/login...`);
  await page.goto(`${BASE_URL}/auth/login`, { waitUntil: "networkidle" });
  await page.screenshot({ path: "tests/tunnel-login.png", fullPage: true });

  await browser.close();
  console.log("✅ Public tunnel test complete and screenshots captured!");
}

main().catch((err: unknown) => {
  console.error("Tunnel verification failed:", err);
  process.exit(1);
});
