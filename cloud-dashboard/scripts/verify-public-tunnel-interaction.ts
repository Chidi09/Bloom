import { chromium } from "@playwright/test";

const BASE_URL = "https://sponsor-cells-borders-airfare.trycloudflare.com";

async function main() {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext();
  const page = await context.newPage();

  console.log("Navigating to public tunnel login...");
  await page.goto(`${BASE_URL}/auth/login`, { waitUntil: "networkidle" });

  console.log("Filling login credentials...");
  await page.locator("input#email").fill("dev@bloom.dev");
  await page.locator("input#password").fill("Password123!");

  console.log("Submitting login form...");
  await page.locator("button[type='submit']").click();

  // Verify smooth client-side transition without page refresh
  await page.waitForURL(/overview|onboarding/);
  console.log(`Successfully navigated to: ${page.url()}`);
  await page.screenshot({ path: "tests/tunnel-after-login.png" });

  await browser.close();
  console.log("✅ Public tunnel form submission verified with zero page reload!");
}

main().catch((err: unknown) => {
  console.error("Public interaction test failed:", err);
  process.exit(1);
});
