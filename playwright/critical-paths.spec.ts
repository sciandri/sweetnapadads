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
