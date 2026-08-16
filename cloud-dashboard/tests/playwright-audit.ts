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

  const orgId = "00000000-0000-0000-0000-000000000001";
  const prjId = "00000000-0000-0000-0000-000000000010";
  const appId = "00000000-0000-0000-0000-000000000030";

  // 1. Organizations List & Detail
  console.log("Auditing Organizations...");
  await page.goto("http://localhost:3000/organizations");
  await page.waitForTimeout(1000);
  await page.screenshot({ path: "tests/audit-organizations.png" });

  console.log("Auditing Organization Detail...");
  await page.goto(`http://localhost:3000/organizations/${orgId}`);
  await page.waitForTimeout(1000);
  await page.screenshot({ path: "tests/audit-organization-detail.png" });

  // 2. Projects List & Detail
  console.log("Auditing Projects...");
  await page.goto("http://localhost:3000/projects");
  await page.waitForTimeout(1000);
  await page.screenshot({ path: "tests/audit-projects.png" });

  console.log("Auditing Project Detail...");
  await page.goto(`http://localhost:3000/projects/${prjId}`);
  await page.waitForTimeout(1000);
  await page.screenshot({ path: "tests/audit-project-detail.png" });

  // 3. Apps List
  console.log("Auditing Apps...");
  await page.goto("http://localhost:3000/apps");
  await page.waitForTimeout(1000);
  await page.screenshot({ path: "tests/audit-apps.png" });

  // 4. Builds tab & expanded row
  console.log("Auditing Builds...");
  await page.goto(`http://localhost:3000/apps/${appId}/builds`);
  await page.waitForTimeout(1000);
  await page.screenshot({ path: "tests/audit-builds.png" });

  // Expand first build row
  const firstRow = page.locator("tbody tr").first();
  if (await firstRow.isVisible()) {
    await firstRow.click();
    await page.waitForTimeout(500);
    await page.screenshot({ path: "tests/audit-builds-expanded.png" });
  }

  // 5. Releases tab & dialog & detail
  console.log("Auditing Releases...");
  await page.goto(`http://localhost:3000/apps/${appId}/releases`);
  await page.waitForTimeout(1000);
  await page.screenshot({ path: "tests/audit-releases.png" });

  await page.click("text=Create Release");
  await page.waitForTimeout(500);
  await page.screenshot({ path: "tests/audit-releases-dialog.png" });
  await page.keyboard.press("Escape");
  await page.waitForTimeout(500);

  console.log("Auditing Release Detail...");
  await page.goto(
    `http://localhost:3000/apps/${appId}/releases/00000000-0000-0000-0000-000000000080`,
  );
  await page.waitForTimeout(1000);
  await page.screenshot({ path: "tests/audit-release-detail.png" });

  // 6. Deployments tab & wizard & detail
  console.log("Auditing Deployments...");
  await page.goto(`http://localhost:3000/apps/${appId}/deployments`);
  await page.waitForTimeout(1000);
  await page.screenshot({ path: "tests/audit-deployments.png" });

  await page.click("button:has-text('Deploy') >> nth=0");
  await page.waitForTimeout(500);
  await page.screenshot({ path: "tests/audit-deployments-dialog.png" });
  await page.keyboard.press("Escape");
  await page.waitForTimeout(500);

  console.log("Auditing Deployment Detail...");
  await page.goto(
    `http://localhost:3000/apps/${appId}/deployments/00000000-0000-0000-0000-000000000090`,
  );
  await page.waitForTimeout(1000);
  await page.screenshot({ path: "tests/audit-deployment-detail.png" });

  // 7. Environments tab + Sheet Open
  console.log("Auditing Environments...");
  await page.goto(`http://localhost:3000/apps/${appId}/environments`);
  await page.waitForTimeout(1000);
  await page.screenshot({ path: "tests/audit-environments.png" });

  await page.click("text=Configure >> nth=0");
  await page.waitForTimeout(500);
  await page.screenshot({ path: "tests/audit-environments-sheet.png" });
  await page.keyboard.press("Escape");
  await page.waitForTimeout(500);

  // 8. Secrets tab + Add Secret Sheet
  console.log("Auditing Secrets...");
  await page.goto(`http://localhost:3000/apps/${appId}/secrets`);
  await page.waitForTimeout(1000);
  await page.screenshot({ path: "tests/audit-secrets.png" });

  await page.click("text=Add Secret");
  await page.waitForTimeout(500);
  await page.screenshot({ path: "tests/audit-secrets-sheet.png" });
  await page.keyboard.press("Escape");
  await page.waitForTimeout(500);

  // 9. Signing tab + Upload Dialog
  console.log("Auditing Signing...");
  await page.goto(`http://localhost:3000/apps/${appId}/signing`);
  await page.waitForTimeout(1000);
  await page.screenshot({ path: "tests/audit-signing.png" });

  await page.click("text=Upload Identity");
  await page.waitForTimeout(500);
  await page.screenshot({ path: "tests/audit-signing-dialog.png" });
  await page.keyboard.press("Escape");
  await page.waitForTimeout(500);

  // 10. Settings tab
  console.log("Auditing Settings...");
  await page.goto(`http://localhost:3000/apps/${appId}/settings`);
  await page.waitForTimeout(1000);
  await page.screenshot({ path: "tests/audit-settings.png" });

  // 11. Full Navigation Walkthrough: Organizations -> Projects -> Apps -> App Detail -> Tabs
  console.log("Verifying navigation flow...");
  await page.goto("http://localhost:3000/organizations");
  await page.waitForTimeout(500);
  await page.click("text=Manage >> nth=0");
  await page.waitForTimeout(500);
  await page.goto("http://localhost:3000/projects");
  await page.waitForTimeout(500);
  await page.click("text=Open >> nth=0");
  await page.waitForTimeout(500);
  await page.goto("http://localhost:3000/apps");
  await page.waitForTimeout(500);
  await page.click("tbody tr >> nth=0");
  await page.waitForTimeout(500);

  await browser.close();
  console.log("Comprehensive Playwright visual self-audit passed successfully!");
}

main().catch((err) => {
  console.error("Audit error:", err);
  process.exit(1);
});

