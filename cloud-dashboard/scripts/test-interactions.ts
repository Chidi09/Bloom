import { chromium } from "@playwright/test";

async function main() {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();

  console.log("1. Testing Register form interaction & password evaluation...");
  await page.goto("http://localhost:3000/auth/register", { waitUntil: "networkidle" });

  const pwdInput = page.locator("input#password");
  await pwdInput.fill("123");
  await page.screenshot({ path: "tests/register-weak-pwd.png" });

  await pwdInput.fill("StrongP@ssw0rd123!");
  await page.screenshot({ path: "tests/register-strong-pwd.png" });

  console.log("2. Testing form validation error triggers...");
  await page.locator("input#email").fill("invalid-email");
  await page.locator("button[type='submit']").click();
  await page.screenshot({ path: "tests/register-errors.png" });

  console.log("3. Testing Login error trigger...");
  await page.goto("http://localhost:3000/auth/login", { waitUntil: "networkidle" });
  await page.locator("input#email").fill("not-an-email");
  await page.locator("button[type='submit']").click();
  await page.screenshot({ path: "tests/login-errors.png" });

  await browser.close();
  console.log("Interaction tests completed successfully!");
}

main().catch((err: unknown) => {
  console.error("Interaction test failed:", err);
  process.exit(1);
});
