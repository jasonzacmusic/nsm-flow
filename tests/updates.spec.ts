import { test, expect } from "@playwright/test";
import { mockDesktop } from "./desktop-fixture";

test.beforeEach(async ({ page }) => {
  await mockDesktop(page, true);
  await page.goto("/");
  await expect(
    page.getByRole("button", { name: "Update available", exact: true }),
  ).toBeVisible();
});

test("discovery and cancelled review never install or restart", async ({
  page,
}) => {
  await expect
    .poll(() =>
      page.evaluate(
        () =>
          (window as any).__desktop.updateCalls.filter((s: string) =>
            s.includes("download_and_install"),
          ).length,
      ),
    )
    .toBe(0);
  await page
    .getByRole("button", { name: "Update available", exact: true })
    .click();
  await expect
    .poll(() =>
      page.evaluate(() => (window as any).__desktop.updateDialogs.length),
    )
    .toBe(1);
  const state = await page.evaluate(() => (window as any).__desktop);
  expect(JSON.stringify(state.updateDialogs)).toContain(
    "Release fixture: clearer classroom notation",
  );
  expect(JSON.stringify(state.updateDialogs)).toContain("Update and restart");
  expect(state.updateCalls).not.toContain("begin_application_update");
  expect(state.updateCalls).not.toContain(
    "plugin:updater|download_and_install",
  );
  expect(state.updateCalls).not.toContain("plugin:process|restart");
});

test("approval cannot interrupt active dictation", async ({ page }) => {
  await page.evaluate(() => {
    const s = (window as any).__desktop;
    s.confirm = true;
    s.updateBusy = true;
  });
  await page
    .getByRole("button", { name: "Update available", exact: true })
    .click();
  await expect
    .poll(() =>
      page.evaluate(() => (window as any).__desktop.updateDialogs.length),
    )
    .toBe(2);
  const state = await page.evaluate(() => (window as any).__desktop);
  expect(JSON.stringify(state.updateDialogs)).toContain(
    "Finish your recording",
  );
  expect(state.updateCalls).not.toContain(
    "plugin:updater|download_and_install",
  );
  expect(state.updateCalls).not.toContain("plugin:process|restart");
});

test("failed downloads release dictation and allow an approved retry", async ({
  page,
}) => {
  await page.evaluate(() => {
    const s = (window as any).__desktop;
    s.confirm = true;
    s.updateDownloadFails = true;
  });
  await page
    .getByRole("button", { name: "Update available", exact: true })
    .click();
  await expect
    .poll(() =>
      page.evaluate(() =>
        (window as any).__desktop.updateCalls.includes(
          "end_application_update",
        ),
      ),
    )
    .toBe(true);
  await page.evaluate(() => {
    (window as any).__desktop.updateDownloadFails = false;
  });
  await page
    .getByRole("button", { name: "Update available", exact: true })
    .click();
  await expect
    .poll(() =>
      page.evaluate(() =>
        (window as any).__desktop.updateCalls.includes(
          "plugin:process|restart",
        ),
      ),
    )
    .toBe(true);
});
