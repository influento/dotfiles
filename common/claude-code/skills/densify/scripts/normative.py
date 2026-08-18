#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Extract and classify normative statements in a markdown document.

Two jobs:

1. **Inventory.** Every obligation in the document, with its force and line.
   Comparing inventories before/after a rewrite is the check that caught drift
   in all nine runs of the previous benchmark, and that blind semantic auditors
   missed every time.

2. **Merge candidates.** Pairs of the shape "X should not do Y" followed by
   "X should do Z". Collapsing those to "X should do Z" is only lossless when Z
   entails not-Y; otherwise it silently deletes a constraint while looking like
   compression. This finds the candidates so a human can judge entailment. It
   deliberately does not judge entailment itself.

Usage:
    ./normative.py DOC.md
    ./normative.py DOC.md --json
    ./normative.py ORIGINAL.md --compare REWRITTEN.md
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from dataclasses import asdict, dataclass
from pathlib import Path

# Ordered longest-first so "must not" wins over "must".
FORCES: list[tuple[str, str]] = [
    (r"must not", "MUST NOT"),
    (r"shall not", "MUST NOT"),
    (r"should not", "SHOULD NOT"),
    (r"shouldn'?t", "SHOULD NOT"),
    (r"may not", "MAY NOT"),
    (r"do not", "MUST NOT"),
    (r"don'?t", "MUST NOT"),
    (r"never", "NEVER"),
    (r"always", "ALWAYS"),
    (r"must", "MUST"),
    (r"shall", "MUST"),
    (r"should", "SHOULD"),
    (r"required to", "MUST"),
    (r"is required", "MUST"),
    (r"are required", "MUST"),
    (r"may", "MAY"),
    (r"optional", "MAY"),
    (r"recommended", "SHOULD"),
]
FORCE_RE = re.compile(
    r"\b(" + "|".join(p for p, _ in FORCES) + r")\b", re.IGNORECASE
)
FORCE_LOOKUP = {p.replace(r"'?", "'").replace("(?:es)?", ""): f for p, f in FORCES}

NEGATIVE = {"MUST NOT", "SHOULD NOT", "MAY NOT", "NEVER"}

FENCE_RE = re.compile(r"^\s*(?:```|~~~)")
SENT_SPLIT_RE = re.compile(r"(?<=[.!?;])\s+(?=[A-Z`\"'(])")

# Leading scaffolding that is not part of the subject.
LEAD_STRIP_RE = re.compile(
    r"^(?:[-*+]\s+|\d+\.\s+|>\s*|\|\s*|#+\s+|note:\s*|important:\s*)+", re.IGNORECASE
)
STOPWORDS = {
    "the", "a", "an", "this", "that", "these", "those", "it", "its", "their",
    "your", "you", "we", "our", "each", "every", "any", "all", "and", "but",
    "or", "if", "when", "then", "also", "however", "therefore", "for", "to",
    "in", "on", "of", "by", "with", "as", "at", "is", "are", "be", "will",
    "handlers", "handler",
}


def classify(match_text: str) -> str:
    key = match_text.lower()
    for pattern, force in FORCES:
        if re.fullmatch(pattern, key, re.IGNORECASE):
            return force
    return "SHOULD"


@dataclass
class Statement:
    line: int
    force: str
    subject: str
    text: str

    def row(self) -> str:
        return f"{self.line:5d}  {self.force:<9}  {self.subject:<22.22}  {self.text:.96}"


def subject_of(prefix: str) -> str:
    """Crude subject extraction: content words immediately before the modal."""
    prefix = LEAD_STRIP_RE.sub("", prefix).strip()
    prefix = re.sub(r"[`*_]", "", prefix)
    words = re.findall(r"[A-Za-z][A-Za-z0-9_./-]*", prefix)
    content = [w for w in words if w.lower() not in STOPWORDS]
    tail = content[-3:] if content else words[-3:]
    return " ".join(tail).lower() or "(none)"


INLINE_CODE_RE = re.compile(r"`[^`]*`")

# Modal-shaped text that is not deontic. Narrow on purpose: every exclusion here
# is a chance to hide real drift, so only patterns that cannot be an obligation
# on the reader belong.
NON_DEONTIC_RE = re.compile(
    r"""(?ix)
      may \s+ well            # epistemic likelihood, not permission
    | recommended \s+ by      # citation of outside opinion, not a recommendation
    | as \s+ recommended
    # "don't" is not always a prohibition. Bare negated-do was counted as MUST NOT
    # unconditionally, which made "Don't worry if this seems complex" -- the phrase
    # this skill's own contract names as deletable audience scaffolding -- an
    # unwaivable obligation the gate refused to let go. Only the descriptive
    # complements are excluded; "Do not use this field" is still a real MUST NOT.
    | do (?: es )? \s* n (?: ['\u2019] t | ot ) \s+
        # NB: "forget" is deliberately absent -- "Don't forget to restore the
        # reclaim policy" is an imperative meaning *do it*, and dropping it lost a
        # real obligation in two corpus documents.
        (?: worry | need | have \s+ to | want )
    """
)


# A soft wrap between a modal and its negation flips the force class: "must\nnot
# reorder" reads as MUST, not MUST NOT. That is the worst direction a gate can be
# wrong in — a prohibition silently becoming a requirement, and parity still
# balancing because one class gained what the other lost. Markdown wraps
# wherever the author's editor did, so this is not hypothetical; it was hit in a
# live rewrite. Join only that exact shape, and keep the first line's number.
TRAILING_MODAL_RE = re.compile(r"\b(?:must|shall|should|may|do|does)\s*$", re.IGNORECASE)
LEADING_NOT_RE = re.compile(r"^\s*not\b", re.IGNORECASE)


def logical_lines(text: str) -> list[tuple[int, str]]:
    """(line number, text) with modal/negation wraps rejoined."""
    raw = text.splitlines()
    out: list[tuple[int, str]] = []
    skip = False
    for i, line in enumerate(raw):
        if skip:
            skip = False
            continue
        if (
            i + 1 < len(raw)
            and TRAILING_MODAL_RE.search(line)
            and LEADING_NOT_RE.match(raw[i + 1])
        ):
            out.append((i + 1, line.rstrip() + " " + raw[i + 1].lstrip()))
            skip = True
            continue
        out.append((i + 1, line))
    return out


def extract(path: Path) -> list[Statement]:
    """Deontic statements only.

    Three sources of false positives are suppressed, because an inflated
    baseline count makes a genuine post-rewrite drop invisible:

    - Inline code: `should` named as a keyword is a mention, not an obligation.
    - Third person "does not": descriptive ("the list does not register as
      loss"), unlike imperative "do not", which is an instruction.
    Note what is deliberately NOT suppressed: two `must` clauses in one
    sentence count as two obligations. They are two things the reader has to do,
    and collapsing them hides a drop when a rewrite keeps one and loses the
    other.
    """
    text = path.read_text(encoding="utf-8")
    statements: list[Statement] = []
    seen: set[tuple[int, str, str]] = set()
    in_fence = False
    for lineno, line in logical_lines(text):
        if FENCE_RE.match(line):
            in_fence = not in_fence
            continue
        if in_fence or not line.strip():
            continue
        # Blank out inline code, preserving offsets so subjects stay aligned.
        line = INLINE_CODE_RE.sub(lambda m: " " * len(m.group(0)), line)
        for sentence in SENT_SPLIT_RE.split(line):
            for m in FORCE_RE.finditer(sentence):
                window = sentence[m.start() : m.start() + 40]
                if NON_DEONTIC_RE.search(window) or NON_DEONTIC_RE.search(
                    sentence[max(0, m.start() - 20) : m.end() + 20]
                ):
                    continue
                force = classify(m.group(1))
                # Keyed on the modal's position, not on the sentence. Keying on
                # the sentence collapsed N same-force modals in one sentence to
                # one, which made "must A, must B, and shall C" impossible to
                # split into three findable lines without the gate reporting two
                # invented obligations. Measured on three documents: 52 blocked
                # splits on one spec, 13 on another, 204 of 467 lines forced past
                # 80 columns, and one rewrite altered "never" to "not" purely to
                # satisfy the arithmetic. The dedupe's own stated rationale was a
                # row enumerating MUST / SHOULD / MAY — but those are different
                # forces, which this key has always separated anyway.
                key = (lineno, sentence.strip(), force, m.start())
                if key in seen:
                    continue
                seen.add(key)
                statements.append(
                    Statement(
                        line=lineno,
                        force=force,
                        subject=subject_of(sentence[: m.start()]),
                        text=sentence.strip(),
                    )
                )
    return statements


def merge_candidates(
    statements: list[Statement], window: int = 3, max_line_gap: int = 6
) -> list[tuple[Statement, Statement]]:
    """Negative statement followed closely by a positive one on the same subject.

    These are the pairs whose collapse is lossless only under entailment.

    Both a statement window and a line gap are required. The window alone
    matched statements 46 lines apart that merely shared a subject word — two
    unrelated obligations, not a mergeable pair. Proximity is what makes the
    pattern real: the merge only makes sense when an author wrote the negative
    and the positive as one thought.
    """
    pairs = []
    for i, first in enumerate(statements):
        if first.force not in NEGATIVE:
            continue
        if not first.subject or first.subject == "(none)":
            continue
        for second in statements[i + 1 : i + 1 + window]:
            if second.force in NEGATIVE:
                continue
            if second.line - first.line > max_line_gap:
                continue
            a, b = set(first.subject.split()), set(second.subject.split())
            if a & b:
                pairs.append((first, second))
                break
    return pairs


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("doc")
    ap.add_argument("--compare", help="rewritten document to diff the inventory against")
    ap.add_argument("--window", type=int, default=3)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    src = extract(Path(args.doc).expanduser())
    counts = Counter(s.force for s in src)
    pairs = merge_candidates(src, args.window)

    if args.json:
        out = {
            "doc": args.doc,
            "counts": dict(counts),
            "statements": [asdict(s) for s in src],
            "merge_candidates": [
                {"negative": asdict(a), "positive": asdict(b)} for a, b in pairs
            ],
        }
        if args.compare:
            dst = extract(Path(args.compare).expanduser())
            out["compare"] = {
                "doc": args.compare,
                "counts": dict(Counter(s.force for s in dst)),
            }
        print(json.dumps(out, indent=2))
        return 0

    print(f"# {args.doc}\n")
    print(f"{len(src)} normative statements")
    for force, n in counts.most_common():
        print(f"  {force:<9} {n}")

    print(f"\n## inventory\n")
    print(" line  force      subject                 text")
    for s in src:
        print(s.row())

    print(f"\n## merge candidates ({len(pairs)})")
    if not pairs:
        print("  none — the negative-then-positive pattern does not occur here")
    for a, b in pairs:
        print(f"\n  L{a.line} [{a.force}] {a.text[:110]}")
        print(f"  L{b.line} [{b.force}] {b.text[:110]}")
        print(f"    -> collapse is lossless only if the second entails not-({a.force.lower()} clause)")

    if args.compare:
        dst = extract(Path(args.compare).expanduser())
        dcounts = Counter(s.force for s in dst)
        print(f"\n## inventory diff vs {args.compare}\n")
        print("  force      before  after   delta")
        for force in sorted(set(counts) | set(dcounts)):
            b, a = counts.get(force, 0), dcounts.get(force, 0)
            flag = ""
            if a < b:
                flag = "  <-- dropped; each needs an entailing survivor"
            elif a > b:
                flag = "  <-- INVENTED obligation"
            print(f"  {force:<9}  {b:6d}  {a:5d}  {a - b:+6d}{flag}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
