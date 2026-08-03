import { expect, test } from "@playwright/test";

test("commissioner can reach the primary member and administration routes", async ({ page }) => {
  await page.goto("/dashboard");
  await expect(page.getByRole("heading", { name: "League standings" })).toBeVisible();

  await page.goto("/dashboard/results");
  await expect(page.getByRole("heading", { name: /Results/ })).toBeVisible();

  await page.goto("/dashboard/finances");
  await expect(page.getByRole("heading", { name: "League finances" })).toBeVisible();

  await page.goto("/dashboard/admin/espn");
  await expect(page.getByRole("heading", { name: "Standings control room" })).toBeVisible();

  await page.goto("/dashboard/admin/season-rules");
  await expect(page.getByRole("heading", { name: "Payouts & penalties" })).toBeVisible();

  await page.goto("/dashboard/admin/notifications");
  await expect(page.getByRole("heading", { name: "League notifications" })).toBeVisible();

  await page.goto("/dashboard/message-composer");
  await expect(page.getByRole("heading", { name: "Message composer" })).toBeVisible();
});

test("result control exposes distinct missing-week and correction modes", async ({ page }) => {
  await page.goto("/dashboard/admin/results");
  await expect(page.getByRole("heading", { name: "Result control" })).toBeVisible();
  await expect(page.getByRole("link", { name: "Missing week" })).toBeVisible();

  await page.getByRole("link", { name: "Correct accepted week" }).click();
  await expect(page).toHaveURL(/operation=correction/);
  await expect(page.getByRole("button", { name: "Record correction" })).toBeVisible();
  await expect(page.getByText(/explicitly reconciles any displaced weekly obligations/)).toBeVisible();
});

test("accepted ESPN scores expose outcomes, weekly honors, and financial effects", async ({ page }) => {
  await page.goto("/dashboard/results?week=1");

  await expect(page.getByRole("heading", { name: "Week 1" })).toBeVisible();
  const finalMatchups = page.getByRole("region", { name: "Final matchups" });
  await expect(finalMatchups.getByText("Development Franchise 2026")).toBeVisible();
  await expect(finalMatchups.getByText("Browser Test Opponent 2026")).toBeVisible();
  await expect(finalMatchups.getByText("128.42")).toBeVisible();
  await expect(finalMatchups.getByText("91.18")).toBeVisible();
  await expect(finalMatchups.getByText("win", { exact: true })).toBeVisible();
  await expect(finalMatchups.getByText("loss", { exact: true })).toBeVisible();

  const highAward = page.getByTestId("weekly-high-award");
  await expect(highAward).toContainText("Automatically derived");
  await expect(highAward).toContainText("League owes winner");
  await expect(highAward).toContainText("$25");

  const lowPenalty = page.getByTestId("weekly-low-penalty");
  await expect(lowPenalty).toContainText("Automatically derived");
  await expect(lowPenalty).toContainText("Low scorer owes league");
  await expect(lowPenalty).toContainText("$10");
});

test("message composer fails safely when AI credentials are absent", async ({ page }) => {
  await page.goto("/dashboard/message-composer");
  await page.getByRole("button", { name: "Generate three options" }).click();
  await expect(page.getByText(/AI generation is not configured yet/)).toBeVisible();
  await expect(page.getByRole("button", { name: "Copy for the group thread" })).toBeDisabled();
});

test("critical pages do not overflow a mobile viewport", async ({ page }, testInfo) => {
  test.skip(!testInfo.project.name.includes("mobile"), "Mobile-only layout assertion");
  for (const route of [
    "/dashboard",
    "/dashboard/results",
    "/dashboard/finances",
    "/dashboard/admin/results?operation=correction",
    "/dashboard/admin/notifications",
    "/dashboard/message-composer",
  ]) {
    await page.goto(route);
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
    expect(overflow, `${route} should not overflow horizontally`).toBeLessThanOrEqual(1);
  }
});
