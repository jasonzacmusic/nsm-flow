import { test, expect } from "@playwright/test";
import { mockDesktop } from "./desktop-fixture";

test.beforeEach(async ({ page }) => {
  await mockDesktop(page);
  await page.goto("/");
  await expect(
    page.getByRole("button", { name: "History", exact: true }),
  ).toBeVisible();
});

test("local dictation settings are available without a cloud sign-in", async ({
  page,
}) => {
  await expect(
    page.getByRole("button", { name: "General", exact: true }),
  ).toBeVisible();
  await expect(
    page.getByText("Sign in to continue", { exact: true }),
  ).toHaveCount(0);
});

test("transcript expiry updates the native setting", async ({ page }) => {
  await page.getByRole("button", { name: "History", exact: true }).click();
  await expect(
    page.getByText("Transcript retention", { exact: true }),
  ).toBeVisible();
  await page.getByRole("button", { name: "Never", exact: true }).click();
  await page.getByText("After 3 days", { exact: true }).click();
  await expect
    .poll(() =>
      page.evaluate(
        () => (window as any).__desktop.settings.transcript_retention_period,
      ),
    )
    .toBe("days3");
});

test("a failed retention save reverts and explains the error", async ({
  page,
}) => {
  await page.evaluate(() => {
    (window as any).__desktop.failRetention = true;
  });
  await page.getByRole("button", { name: "History", exact: true }).click();
  await page.getByRole("button", { name: "Never", exact: true }).click();
  await page.getByText("After 3 days", { exact: true }).click();
  await expect(
    page.getByText("Could not save this setting. Please try again."),
  ).toBeVisible();
  await expect(
    page.getByRole("button", { name: "Never", exact: true }),
  ).toBeVisible();
});

test("clear history requires confirmation and removes saved text too", async ({
  page,
}) => {
  await page.getByRole("button", { name: "History", exact: true }).click();
  await expect(
    page.getByText("Play the C major scale", { exact: true }),
  ).toBeVisible();
  await page.evaluate(() => {
    (window as any).__desktop.confirm = false;
  });
  await page.getByRole("button", { name: "Delete all history" }).click();
  await expect(
    page.getByText("Play the C major scale", { exact: true }),
  ).toBeVisible();
  await page.evaluate(() => {
    (window as any).__desktop.confirm = true;
  });
  await page.getByRole("button", { name: "Delete all history" }).click();
  await expect(
    page.getByText("Play the C major scale", { exact: true }),
  ).toHaveCount(0);
});

test("saved API keys are never placed in the password input", async ({
  page,
}) => {
  await page.getByRole("button", { name: "Post Process", exact: true }).click();
  const field = page.getByPlaceholder("Saved securely — enter a replacement");
  await expect(field).toHaveValue("");
  await field.focus();
  await field.blur();
  await expect
    .poll(() => page.evaluate(() => (window as any).__desktop.keyWrites.length))
    .toBe(0);
  await field.fill("disposable-test-key");
  await field.blur();
  await expect
    .poll(() => page.evaluate(() => (window as any).__desktop.keyWrites.length))
    .toBe(1);
  await expect(field).toHaveValue("");
});
