import { test, expect } from "bun:test";
import { compareVersions, parseVersion } from "../src/lib/utils/semver";

test("alpha updates show newer release notes in numeric order", () => {
  expect(compareVersions("0.3.0-alpha.2", "0.3.0-alpha.1")).toBeGreaterThan(0);
  expect(compareVersions("0.3.0-alpha.10", "0.3.0-alpha.2")).toBeGreaterThan(0);
  expect(compareVersions("0.3.0", "0.3.0-alpha.10")).toBeGreaterThan(0);
  expect(compareVersions("0.3.0-beta.1", "0.3.0-alpha.10")).toBeGreaterThan(0);
  expect(compareVersions("v0.3.0-alpha.2+build1", "0.3.0-alpha.2+build2")).toBe(
    0,
  );
  expect(parseVersion("README")).toBeNull();
  expect(parseVersion("0.3.0-alpha.01")).toBeNull();
});
