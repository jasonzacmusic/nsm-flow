#!/usr/bin/env python3
"""Usage: python scripts/import_wispr_dictionary.py FLOW_SQLITE OUTPUT_JSON

Export safe vocabulary terms from a local Wispr Flow dictionary without
reading dictation history, recordings, snippets, email addresses, or URLs.
The output is a plain JSON array suitable for review before adding to NSM Flow.
"""

from __future__ import annotations

import argparse
import json
import re
import sqlite3
from pathlib import Path

ALLOWED_SOURCES = {"manual", "user_edits"}
MAX_TERM_LENGTH = 60
MAX_WORDS = 5


def is_safe_term(value: str) -> bool:
    normalized = " ".join(value.split())
    if not normalized or len(normalized) > MAX_TERM_LENGTH:
        return False
    if len(normalized.split()) > MAX_WORDS:
        return False
    if "@" in normalized or "://" in normalized:
        return False
    if re.search(r"\b(?:https?|www)\b", normalized, re.IGNORECASE):
        return False
    if re.search(r"\d{7,}", normalized):
        return False
    return True


def export_terms(database: Path) -> list[str]:
    connection = sqlite3.connect(f"file:{database}?mode=ro", uri=True)
    connection.row_factory = sqlite3.Row
    try:
        rows = connection.execute(
            """
            SELECT phrase, replacement, manualEntry, source, frequencyUsed
            FROM Dictionary
            WHERE isDeleted = 0 AND isSnippet = 0
            ORDER BY frequencyUsed DESC, phrase COLLATE NOCASE
            """
        )
        terms: list[str] = []
        seen: set[str] = set()
        for row in rows:
            if row["source"] not in ALLOWED_SOURCES:
                continue
            if not row["manualEntry"] and int(row["frequencyUsed"] or 0) < 2:
                continue
            candidate = (row["replacement"] or row["phrase"] or "").strip()
            candidate = " ".join(candidate.split())
            if not is_safe_term(candidate):
                continue
            key = candidate.casefold()
            if key in seen:
                continue
            seen.add(key)
            terms.append(candidate)
        return terms
    finally:
        connection.close()


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Safely export vocabulary from a local Wispr Flow database."
    )
    parser.add_argument("database", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    if not args.database.is_file():
        parser.error(f"database does not exist: {args.database}")

    terms = export_terms(args.database.resolve())
    args.output.write_text(
        json.dumps(terms, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Exported {len(terms)} safe vocabulary terms to {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
