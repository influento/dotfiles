#!/usr/bin/env python3
"""Single acceptance gate. Exit 0 means accepted.

Exists because both gates being documented in a markdown file is not the same
as both gates being run. Measured on a 4-arm benchmark over three 12k-28k token documents: every arm
whose gates were prose instructions rather than one command with an exit code
shipped at least one output that failed its own gates, in the worst case dropping
19 obligations while reporting success. One entry point, one verdict, nothing to
skip.

Usage:
    verify.py ORIGINAL.md COMPRESSED.md [--ignore FILE]
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent


def run(script: str, *args: str) -> dict | None:
    r = subprocess.run(
        [sys.executable, str(HERE / script), *args, "--json"],
        capture_output=True,
        text=True,
    )
    try:
        return json.loads(r.stdout) if r.stdout.strip() else None
    except json.JSONDecodeError:
        return None



def count_token(text: str, token: str) -> int:
    """Occurrences of token as a standalone span, not as a substring.

    Naive substring counting is actively misleading here: "8812" appears inside
    every "acct_8812", and "2.1" inside every "12.1". A waiver audited with
    substring counts reads as busy when the token occurs exactly once.
    """
    return len(re.findall(rf"(?<![\w.]){re.escape(token)}(?![\w.])", text))


def audit_waivers(original: str, compressed: str, ignore_path: str | None) -> list[tuple]:
    """Check what an ignore file asserts, rather than reading its comments.

    A waiver says a token left with a passage that was deleted whole. Two parts
    of that are mechanical, so they are checked rather than trusted:

      - the token must actually be absent from the output, or the waiver is
        noise that hides a real loss behind it;
      - its occurrence count in the source is reported, because a token present
        in several places did not leave with one passage, whatever the comment
        next to it claims. Observed in practice: a waiver asserting "appears
        nowhere else in the source" for an ordinal that also had a live
        cross-reference in a surviving section.
    """
    if not ignore_path:
        return []
    try:
        lines = Path(ignore_path).read_text(encoding="utf-8").splitlines()
    except OSError:
        return []
    src = Path(original).read_text(encoding="utf-8")
    dst = Path(compressed).read_text(encoding="utf-8")
    out = []
    for raw in lines:
        tok = raw.strip()
        if not tok or tok.startswith("#"):
            continue
        out.append((tok, count_token(src, tok), count_token(dst, tok)))
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("original")
    ap.add_argument("compressed")
    ap.add_argument("--ignore")
    args = ap.parse_args()

    inv_args = [args.original, args.compressed]
    if args.ignore:
        inv_args += ["--ignore", args.ignore]

    waivers = audit_waivers(args.original, args.compressed, args.ignore)

    inv = run("check_invariants.py", *inv_args)
    src = run("normative.py", args.original)
    dst = run("normative.py", args.compressed)
    # Runs on the output alone: this defect is introduced by the rewrite and has
    # no counterpart in the source to compare against.
    hoist = run("hoist_audit.py", args.compressed)

    if inv is None or src is None or dst is None or hoist is None:
        print("REJECTED - a gate failed to run; do not accept on a broken gate")
        return 2

    failures: list[str] = []

    losses = inv.get("blocking_losses", {})
    for bucket, items in sorted(losses.items()):
        if items:
            failures.append(
                f"invariant {bucket}: {len(items)} lost -> {', '.join(map(str, items[:8]))}"
            )

    a, b = src.get("counts", {}), dst.get("counts", {})
    for force in sorted(set(a) | set(b)):
        before, after = a.get(force, 0), b.get(force, 0)
        if after < before:
            failures.append(f"normative {force}: {before} -> {after} (dropped {before - after})")
        elif after > before:
            failures.append(f"normative {force}: {before} -> {after} (INVENTED {after - before})")

    for tok, in_src, in_out in waivers:
        if in_out:
            failures.append(
                f"waiver {tok!r}: still present {in_out}x in the output - waive only what left"
            )

    scope_hoists = 0
    for doc in hoist:
        scope_hoists += doc.get("scope_hoists", 0)
        for d in doc.get("defects", []):
            failures.append(
                f"stranded {d['stranded']} in stem L{d['stem_line']}: "
                f"L{d['item_line']} {d['item'][:60]!r} reads complete but is not"
            )

    if failures:
        print("REJECTED")
        for f in failures:
            print(f"  {f}")
        print("\nRestore the listed items. There is no disposition mechanism:")
        print("a waiver is an --ignore entry naming the deleted passage, or it is a defect.")
        print("For a 'stranded' failure, put the value back in the item - never delete")
        print("the stem, and never touch a hoist the audit did not name.")
        return 1

    print("ACCEPTED - invariants intact, normative parity held, no stranded thresholds")
    if scope_hoists:
        print(f"  {scope_hoists} scope hoist(s) found and accepted - these are correct")
    for tok, in_src, in_out in waivers:
        note = "" if in_src <= 1 else "   <-- occurs in more than one place; verify each site was deleted"
        print(f"  waived {tok!r}: {in_src}x in source, {in_out}x in output{note}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
