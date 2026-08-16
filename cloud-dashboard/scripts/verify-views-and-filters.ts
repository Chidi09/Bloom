import { chromium } from "@playwright/test";

const BASE_URL = "http://localhost:3000";

async function main() {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext();
  const page = await context.newPage();

  const consoleErrors: string[] = [];
  page.on("console", (msg) => {
    if (msg.type() === "error") {
      consoleErrors.push(msg.text());
    }
  });

  console.log("1. Navigating to /overview...");
  await page.goto(`${BASE_URL}/overview`, { waitUntil: "networkidle" });
  await page.waitForSelector("input[placeholder='Search Projects']");

  console.log("2. Verifying Grid view...");
  await page.screenshot({ path: "tests/view-1-grid.png" });

  console.log("3. Switching to List view...");
  await page.locator("button[title='List view']").click();
  await page.waitForTimeout(300);
  await page.screenshot({ path: "tests/view-2-list.png" });

  console.log("4. Testing Filter & Sort dropdown...");
  await page.locator("button[title='Filter & Sort']").click();
  await page.waitForTimeout(300);
  await page.screenshot({ path: "tests/view-3-filter-menu.png" });

  await browser.close();

  if (consoleErrors.length > 0) {
    console.error("Console errors encountered:", consoleErrors);
    process.exit(1);
  }

  console.log("✅ View mode toggle, List view, and Filter dropdown verified with 0 console errors!");
}

main().catch((err: unknown) => {
  console.error("View verification failed:", err);
  process.exit(1);
});
