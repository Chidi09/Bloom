import { chromium } from "@playwright/test";

async function main() {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext();
  const page = await context.newPage();

  console.log("1. Navigating to /onboarding...");
  await page.goto("http://localhost:3000/onboarding", { waitUntil: "networkidle" });
  await page.screenshot({ path: "tests/onboarding-step1.png", fullPage: true });

  console.log("2. Submitting Step 1 (Organization)...");
  await page.locator("input#orgName").fill("Bloom Demo Labs");
  await page.locator("button[type='submit']").click();

  // Wait for Step 2 to be visible
  await page.waitForSelector("input#projectName");
  console.log("Reached Step 2 (App Setup)!");
  await page.screenshot({ path: "tests/onboarding-step2.png", fullPage: true });

  console.log("3. Submitting Step 2 (App & Framework)...");
  await page.locator("input#projectName").fill("Mobile Core");
  await page.locator("input#appName").fill("bloom_sample");
  await page.locator("button[type='submit']").click();

  // Wait for Step 3 to be visible
  await page.waitForSelector("text=1. Install the Bloom CLI");
  console.log("Reached Step 3 (CLI Quickstart)!");
  await page.screenshot({ path: "tests/onboarding-step3.png", fullPage: true });

  await browser.close();
  console.log("✅ Onboarding flow completed and verified successfully!");
}

main().catch((err: unknown) => {
  console.error("Onboarding test failed:", err);
  process.exit(1);
});
