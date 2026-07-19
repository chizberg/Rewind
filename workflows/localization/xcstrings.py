#!/usr/bin/env python3
"""Read/patch an Apple String Catalog (.xcstrings) without reformatting it.

Xcode serializes .xcstrings with a non-standard separator (`" : "`), 2-space
indent, no trailing newline, and its own key ordering. Naive `json.dump` churns
the whole file. `dump_catalog` below round-trips byte-identically, so a patch
run produces a diff containing only the strings that actually changed.

Subcommands
  inventory   list units that need work (missing / stale / needs_review)
  apply       apply patch files produced by the translation workflows
  verify      check byte-exact round-trip + per-language coverage

All output is JSON on stdout; diagnostics go to stderr.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

# Placeholders that must survive translation unchanged.
PLACEHOLDER_RE = re.compile(
    r"%(?:\d+\$)?[@difsu]|%(?:\d+\$)?l{1,2}[du]|%\.\d+f|%%"
    r"|\{[A-Za-z0-9_]+\}|\$\{[A-Za-z0-9_]+\}"
)

WORK_STATES = {"stale", "needs_review", "new"}


# --- serialization ----------------------------------------------------------


def load_catalog(path: Path) -> dict[str, Any]:
    # json.loads preserves file key order, which dump_catalog then reproduces.
    return json.loads(path.read_text(encoding="utf-8"))


def dump_catalog(catalog: dict[str, Any], path: Path) -> None:
    path.write_text(serialize(catalog), encoding="utf-8")


def serialize(catalog: dict[str, Any]) -> str:
    return json.dumps(catalog, ensure_ascii=False, indent=2, separators=(",", " : "))


# --- traversal --------------------------------------------------------------


def source_value(key: str, entry: dict[str, Any], source_language: str) -> str:
    """The English text for a key.

    Symbolic keys (`comparison_title`) carry their real text in the source
    localization; literal keys are their own source text.
    """
    unit = (
        entry.get("localizations", {})
        .get(source_language, {})
        .get("stringUnit", {})
    )
    value = unit.get("value")
    return value if isinstance(value, str) and value else key


def iter_units(node: dict[str, Any], path: tuple[str, ...] = ()):
    """Yield (variation_path, string_unit_container) for a localization node.

    Handles both plain `stringUnit` and nested `variations` (plural, device).
    """
    if "stringUnit" in node:
        yield ".".join(path), node
    for kind, cases in (node.get("variations") or {}).items():
        for case, sub in cases.items():
            yield from iter_units(sub, path + (kind, case))


def ensure_unit(node: dict[str, Any], variation_path: str) -> dict[str, Any]:
    """Return the container that should hold `stringUnit`, creating variations."""
    if not variation_path:
        return node
    parts = variation_path.split(".")
    if len(parts) % 2 != 0:
        raise ValueError(f"malformed variationPath: {variation_path!r}")
    cursor = node
    for kind, case in zip(parts[::2], parts[1::2]):
        cursor = cursor.setdefault("variations", {}).setdefault(kind, {}).setdefault(case, {})
    return cursor


def target_languages(catalog: dict[str, Any]) -> list[str]:
    source = catalog.get("sourceLanguage", "en")
    seen: set[str] = set()
    for entry in catalog.get("strings", {}).values():
        seen.update(entry.get("localizations", {}))
    return sorted(seen - {source})


# --- inventory --------------------------------------------------------------


def inventory(catalog: dict[str, Any], languages: list[str]) -> dict[str, Any]:
    source_language = catalog.get("sourceLanguage", "en")
    strings = catalog.get("strings", {})
    work: dict[str, list[dict[str, Any]]] = {lang: [] for lang in languages}

    for key, entry in strings.items():
        if entry.get("shouldTranslate") is False:
            continue
        english = source_value(key, entry, source_language)
        comment = entry.get("comment")
        localizations = entry.get("localizations", {})

        # Variation shape is defined by the source; fall back to a plain unit.
        source_node = localizations.get(source_language)
        shapes = [p for p, _ in iter_units(source_node)] if source_node else [""]
        if not shapes:
            shapes = [""]

        for lang in languages:
            node = localizations.get(lang)
            existing = {p: c["stringUnit"] for p, c in iter_units(node)} if node else {}
            for variation_path in shapes:
                unit = existing.get(variation_path)
                if unit is None or not (unit.get("value") or "").strip():
                    reason = "missing"
                elif unit.get("state") in WORK_STATES:
                    reason = unit["state"]
                else:
                    continue
                item: dict[str, Any] = {
                    "key": key,
                    "english": english,
                    "reason": reason,
                }
                if comment:
                    item["comment"] = comment
                if variation_path:
                    item["variationPath"] = variation_path
                if unit and unit.get("value"):
                    item["existing"] = unit["value"]
                placeholders = sorted(set(PLACEHOLDER_RE.findall(english)))
                if placeholders:
                    item["placeholders"] = placeholders
                work[lang].append(item)

    return {
        "sourceLanguage": source_language,
        "languages": languages,
        "counts": {lang: len(items) for lang, items in work.items()},
        "total": sum(len(items) for items in work.values()),
        "work": work,
    }


def reference_corpus(catalog: dict[str, Any], language: str, limit: int) -> list[dict[str, str]]:
    """Already-approved translations, as style reference for a translator."""
    source_language = catalog.get("sourceLanguage", "en")
    out: list[dict[str, str]] = []
    for key, entry in catalog.get("strings", {}).items():
        node = entry.get("localizations", {}).get(language)
        if not node:
            continue
        for variation_path, container in iter_units(node):
            unit = container["stringUnit"]
            if unit.get("state") != "translated" or not unit.get("value"):
                continue
            row = {
                "english": source_value(key, entry, source_language),
                "translation": unit["value"],
            }
            if entry.get("comment"):
                row["comment"] = entry["comment"]
            if variation_path:
                row["variationPath"] = variation_path
            out.append(row)
            if len(out) >= limit:
                return out
    return out


# --- apply ------------------------------------------------------------------


def apply_updates(
    catalog: dict[str, Any],
    updates: list[dict[str, Any]],
    default_state: str,
) -> dict[str, Any]:
    strings = catalog.get("strings", {})
    applied, skipped = 0, []

    for update in updates:
        key = update["key"]
        lang = update["language"]
        value = update["value"]
        variation_path = update.get("variationPath") or ""

        entry = strings.get(key)
        if entry is None:
            skipped.append({"key": key, "language": lang, "why": "key not in catalog"})
            continue
        if not isinstance(value, str) or not value.strip():
            skipped.append({"key": key, "language": lang, "why": "empty value"})
            continue

        english = source_value(key, entry, catalog.get("sourceLanguage", "en"))
        expected = sorted(set(PLACEHOLDER_RE.findall(english)))
        actual = sorted(set(PLACEHOLDER_RE.findall(value)))
        if expected != actual:
            skipped.append({
                "key": key,
                "language": lang,
                "why": f"placeholder mismatch: source {expected} vs translation {actual}",
            })
            continue

        node = entry.setdefault("localizations", {}).setdefault(lang, {})
        container = ensure_unit(node, variation_path)
        container["stringUnit"] = {
            "state": update.get("state") or default_state,
            "value": value,
        }
        applied += 1

    return {"applied": applied, "skipped": skipped}


def load_patches(paths: list[Path]) -> list[dict[str, Any]]:
    updates: list[dict[str, Any]] = []
    for path in paths:
        data = json.loads(path.read_text(encoding="utf-8"))
        items = data["updates"] if isinstance(data, dict) else data
        language = data.get("language") if isinstance(data, dict) else None
        for item in items:
            if "language" not in item:
                if not language:
                    raise ValueError(f"{path}: update has no language and patch has no top-level language")
                item = {**item, "language": language}
            updates.append(item)
    return updates


# --- verify -----------------------------------------------------------------


def verify(path: Path) -> dict[str, Any]:
    original = path.read_text(encoding="utf-8")
    catalog = json.loads(original)
    languages = target_languages(catalog)
    report = inventory(catalog, languages)
    return {
        "roundTripsExactly": serialize(catalog) == original,
        "sourceLanguage": catalog.get("sourceLanguage", "en"),
        "languages": languages,
        "totalKeys": len(catalog.get("strings", {})),
        "outstanding": report["counts"],
    }


# --- cli --------------------------------------------------------------------


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    p_inv = sub.add_parser("inventory", help="list units needing translation")
    p_inv.add_argument("catalog", type=Path)
    p_inv.add_argument("--languages", help="comma-separated; default = all in file")
    p_inv.add_argument("--reference", metavar="LANG", help="also emit approved translations for LANG")
    p_inv.add_argument("--reference-limit", type=int, default=400)

    p_apply = sub.add_parser("apply", help="apply patch files to the catalog")
    p_apply.add_argument("catalog", type=Path)
    p_apply.add_argument("patches", type=Path, nargs="+")
    p_apply.add_argument("--state", default="translated", help="stringUnit state to write")
    p_apply.add_argument("--dry-run", action="store_true")

    p_ver = sub.add_parser("verify", help="check formatting round-trip and coverage")
    p_ver.add_argument("catalog", type=Path)

    args = parser.parse_args()

    if args.command == "verify":
        print(json.dumps(verify(args.catalog), ensure_ascii=False, indent=2))
        return 0

    catalog = load_catalog(args.catalog)

    if args.command == "inventory":
        languages = (
            [x.strip() for x in args.languages.split(",") if x.strip()]
            if args.languages
            else target_languages(catalog)
        )
        result = inventory(catalog, languages)
        if args.reference:
            result["reference"] = reference_corpus(catalog, args.reference, args.reference_limit)
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0

    if args.command == "apply":
        original = serialize(catalog)
        updates = load_patches(args.patches)
        result = apply_updates(catalog, updates, args.state)
        result["received"] = len(updates)
        if args.dry_run:
            result["dryRun"] = True
        else:
            dump_catalog(catalog, args.catalog)
            result["changed"] = serialize(catalog) != original
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 1 if result["skipped"] else 0

    return 2


if __name__ == "__main__":
    sys.exit(main())
