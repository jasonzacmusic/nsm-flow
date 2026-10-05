import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Configuration
const LOCALES_DIR = path.join(__dirname, "..", "src", "i18n", "locales");
const REFERENCE_LANG = "en";
// New NSM-only surfaces intentionally use i18next's English fallback until
// Nathaniel has reviewed native translations with speakers of each language.
const ENGLISH_FALLBACK_KEYS = new Set([
  "sidebar.team",
  "settings.debug.recordingRetention.deleteImmediately",
  "footer.getLatestVersion",
  "footer.updateAndRestart",
  "settings.postProcessing.api.apiKey.saved",
  "settings.postProcessing.api.apiKey.remove",
  "settings.postProcessing.api.apiKey.unlock",
  "settings.history.clearAll",
  "settings.history.clearConfirm",
  "settings.history.transcriptRetention.title",
  "settings.history.transcriptRetention.description",
  "settings.history.transcriptRetention.deleteImmediately",
  "settings.saveError",
  "models.downloadingCount",
  "models.downloading",
]);
// `settings.about.projectPage.*` replaced a "Source Code" block whose existing
// translations promised a public repository that does not exist. Keeping those
// strings would have kept the promise in 23 languages, so they were dropped in
// favour of the English fallback until a native speaker reviews new wording.
const ENGLISH_FALLBACK_PREFIXES = [
  "settings.team.",
  "settings.about.projectPage.",
];

type TranslationData = Record<string, unknown>;

interface ValidationResult {
  valid: boolean;
  missing: string[][];
  extra: string[][];
}

function getLanguages(): string[] {
  const entries = fs.readdirSync(LOCALES_DIR, { withFileTypes: true });
  return entries
    .filter((entry) => entry.isDirectory() && entry.name !== REFERENCE_LANG)
    .map((entry) => entry.name)
    .sort();
}

const LANGUAGES = getLanguages();

// Colors for terminal output
const colors: Record<string, string> = {
  reset: "\x1b[0m",
  red: "\x1b[31m",
  green: "\x1b[32m",
  yellow: "\x1b[33m",
  blue: "\x1b[34m",
};

function colorize(text: string, color: string): string {
  return `${colors[color]}${text}${colors.reset}`;
}

function getAllKeyPaths(
  obj: TranslationData,
  prefix: string[] = [],
): string[][] {
  let paths: string[][] = [];
  for (const key in obj) {
    if (!Object.hasOwn(obj, key)) continue;

    const currentPath = prefix.concat([key]);
    const value = obj[key];

    if (typeof value === "object" && value !== null && !Array.isArray(value)) {
      paths = paths.concat(
        getAllKeyPaths(value as TranslationData, currentPath),
      );
    } else {
      paths.push(currentPath);
    }
  }
  return paths;
}

function hasKeyPath(obj: TranslationData, keyPath: string[]): boolean {
  let current: unknown = obj;
  for (const key of keyPath) {
    if (
      typeof current !== "object" ||
      current === null ||
      (current as Record<string, unknown>)[key] === undefined
    ) {
      return false;
    }
    current = (current as Record<string, unknown>)[key];
  }
  return true;
}

function loadTranslationFile(lang: string): TranslationData | null {
  const filePath = path.join(LOCALES_DIR, lang, "translation.json");

  try {
    const content = fs.readFileSync(filePath, "utf8");
    return JSON.parse(content) as TranslationData;
  } catch (error) {
    console.error(colorize(`✗ Error loading ${lang}/translation.json:`, "red"));
    console.error(`  ${(error as Error).message}`);
    return null;
  }
}

function validateTranslations(): void {
  console.log(colorize("\n🌍 Translation Consistency Check\n", "blue"));

  // Load reference file
  console.log(`Loading reference language: ${REFERENCE_LANG}`);
  const referenceData = loadTranslationFile(REFERENCE_LANG);

  if (!referenceData) {
    console.error(
      colorize(`\n✗ Failed to load reference file (${REFERENCE_LANG})`, "red"),
    );
    process.exit(1);
  }

  // Get all key paths from reference
  const referenceKeyPaths = getAllKeyPaths(referenceData);
  console.log(`Reference has ${referenceKeyPaths.length} keys\n`);
  console.log(
    "NSM additions use explicitly listed English fallbacks pending native-speaker review.\n",
  );

  // Track validation results
  let hasErrors = false;
  const results: Record<string, ValidationResult> = {};

  // Validate each language
  for (const lang of LANGUAGES) {
    const langData = loadTranslationFile(lang);

    if (!langData) {
      hasErrors = true;
      results[lang] = { valid: false, missing: [], extra: [] };
      continue;
    }

    // Find missing keys
    const missing = referenceKeyPaths.filter((keyPath) => {
      const dotted = keyPath.join(".");
      const usesEnglishFallback =
        ENGLISH_FALLBACK_KEYS.has(dotted) ||
        ENGLISH_FALLBACK_PREFIXES.some((prefix) => dotted.startsWith(prefix));
      return !usesEnglishFallback && !hasKeyPath(langData, keyPath);
    });

    // Find extra keys (keys in language but not in reference)
    const langKeyPaths = getAllKeyPaths(langData);
    const extra = langKeyPaths.filter(
      (keyPath) => !hasKeyPath(referenceData, keyPath),
    );

    results[lang] = {
      valid: missing.length === 0 && extra.length === 0,
      missing,
      extra,
    };

    if (missing.length > 0 || extra.length > 0) {
      hasErrors = true;
    }
  }

  // Print results
  console.log(colorize("Results:", "blue"));
  console.log("─".repeat(60));

  for (const lang of LANGUAGES) {
    const result = results[lang];

    if (result.valid) {
      console.log(
        colorize(
          `✓ ${lang.toUpperCase()}: Key coverage valid with declared English fallbacks`,
          "green",
        ),
      );
    } else {
      console.log(colorize(`✗ ${lang.toUpperCase()}: Issues found`, "red"));

      if (result.missing.length > 0) {
        console.log(
          colorize(`  Missing ${result.missing.length} keys:`, "yellow"),
        );
        result.missing.slice(0, 10).forEach((keyPath) => {
          console.log(`    - ${keyPath.join(".")}`);
        });
        if (result.missing.length > 10) {
          console.log(
            colorize(
              `    ... and ${result.missing.length - 10} more`,
              "yellow",
            ),
          );
        }
      }

      if (result.extra.length > 0) {
        console.log(
          colorize(
            `  Extra ${result.extra.length} keys (not in reference):`,
            "yellow",
          ),
        );
        result.extra.slice(0, 10).forEach((keyPath) => {
          console.log(`    - ${keyPath.join(".")}`);
        });
        if (result.extra.length > 10) {
          console.log(
            colorize(`    ... and ${result.extra.length - 10} more`, "yellow"),
          );
        }
      }

      console.log("");
    }
  }

  console.log("─".repeat(60));

  // Summary
  const validCount = Object.values(results).filter((r) => r.valid).length;
  const totalCount = LANGUAGES.length;

  if (hasErrors) {
    console.log(
      colorize(
        `\n✗ Validation failed: ${validCount}/${totalCount} languages passed`,
        "red",
      ),
    );
    process.exit(1);
  } else {
    console.log(
      colorize(
        `\n✓ All ${totalCount} locales pass key coverage; declared English fallbacks retained`,
        "green",
      ),
    );
    process.exit(0);
  }
}

// Run validation
validateTranslations();
