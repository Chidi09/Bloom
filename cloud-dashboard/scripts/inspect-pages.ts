import { chromium } from "@playwright/test";

async function main() {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();

  const consoleMessages: { type: string; text: string }[] = [];
  const pageErrors: string[] = [];
  const failedRequests: string[] = [];
  const responses: { url: string; status: number }[] = [];

  page.on("console", (msg) => {
    consoleMessages.push({ type: msg.type(), text: msg.text() });
  });

  page.on("pageerror", (err) => {
    pageErrors.push(err.toString());
  });

  page.on("requestfailed", (req) => {
    failedRequests.push(`${req.method()} ${req.url()} - ${req.failure()?.errorText}`);
  });

  page.on("response", (res) => {
    if (res.status() >= 400) {
      responses.push({ url: res.url(), status: res.status() });
    }
  });

  console.log("--- Checking /auth/login ---");
  await page.goto("http://localhost:3000/auth/login", { waitUntil: "networkidle" });
  await page.screenshot({ path: "tests/login.png", fullPage: true });

  console.log("Login page title:", await page.title());
  console.log("Login console messages:", consoleMessages);
  console.log("Login page errors:", pageErrors);
  console.log("Login failed requests:", failedRequests);
  console.log("Login HTTP 4xx/5xx responses:", responses);

  // Clear for register
  consoleMessages.length = 0;
  pageErrors.length = 0;
  failedRequests.length = 0;
  responses.length = 0;

  console.log("\n--- Checking /auth/register ---");
  await page.goto("http://localhost:3000/auth/register", { waitUntil: "networkidle" });
  await page.screenshot({ path: "tests/register.png", fullPage: true });

  console.log("Register page title:", await page.title());
  console.log("Register console messages:", consoleMessages);
  console.log("Register page errors:", pageErrors);
  console.log("Register failed requests:", failedRequests);
  console.log("Register HTTP 4xx/5xx responses:", responses);

  await browser.close();
}

main().catch((err: unknown) => {
  console.error("Script failed:", err);
  process.exit(1);
});
