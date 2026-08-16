import { chromium } from "playwright";

async function main() {
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

  // 1. Environments tab + Sheet Open
  console.log("Auditing Environments...");
  await page.goto(`http://localhost:3000/apps/${appId}/environments`);
  await page.waitForTimeout(1000);
  await page.screenshot({ path: "tests/audit-environments.png" });

  // Click Configure on first card
  await page.click("text=Configure >> nth=0");
  await page.waitForTimeout(500);
  await page.screenshot({ path: "tests/audit-environments-sheet.png" });
  await page.keyboard.press("Escape");
  await page.waitForTimeout(500);

  // 2. Secrets tab + Add Secret Sheet + Import Dialog
  console.log("Auditing Secrets...");
  await page.goto(`http://localhost:3000/apps/${appId}/secrets`);
  await page.waitForTimeout(1000);
  await page.screenshot({ path: "tests/audit-secrets.png" });

  await page.click("text=Add Secret");
  await page.waitForTimeout(500);
  await page.screenshot({ path: "tests/audit-secrets-sheet.png" });
  await page.keyboard.press("Escape");
  await page.waitForTimeout(500);

  // 3. Signing tab + Upload Dialog
  console.log("Auditing Signing...");
  await page.goto(`http://localhost:3000/apps/${appId}/signing`);
  await page.waitForTimeout(1000);
  await page.screenshot({ path: "tests/audit-signing.png" });

  await page.click("text=Upload Identity");
  await page.waitForTimeout(500);
  await page.screenshot({ path: "tests/audit-signing-dialog.png" });
  await page.keyboard.press("Escape");
  await page.waitForTimeout(500);

  // 4. Releases tab + Create Release Dialog
  console.log("Auditing Releases...");
  await page.goto(`http://localhost:3000/apps/${appId}/releases`);
  await page.waitForTimeout(1000);
  await page.screenshot({ path: "tests/audit-releases.png" });

  await page.click("text=Create Release");
  await page.waitForTimeout(500);
  await page.screenshot({ path: "tests/audit-releases-dialog.png" });
  await page.keyboard.press("Escape");
  await page.waitForTimeout(500);

  // 5. Release Detail
  console.log("Auditing Release Detail...");
  await page.goto(
    `http://localhost:3000/apps/${appId}/releases/00000000-0000-0000-0000-000000000080`,
  );
  await page.waitForTimeout(1000);
  await page.screenshot({ path: "tests/audit-release-detail.png" });

  // 6. Deployments tab + Deploy Wizard Dialog
  console.log("Auditing Deployments...");
  await page.goto(`http://localhost:3000/apps/${appId}/deployments`);
  await page.waitForTimeout(1000);
  await page.screenshot({ path: "tests/audit-deployments.png" });

  await page.click("button:has-text('Deploy') >> nth=0");
  await page.waitForTimeout(500);
  await page.screenshot({ path: "tests/audit-deployments-dialog.png" });
  await page.keyboard.press("Escape");
  await page.waitForTimeout(500);

  // 7. Deployment Detail
  console.log("Auditing Deployment Detail...");
  await page.goto(
    `http://localhost:3000/apps/${appId}/deployments/00000000-0000-0000-0000-000000000090`,
  );
  await page.waitForTimeout(1000);
  await page.screenshot({ path: "tests/audit-deployment-detail.png" });

  // 8. Siblings sanity: Builds & Settings
  console.log("Auditing Siblings...");
  await page.goto(`http://localhost:3000/apps/${appId}/builds`);
  await page.waitForTimeout(1000);
  await page.screenshot({ path: "tests/audit-sibling-builds.png" });

  await page.goto(`http://localhost:3000/apps/${appId}/settings`);
  await page.waitForTimeout(1000);
  await page.screenshot({ path: "tests/audit-sibling-settings.png" });

  await browser.close();
  console.log("Comprehensive Playwright audit passed with all modal states!");
}

main().catch((err) => {
  console.error("Audit error:", err);
  process.exit(1);
});
