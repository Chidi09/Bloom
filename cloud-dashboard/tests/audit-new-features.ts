import { chromium } from "playwright";

async function runAudit() {
  const browser = await chromium.launch({
    headless: true,
    args: ["--no-sandbox", "--disable-setuid-sandbox"],
  });
  const context = await browser.newContext({
    viewport: { width: 1440, height: 900 },
    colorScheme: "dark",
  });
  const page = await context.newPage();

  const appId = "00000000-0000-0000-0000-000000000030";

  console.log("=== STARTING PLAYWRIGHT SELF-AUDIT ===");

  // 1. Web Hosting Tab & Dialogs
  console.log("1. Auditing Web Hosting (/apps/[id]/webhosting)...");
  await page.goto(`http://localhost:3000/apps/${appId}/webhosting`);
  await page.waitForTimeout(1500);
  await page.screenshot({ path: "tests/audit-webhosting-deployments.png" });

  console.log(" - Opening Deploy Now Dialog...");
  const deployNowBtn = page.locator("button:has-text('Deploy Now')").first();
  if (await deployNowBtn.isVisible()) {
    await deployNowBtn.click();
    await page.waitForTimeout(500);
    await page.screenshot({ path: "tests/audit-webhosting-deploy-dialog.png" });
    await page.keyboard.press("Escape");
    await page.waitForTimeout(500);
  }

  console.log(" - Switching to Domains Tab...");
  await page.click("button[role='tab']:has-text('Custom Domains')");
  await page.waitForTimeout(600);
  await page.screenshot({ path: "tests/audit-webhosting-domains.png" });

  console.log(" - Opening Add Domain Dialog...");
  const addDomainBtn = page.locator("button:has-text('Add Domain')").first();
  if (await addDomainBtn.isVisible()) {
    await addDomainBtn.click();
    await page.waitForTimeout(500);
    await page.screenshot({ path: "tests/audit-webhosting-add-domain-dialog.png" });
    await page.keyboard.press("Escape");
    await page.waitForTimeout(500);
  }

  console.log(" - Viewing DNS records modal...");
  const viewRecordsBtn = page.locator("button:has-text('records configured')").first();
  if (await viewRecordsBtn.isVisible()) {
    await viewRecordsBtn.click();
    await page.waitForTimeout(500);
    await page.screenshot({ path: "tests/audit-webhosting-dns-records-modal.png" });
    await page.keyboard.press("Escape");
    await page.waitForTimeout(500);
  }

  // 2. Observability Tab
  console.log("2. Auditing Observability (/apps/[id]/observability)...");
  await page.goto(`http://localhost:3000/apps/${appId}/observability`);
  await page.waitForTimeout(1500);
  await page.screenshot({ path: "tests/audit-observability.png" });

  // 3. Account Settings & Layout User-Menu verification
  console.log("3. Auditing Account Settings (/account)...");
  await page.goto("http://localhost:3000/account");
  await page.waitForTimeout(1500);
  await page.screenshot({ path: "tests/audit-account-profile.png" });

  console.log(" - Switching to API Tokens Tab...");
  await page.click("button[role='tab']:has-text('API Tokens')");
  await page.waitForTimeout(600);
  await page.screenshot({ path: "tests/audit-account-tokens.png" });

  console.log(" - Opening Create API Token Dialog & generating token...");
  const createTokenBtn = page.locator("button:has-text('Create Token')").first();
  if (await createTokenBtn.isVisible()) {
    await createTokenBtn.click();
    await page.waitForTimeout(400);
    await page.fill("#token-name", "Playwright Audit Token");
    await page.click("button[type='submit']:has-text('Generate Token')");
    await page.waitForTimeout(800);
    await page.screenshot({ path: "tests/audit-account-token-generated.png" });
    await page.click("button:has-text('Done')");
    await page.waitForTimeout(500);
  }

  console.log(" - Switching to Security Tab...");
  await page.click("button[role='tab']:has-text('Security & Password')");
  await page.waitForTimeout(600);
  await page.screenshot({ path: "tests/audit-account-security.png" });

  // Test layout user-menu click target
  console.log(" - Verifying Layout User Menu 'Settings' routing to /account without 404...");
  await page.goto("http://localhost:3000/overview");
  await page.waitForTimeout(1000);
  // Hide Next dev overlay that blocks the bottom left corner in development mode
  await page.evaluate(() => {
    document.querySelectorAll("nextjs-portal").forEach((el) => el.remove());
  });
  await page.waitForTimeout(300);

  // Click user avatar footer in sidebar
  const userMenuTrigger = page.locator("aside [data-slot='dropdown-menu-trigger']").last();
  await userMenuTrigger.click();
  await page.waitForTimeout(600);
  await page.screenshot({ path: "tests/audit-user-menu-open.png" });
  await page.locator("[data-slot='dropdown-menu-item']:has-text('Settings'), [role='menuitem']:has-text('Settings')").click();
  await page.waitForTimeout(1000);
  const currentUrl = page.url();
  console.log(`   User menu clicked -> navigated to: ${currentUrl}`);
  if (!currentUrl.includes("/account")) {
    throw new Error(`Expected /account URL but got ${currentUrl}`);
  }

  // 4. Credentials Page
  console.log("4. Auditing Credentials Vault (/credentials)...");
  await page.goto("http://localhost:3000/credentials");
  await page.waitForTimeout(1500);
  await page.screenshot({ path: "tests/audit-credentials-grid.png" });

  console.log(" - Testing Add Credential Dialog wizard...");
  const addCredBtn = page.locator("button:has-text('Add Credential')").first();
  if (await addCredBtn.isVisible()) {
    await addCredBtn.click();
    await page.waitForTimeout(500);
    await page.screenshot({ path: "tests/audit-credentials-wizard-dialog.png" });
    await page.keyboard.press("Escape");
    await page.waitForTimeout(500);
  }

  console.log(" - Testing Connection button inline...");
  const testConnBtn = page.locator("button:has-text('Test Connection')").first();
  if (await testConnBtn.isVisible()) {
    await testConnBtn.click();
    await page.waitForTimeout(1000);
    await page.screenshot({ path: "tests/audit-credentials-test-toast.png" });
  }

  // 5. Git Connections Page
  console.log("5. Auditing Git Connections (/git-connections)...");
  await page.goto("http://localhost:3000/git-connections");
  await page.waitForTimeout(1500);
  await page.screenshot({ path: "tests/audit-git-connections-table.png" });

  console.log(" - Opening Repositories Sheet...");
  const reposBtn = page.locator("button:has-text('Repositories')").first();
  if (await reposBtn.isVisible()) {
    await reposBtn.click();
    await page.waitForTimeout(800);
    await page.screenshot({ path: "tests/audit-git-repositories-sheet.png" });
    await page.keyboard.press("Escape");
    await page.waitForTimeout(500);
  }

  console.log(" - Opening Connect Provider Dialog...");
  const connectBtn = page.locator("button:has-text('Connect Provider')").first();
  if (await connectBtn.isVisible()) {
    await connectBtn.click();
    await page.waitForTimeout(500);
    await page.screenshot({ path: "tests/audit-git-connect-dialog.png" });
    await page.keyboard.press("Escape");
    await page.waitForTimeout(500);
  }

  // 6. Sibling Tabs Regression Check
  console.log("6. Verifying Sibling Tabs on App Detail...");
  await page.goto(`http://localhost:3000/apps/${appId}/secrets`);
  await page.waitForTimeout(1000);
  await page.screenshot({ path: "tests/audit-sibling-secrets-tab.png" });

  await page.goto(`http://localhost:3000/apps/${appId}/signing`);
  await page.waitForTimeout(1000);
  await page.screenshot({ path: "tests/audit-sibling-signing-tab.png" });

  console.log("=== PLAYWRIGHT SELF-AUDIT COMPLETE ===");
  await browser.close();
}

runAudit().catch((err) => {
  console.error("Audit failed with error:", err);
  process.exit(1);
});
