import { compareVersions, parseVersion } from "@/lib/utils/semver";

export interface ReleaseNote {
  version: string;
  markdown: string;
}

interface ReleaseNoteRecord {
  version: string;
  markdown: string;
}

interface FindReleaseNoteOptions {
  currentVersion: string;
  lastSeenVersion: string;
}

const releaseNoteModules = import.meta.glob<string>(
  "../../content/release-notes/*.md",
  {
    eager: true,
    import: "default",
    query: "?raw",
  },
);

const releaseNotesByVersion = new Map<string, ReleaseNoteRecord>();

for (const [path, markdown] of Object.entries(releaseNoteModules)) {
  const match = path.match(/release-notes\/([^/]+)\.md$/);
  if (!match) continue;

  const version = match[1];

  if (!parseVersion(version)) continue;

  releaseNotesByVersion.set(version, {
    version,
    markdown,
  });
}

export const findReleaseNoteToShow = ({
  currentVersion,
  lastSeenVersion,
}: FindReleaseNoteOptions): ReleaseNote | null => {
  if (!parseVersion(currentVersion)) return null;

  const hasValidLastSeenVersion = parseVersion(lastSeenVersion) !== null;
  const candidate = Array.from(releaseNotesByVersion.values())
    .filter((note) => compareVersions(note.version, currentVersion) <= 0)
    .filter(
      (note) =>
        !hasValidLastSeenVersion ||
        compareVersions(note.version, lastSeenVersion) > 0,
    )
    .sort((a, b) => compareVersions(b.version, a.version))[0];

  if (!candidate) return null;

  return candidate;
};

export const findLatestReleaseNote = (): ReleaseNote | null => {
  const candidate = Array.from(releaseNotesByVersion.values()).sort((a, b) =>
    compareVersions(b.version, a.version),
  )[0];

  if (!candidate) return null;

  return candidate;
};
