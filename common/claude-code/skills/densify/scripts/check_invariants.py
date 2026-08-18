#!/usr/bin/env python3
"""
Deterministic loss detector for markdown compression.

Extracts hard-to-fake, easy-to-lose tokens from an original and a compressed
document and reports what vanished. Catches the majority of real information
loss without any model judgement.

Usage:
    check_invariants.py ORIGINAL COMPRESSED [--json] [--ignore FILE]
    check_invariants.py --stats FILE

Exit codes:
    0  no blocking loss
    1  blocking loss detected (numbers / code / URLs / identifiers dropped)
    2  usage error
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

# --------------------------------------------------------------------------
# Normalisation: strip markdown scaffolding that legitimately changes shape
# --------------------------------------------------------------------------

# Ordered-list markers and heading hashes carry no payload but would otherwise
# register as "numbers" and produce false positives when prose becomes a table.
RE_ORDERED_MARKER = re.compile(r"^\s{0,8}\d{1,3}[.)]\s+", re.M)
# The optional trailing group eats a section ordinal ("### 13.2 Why ..."), which
# is navigation, not data. Without it, deleting a numbered section -- the whole
# point of this skill -- reports the section's own number as lost content.
# Scoped to heading lines so a genuine "13.2" in prose is still tracked.
RE_HEADING_HASH = re.compile(r"^\s{0,3}#{1,6}\s+(?:\d{1,3}(?:\.\d{1,3})*\.?\s+)?", re.M)
RE_BULLET_MARKER = re.compile(r"^\s{0,8}[-*+]\s+", re.M)
RE_TABLE_SEP = re.compile(r"^\s*\|?[\s:|-]{4,}\|?\s*$", re.M)


# In-page anchor targets are navigation: "](#14-dead-letter-queue-dlq)" carries
# no fact its own link text does not. Left in, deleting a table of contents --
# routine for this skill -- reports every section ordinal as lost data, which
# trains the operator to ignore the gate. Only "#..." targets are stripped;
# external URLs are extracted separately from the raw text and still checked.
RE_ANCHOR_LINK = re.compile(r"\]\(#[^)]*\)")


def strip_scaffolding(text: str) -> str:
    text = RE_ANCHOR_LINK.sub("]", text)
    text = RE_TABLE_SEP.sub("", text)
    text = RE_ORDERED_MARKER.sub("", text)
    text = RE_HEADING_HASH.sub("", text)
    text = RE_BULLET_MARKER.sub("", text)
    return text


# --------------------------------------------------------------------------
# Extractors
# --------------------------------------------------------------------------

RE_FENCE = re.compile(r"^[ \t]*(?:```|~~~)[^\n]*\n(.*?)^[ \t]*(?:```|~~~)", re.S | re.M)
RE_INLINE_CODE = re.compile(r"`([^`\n]+)`")
RE_URL = re.compile(r"<?(https?://[^\s>)\]\"'`]+)>?")

# A number plus its unit, whether glued (200ms) or spelled out (200 milliseconds).
# Units are canonicalised so a rewrite from one form to the other is not a diff,
# while a genuine unit change (90 days -> 90 seconds) still trips the gate.
UNIT_CANON = {
    "%": "%",
    "percent": "%",
    "pct": "%",
    "x": "x",
    "times": "x",
    "ms": "ms",
    "millisecond": "ms",
    "milliseconds": "ms",
    "msec": "ms",
    "s": "s",
    "sec": "s",
    "secs": "s",
    "second": "s",
    "seconds": "s",
    "m": "m",
    "min": "m",
    "mins": "m",
    "minute": "m",
    "minutes": "m",
    "h": "h",
    "hr": "h",
    "hrs": "h",
    "hour": "h",
    "hours": "h",
    "d": "d",
    "day": "d",
    "days": "d",
    "w": "w",
    "week": "w",
    "weeks": "w",
    "mo": "mo",
    "month": "mo",
    "months": "mo",
    "y": "y",
    "yr": "y",
    "year": "y",
    "years": "y",
    "kb": "kb",
    "mb": "mb",
    "gb": "gb",
    "tb": "tb",
    "k": "k",
    "b": "b",
    "px": "px",
    "em": "em",
    "rem": "rem",
}
RE_NUMBER = re.compile(
    r"(?<![\w.])(\d[\d_,]*(?:\.\d+)*)\s?([A-Za-z%]{1,12})?(?!\w)(?!\.\d)"
)

IDENTIFIER_PATTERNS = [
    re.compile(r"(?<![\w/])(?:\.{0,2}/)[\w.\-/]+"),  # ./path  /abs/path
    re.compile(
        r"\b[\w\-]+\.(?:md|py|js|mjs|ts|tsx|jsx|json|ya?ml|toml|ini|sh|bash|txt|csv|sql|rs|go|java|cs)\b"
    ),
    re.compile(r"\$\{?[A-Z_][A-Z0-9_]*\}?"),  # $VAR ${VAR}
    re.compile(r"\b[A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+\b"),  # ENV_STYLE_CONST
    re.compile(r"\b[a-z][a-z0-9]*(?:_[a-z0-9]+)+\b"),  # snake_case
    re.compile(r"\b[a-z][a-z0-9]*(?:[A-Z][a-z0-9]*)+\b"),  # camelCase
    re.compile(r"(?<![\w.-])--?[a-zA-Z][\w-]{1,}"),  # --flag  -f
    re.compile(r"\bv?\d+\.\d+(?:\.\d+)*(?:-[\w.]+)?\b"),  # 1.2.3  v2.0
    re.compile(r"\b[a-z_][\w-]*(?:\.[a-z_][\w-]*)+\b"),  # dotted.name
]

# Dotted/abbrev noise that is prose, not an identifier.
IDENT_STOPLIST = {
    "e.g",
    "i.e",
    "etc",
    "vs",
    "a.k.a",
    "et.al",
    "ie",
    "eg",
    "--",
    "-",
    "e.g.",
    "i.e.",
}

# Meaning-inverting and scope-limiting words. Losing one silently flips a spec.
# Bucketed by function so that a legitimate synonym swap ("does not expire" ->
# "never") nets to zero instead of firing a false advisory.
QUALIFIER_BUCKETS = {
    "negation": [
        "not",
        "never",
        "no",
        "none",
        "cannot",
        "without",
        "neither",
        "nor",
        "n't",
    ],
    "condition": [
        "unless",
        "except",
        "only",
        "if",
        "when",
        "until",
        "otherwise",
        "provided",
        "assuming",
    ],
    "ordering": ["before", "after", "first", "then", "finally", "prior"],
    "bound": [
        "at least",
        "at most",
        "up to",
        "more than",
        "less than",
        "fewer",
        "maximum",
        "minimum",
        "max",
        "min",
        "cap",
        "capped",
        "exceed",
        "exceeds",
    ],
}
NORMATIVE = [
    "must",
    "should",
    "may",
    "shall",
    "required",
    "optional",
    "recommended",
    "prohibited",
]


def _norm_number(raw: str, unit: str | None) -> str:
    core = raw.replace(",", "").replace("_", "")
    if "." in core:
        core = core.rstrip("0").rstrip(".") or "0"
    else:
        core = core.lstrip("0") or "0"
    canon = UNIT_CANON.get((unit or "").lower(), "")
    return core + canon


def extract(text: str) -> dict[str, set[str] | dict[str, int]]:
    fences = {m.strip() for m in RE_FENCE.findall(text)}
    body_wo_fence = RE_FENCE.sub("\n", text)

    inline = {m.strip() for m in RE_INLINE_CODE.findall(body_wo_fence)}
    urls = set(RE_URL.findall(text))

    scaffold_free = strip_scaffolding(body_wo_fence)

    numbers = set()
    for raw, unit in RE_NUMBER.findall(scaffold_free):
        numbers.add(_norm_number(raw, unit))

    idents = set()
    for pat in IDENTIFIER_PATTERNS:
        # scaffold_free, not text: numbers already use it, and reading the two
        # from different sources let a heading ordinal survive as an identifier
        # while being stripped as a number. Identifiers inside headings survive
        # either way -- only the leading section ordinal is removed.
        for m in pat.findall(scaffold_free):
            tok = m.strip().strip(".,;:)")
            if not tok or tok.lower() in IDENT_STOPLIST or len(tok) < 2:
                continue
            idents.add(tok)
    # Identifiers already captured verbatim inside code spans are not a separate risk.
    idents -= inline

    low = re.sub(r"\s+", " ", scaffold_free.lower())

    def word_count(term: str) -> int:
        return len(re.findall(r"(?<![\w'])" + re.escape(term) + r"(?![\w])", low))

    qual_counts = {
        bucket: sum(word_count(w) for w in words)
        for bucket, words in QUALIFIER_BUCKETS.items()
    }
    norm_counts = {n: word_count(n) for n in NORMATIVE}

    return {
        "code_fences": fences,
        "inline_code": inline,
        "urls": urls,
        "numbers": numbers,
        "identifiers": idents,
        "qualifier_counts": qual_counts,
        "normative_counts": norm_counts,
    }


def stats(text: str) -> dict[str, int]:
    lines = text.splitlines()
    return {
        "lines": len(lines),
        "nonblank_lines": sum(1 for line in lines if line.strip()),
        "chars": len(text),
        "words": len(text.split()),
    }


# --------------------------------------------------------------------------
# Comparison
# --------------------------------------------------------------------------

BLOCKING = ["numbers", "code_fences", "inline_code", "urls", "identifiers"]


def compare(orig: str, comp: str, ignore: set[str]) -> dict:
    a, b = extract(orig), extract(comp)

    losses = {}
    for key in BLOCKING:
        missing = {t for t in (a[key] - b[key]) if t not in ignore}
        if missing:
            losses[key] = sorted(missing)

    advisories = []
    for word, before in a["qualifier_counts"].items():
        after = b["qualifier_counts"][word]
        if before and after < before:
            advisories.append(
                {"kind": "qualifier", "token": word, "before": before, "after": after}
            )
    for word, before in a["normative_counts"].items():
        after = b["normative_counts"][word]
        if before and after != before:
            advisories.append(
                {"kind": "normative", "token": word, "before": before, "after": after}
            )

    s_a, s_b = stats(orig), stats(comp)
    reduction = {
        k: (round(100 * (1 - s_b[k] / s_a[k]), 1) if s_a[k] else 0.0) for k in s_a
    }

    return {
        "blocking_losses": losses,
        "advisories": advisories,
        "before": s_a,
        "after": s_b,
        "reduction_pct": reduction,
        "passed": not losses,
    }


def render(report: dict) -> str:
    out = []
    b, a, r = report["before"], report["after"], report["reduction_pct"]
    out.append("SIZE")
    out.append(f"  lines  {b['lines']:>6} -> {a['lines']:<6} ({r['lines']}%)")
    out.append(f"  chars  {b['chars']:>6} -> {a['chars']:<6} ({r['chars']}%)")
    out.append(f"  words  {b['words']:>6} -> {a['words']:<6} ({r['words']}%)")
    out.append("")

    if report["blocking_losses"]:
        out.append("BLOCKING LOSS — restore these before accepting the rewrite")
        for key, toks in report["blocking_losses"].items():
            out.append(f"  {key} ({len(toks)}):")
            for t in toks[:40]:
                flat = t if len(t) < 90 else t[:87] + "..."
                out.append(f"    - {flat!r}")
            if len(toks) > 40:
                out.append(f"    ... {len(toks) - 40} more")
        out.append("")
    else:
        out.append("BLOCKING LOSS — none")
        out.append("")

    if report["advisories"]:
        out.append(
            "ADVISORY — verify each was redundant restatement, not a dropped condition"
        )
        for adv in report["advisories"]:
            out.append(
                f"  {adv['kind']:<9} {adv['token']:<12} {adv['before']} -> {adv['after']}"
            )
    else:
        out.append("ADVISORY — none")

    return "\n".join(out)


def main() -> int:
    p = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    p.add_argument("original", type=Path)
    p.add_argument("compressed", type=Path, nargs="?")
    p.add_argument("--json", action="store_true", help="emit machine-readable report")
    p.add_argument(
        "--stats", action="store_true", help="size stats for one file, no comparison"
    )
    p.add_argument(
        "--ignore", type=Path, help="file of tokens (one per line) allowed to disappear"
    )
    args = p.parse_args()

    if args.stats:
        print(json.dumps(stats(args.original.read_text(encoding="utf-8")), indent=2))
        return 0

    if not args.compressed:
        p.error("COMPRESSED is required unless --stats is used")

    ignore: set[str] = set()
    if args.ignore and args.ignore.exists():
        ignore = {
            ln.strip()
            for ln in args.ignore.read_text(encoding="utf-8").splitlines()
            if ln.strip()
        }

    report = compare(
        args.original.read_text(encoding="utf-8"),
        args.compressed.read_text(encoding="utf-8"),
        ignore,
    )
    print(json.dumps(report, indent=2) if args.json else render(report))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except SystemExit:
        raise
    except Exception as exc:  # noqa: BLE001
        print(f"check_invariants: {exc}", file=sys.stderr)
        sys.exit(2)
