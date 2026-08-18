#!/usr/bin/env python3
"""Find obligations that lost a defining value to a hoisted stem.

Stem hoisting is this transform's largest token move and its most dangerous one.
Pulling a shared lead-in out of N items is correct when the stem holds *scope* —
the actor, the subsystem, the triggering condition. It is a defect when the stem
holds a *parameter of the obligation itself*: a duration, a threshold, a count.
The item then reads as a complete rule while silently missing the number that
bounds it, and anything that sees a window rather than the whole document — a
retriever, a grep, a person scanning one screen — will act on the incomplete
version.

Found by the retrieval test, which lost exactly one question out of thirty:

    Rebuilt node, for at least 2 h:
    - must be brought back as replica
    - must not be promoted          <- carries no duration

Run this because the other three gates cannot see this defect, by construction:

  - `check_invariants.py` compares token *sets*. The `2 h` is still in the
    document — it moved into the stem, it was not deleted. Passes.
  - `normative.py` compares obligation counts and forces. `must not be promoted`
    is still exactly one MUST NOT. Passes.
  - The blind claim audit has returned near-perfect recall on outputs missing 26
    identifiers and 25 obligations. It has never caught anything of this kind.

So all three can jointly certify a document in which an obligation reads complete
and is not. Measured across three documents, the pattern appears in the output and
never in the source: it is introduced by this transform, not inherited.

The scope/parameter split is grammatical, not lexical. A quantity inside a
duration or limit frame ("for at least 6 h", "within 500 ms", "no more than 3")
is a parameter. A bare identifier naming what the rule is about (`ERR_RATE_LIMIT`,
`default_pool_size`) is scope, and repeating it in every item is noise. Both are
reported, but only the first is a defect — do not "fix" the second.

Exits 1 if any defect is found, 0 if clean, so it can gate a run.

    ./hoist_audit.py rewritten.md
    ./hoist_audit.py *.md
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

# A quantity in a duration/limit frame: the obligation is *about* this number.
PARAM_RE = re.compile(
    r"\b(?:for|within|after|before|at least|at most|no more than|not exceeding|"
    r"up to|every|per|beyond|under|over)\s+(?:at least\s+|at most\s+|about\s+)?"
    r"\d+(?:\.\d+)?\s*"
    r"(?:h|hr|hrs|hours?|m|min|mins|minutes?|s|sec|secs|seconds?|ms|d|days?|"
    r"weeks?|%|MB|GB|KB|TB|KiB|MiB|GiB|bytes?|entries|items|times|attempts|retries)?\b",
    re.IGNORECASE,
)

# Any value at all — used to tell "stem has something" from "stem has a parameter".
VALUE_RE = re.compile(
    r"`[^`]+`|\b\d+(?:\.\d+)?\s*"
    r"(?:h|m|s|ms|min|d|%|MB|GB|KB|TB|KiB|MiB|GiB)\b",
    re.IGNORECASE,
)

MODAL_RE = re.compile(r"\b(must|shall|should|may|never|always)\b", re.IGNORECASE)

BULLET = ("-", "*", "+")


def audit(text: str) -> dict:
    """Classify every obligation item sitting under a value-bearing stem."""
    lines = text.splitlines()
    stem: tuple[int, str] | None = None
    params: list[str] = []
    has_value = False
    defects: list[dict] = []
    scoped = 0

    for i, raw in enumerate(lines, 1):
        s = raw.strip()
        if not s:
            stem = None
            continue
        # A stem is a non-bullet, non-table, non-heading line ending in a colon.
        if s.endswith(":") and not s.startswith((*BULLET, "|", "#", ">")):
            stem = (i, s)
            params = [m.group(0) for m in PARAM_RE.finditer(s)]
            has_value = bool(VALUE_RE.search(s))
            continue
        if stem and s.startswith(BULLET) and MODAL_RE.search(s):
            # The item is only at risk if it carries no value of its own.
            if VALUE_RE.search(s) or PARAM_RE.search(s):
                continue
            if params:
                defects.append({
                    "stem_line": stem[0],
                    "stem": stem[1],
                    "item_line": i,
                    "item": s,
                    "stranded": params,
                })
            elif has_value:
                scoped += 1
        elif not s.startswith(BULLET):
            stem = None

    return {"defects": defects, "scope_hoists": scoped}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("paths", nargs="*")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    paths = list(args.paths)
    if not paths:
        ap.error("give one or more markdown paths")

    rows = []
    for p in paths:
        r = audit(Path(p).read_text())
        r["doc"] = Path(p).name
        rows.append(r)

    if args.json:
        print(json.dumps(rows, indent=2))
        return 0

    worst = 0
    for r in rows:
        n = len(r["defects"])
        worst = max(worst, n)
        verdict = "CLEAN" if n == 0 else f"{n} DEFECT(S)"
        print(f"\n=== {r['doc']}: {verdict}  "
              f"({r['scope_hoists']} scope hoist(s), correct — leave alone)")
        for d in r["defects"]:
            print(f"  L{d['stem_line']} stem: {d['stem'][:90]}")
            print(f"  L{d['item_line']} item: {d['item'][:90]}")
            print(f"       stranded in the stem: {d['stranded']}")

    if worst:
        print("\nEach defect is an obligation that reads complete but is not.")
        print("Fix by putting the value back in the item, not by removing the stem.")
    return 1 if worst else 0


if __name__ == "__main__":
    sys.exit(main())
