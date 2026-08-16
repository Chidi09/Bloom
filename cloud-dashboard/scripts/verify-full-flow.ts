import { chromium } from "@playwright/test";

const BASE_URL = "http://localhost:3000";

async function main() {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext();
  const page = await context.newPage();

  console.log("1. Starting registration at /auth/register...");
  await page.goto(`${BASE_URL}/auth/register`, { waitUntil: "networkidle" });
  await page.locator("input#name").fill("Dev Lead");
  await page.locator("input#email").fill("dev-lead@bloom.dev");
  await page.locator("input#password").fill("SuperSecretPass123!");
  await page.screenshot({ path: "tests/flow-1-register.png" });

  console.log("2. Submitting registration...");
  await page.locator("button[type='submit']").click();

  // Wait for /onboarding
  await page.waitForURL("**/onboarding");
  console.log("Reached /onboarding Step 1!");
  await page.screenshot({ path: "tests/flow-2-onboarding-step1.png" });

  console.log("3. Submitting Workspace Setup...");
  await page.locator("input#orgName").fill("Nova Mobile Studio");
  await page.locator("button[type='submit']").click();

  // Wait for Step 2
  await page.waitForSelector("input#projectName");
  console.log("Reached /onboarding Step 2!");
  await page.locator("input#projectName").fill("Client Apps");
  await page.locator("input#appName").fill("nova_flutter_app");
  await page.screenshot({ path: "tests/flow-3-onboarding-step2.png" });

  console.log("4. Submitting App Setup...");
  await page.locator("button[type='submit']").click();

  // Wait for Step 3
  await page.waitForSelector("text=1. Install the Bloom CLI");
  console.log("Reached /onboarding Step 3!");
  await page.screenshot({ path: "tests/flow-4-onboarding-step3.png" });

  console.log("5. Entering Dashboard Overview...");
  await page.locator("button:has-text('Enter Dashboard Overview')").click();

  // Wait for /overview
  await page.waitForURL("**/overview");
  await page.waitForSelector("input[placeholder='Search Projects']");
  console.log("Reached /overview (Dashboard)!");
  await page.screenshot({ path: "tests/flow-5-overview-dashboard.png", fullPage: true });

  await browser.close();
  console.log("✅ Full End-to-End Production Flow completed and verified successfully!");
}

main().catch((err: unknown) => {
  console.error("Flow test failed:", err);
  process.exit(1);
});
