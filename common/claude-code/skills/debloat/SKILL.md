---
name: debloat
description: Cut the token cost of over-explained documentation by deleting explanation of general concepts, derivable prose, and restatement, while preserving every system-specific fact byte-exact. Use for AI-generated or AI-assisted docs, onboarding guides, wikis, and design docs that explain background concepts the reader already knows, restate the same fact across overview and detail sections, or spend most of their length on prose that carries no number, identifier, or code. Use when a document must fit in a context budget. For losslessly restructuring an already-focused doc into tables and telegraphic lines, use densify instead.
---

# debloat

Reduce a document to the part that is about *this system*. Everything else goes.

## Routing

| Use | When |
| --- | --- |
| `debloat` | The doc explains things not specific to its subject; you want fewer tokens; some content may be lost by design |
| `densify` | Nothing may be lost; the doc is already focused and needs restructuring into tables and telegraphic lines |

Both may run: debloat first, then densify what survives.

## The contract

This skill is **lossy on purpose**, which makes its boundary the whole design. Loss is confined to one axis and forbidden on all others.

**May be deleted:**

| Category | Test |
| --- | --- |
| General-concept explanation | Would this sentence be true, unchanged, in a document about a different system? Then it is background, not content |
| Derivable prose | Can a reader reconstruct the sentence from what remains? Applies to prose only — a table of values stays even when a formula above it generates them. See Numbers |
| Restatement | The same fact in the overview, the walkthrough, and the summary. Keep the most precise instance, usually the one with concrete values |
| Executive summaries that only restate the body | If it introduces nothing, it is navigation, and headings already do that |
| Salience assertions | "X is a critical aspect of Y." If X is critical, the rest of the document shows it; if it does not, the sentence was the only evidence and it was never enough |
| Vacuous qualifiers | "Write a **short** extension." The size is whatever does the job |
| Audience scaffolding | "Don't worry if this seems complex", "we'll come back to this later" |

**May never be touched:**

| Category | Why |
| --- | --- |
| Numbers, units, thresholds, ranges, versions, dates | The single most common real loss |
| Identifiers: paths, env vars, flags, endpoints, field names, error codes, metric names | Must survive byte-identical |
| Fenced code, inline code, URLs | Copy through verbatim |
| Normative statements: MUST / SHOULD / MAY / NEVER | See Gate 2. Parity is absolute |
| Qualifiers: `unless`, `only if`, `except`, `up to` | Highest information density per token in any spec |
| Rationale specific to this system | *Why we chose Postgres over Redis here* is content. *What Postgres is* is not |
| Anything you do not understand | Inability to see a fact's purpose is not evidence it has none |

## The general/specific boundary

This is the only judgment the skill makes, so make it explicitly, per passage.

The test: **would this sentence survive unchanged in a document about a different system?**

Worked example, from a retry-policy section:

| Passage | Verdict |
| --- | --- |
| "Retrying immediately makes things worse; the dependency is failing because it is overloaded. This is called a retry storm." | **General.** True of every queue ever built. Delete |
| "With pure exponential backoff a thousand failed jobs retry in synchronised spikes — a thundering herd." | **General.** Delete |
| "Warden uses full jitter: delay is drawn uniformly from zero to the computed ceiling, not ceiling ± a small random amount." | **Specific.** The definition is needed to read the formula. Keep |
| "Jitter is not configurable and will not be made configurable." | **Specific.** A constraint on the reader. Keep |
| "delay = random(0, min(10s * 2^(attempt-1), 6h))" | **Specific.** Keep byte-exact |
| An 8-row table of backoff values for attempts 1-10 | **Keep**, despite being derivable from the formula above it. Numbers do not leave except with a deleted passage — see Numbers |

Deleting general explanation retargets the document from a novice reader to a competent one. That is the intended trade and the user has accepted it — but say so in the report, because it is the one loss that is invisible in the diff.

**Never delete a concept explanation that the document then depends on.** If a later section says "because of the thundering-herd problem described above", either keep enough of the explanation to support the reference or rewrite the reference. Dangling back-references are the characteristic bug of this skill.

## Numbers

Numbers are the highest-risk loss and the hardest to notice missing, so they get their own rule rather than living inside the general/specific judgment.

**A number may leave only when the passage containing it is deleted whole, and only if that number appears nowhere else in the document.** Both conditions are checkable. The second is what makes this a narrow waiver rather than a licence: a value used anywhere else is a specification, whatever the passage around it looked like.

In practice this splits cleanly:

| Number | Verdict |
| --- | --- |
| "Warden honours 1 to 21600 (6 h) inclusive" | Specification. Never |
| "all thousand retry at 10 s, then 20, then 40, and so on" — inside a deleted thundering-herd explanation | Illustration. Leaves with its passage |
| A table of backoff values generated by a formula above it | Stays. Derivability is not deletability, and a model asserting "derivable" is the failure mode this project has measured repeatedly |

Every waived number goes in an ignore file, one per line, each naming the section it left with:

```bash
scripts/verify.py ORIGINAL.md ORIGINAL.debloat.md --ignore ORIGINAL.ignore
```

`verify.py` audits the file rather than reading your comments. It rejects a waiver for a token that is still present in the output, and prints each waived token's occurrence count in the source — flagging any that appear in more than one place, since a token in several places did not leave with a single passage no matter what the comment beside it says. That check exists because a real run waived two section ordinals as "appears nowhere else in the source" while one of them had a live cross-reference in a section that survived.

An ignore file of three enumerated values, each with a machine-checked count beside it, is auditable in seconds. That is what separates it from a free-text justification.

### Write the ignore file from what left, never from what you meant to remove

**Build it last, by checking the output.** For each candidate entry, confirm the token is actually absent from the finished file before writing the line. A waiver is an assertion that something left; if it is still there, the assertion is false and the gate rejects the run.

This is measured, not hypothetical. One accepted-looking run shipped a five-entry ignore file in which **four tokens appeared in the output exactly as often as in the source** — `0.4%`, `3.1%`, `0.4` and `[-0.4%, +3.1%]`, all still present, none ever removed — while the fifth (`29`) went 10 → 8. The file described an intended edit, not a performed one. Nothing in it was true.

The same run failed in the opposite direction on the same document: it deleted the clause `— because the user never reached the code path —` and waived nothing, so `NEVER` came out 19 → 18 and the run was rejected. Deleting a parenthetical gloss is legitimate here; deleting it **silently** is not.

So both directions are defects, and they are the same defect:

| symptom | what it means |
| ---------------------------------------- | ------------------------------------------------ |
| waived token still present in the output | you asserted a deletion you did not make |
| normative count dropped, nothing waived   | you made a deletion you did not declare |

**The run is not finished until `verify.py` exits 0.** Writing the ignore file is not the last step — re-running the gate is. If it still rejects, the ignore file is wrong or the edit is; fix one of them and run again. Do not ship a rejected run with an ignore file attached, which is how both failures above reached the output.

One consequence worth internalising: deleting a clause that contains `never`, `must`, `shall`, `should` or `may` will move a force count even when the surrounding obligation survives intact. That is not a bug in the counter — it is the counter noticing. Either keep the clause or waive it explicitly.

## Section numbering

**Never renumber sections.** Deleting §13.2 leaves §13.1, §13.3, §13.4 — a visible gap and correct cross-references. Closing the gap silently breaks every reference elsewhere in the document, and those references are usually outside the part you are looking at.

## Contradictions

Compression surfaces conflicts that were hidden by distance — a table on page 4 disagreeing with a formula on page 3. **Never resolve them.** Preserve both figures and flag the conflict in a callout. Silently picking one is a decision the author did not authorize, and the compressed doc looks authoritative enough that nobody will re-check it.

## Workflow

1. **Read the whole document.** Structural decisions made mid-rewrite are consistently worse.
2. **Baseline.** Record token count and the normative inventory before touching anything:
   `scripts/normative.py DOC.md --json > DOC.norm.json`
3. **Classify, do not rewrite yet.** Mark each passage general / specific / derivable / restated. Big wins are whole sections.
4. **Delete, then tighten.** Deletion first — there is no point tightening prose that is about to go.
5. **Verify.** `scripts/verify.py` until it exits 0. Non-negotiable, and not satisfied by reading its output and deciding you disagree.
6. **Report.** Paste the final `ACCEPTED` line verbatim.

Write output to `<name>.debloat.md`. Overwrite in place only on explicit instruction: this transform is lossy and the user needs the original to check against.

## Gates

**Run one command. The rewrite is not finished until it exits 0:**

```bash
scripts/verify.py ORIGINAL.md ORIGINAL.debloat.md [--ignore ORIGINAL.ignore]
```

It runs both gates and prints `ACCEPTED` or `REJECTED` with every failure listed. Do not read the sub-gates' output and form your own opinion; the exit code is the verdict.

This exists because documenting two gates is not the same as running them. In the benchmark that produced this skill, the arm following this very document shipped an output that failed the invariant gate, with no waiver file, because the gates were prose instructions instead of one command with an exit code.

Both are blocking and both are deterministic. **There is no disposition mechanism.** A nonzero delta is a failure to fix, not a finding to explain away. Skills that let the model write a justification for its own drift ship the drift — that is measured behaviour, not a hypothetical.

### Gate 1 — invariants

Numbers (unit-normalized), code fences, inline code, URLs, identifiers. Any loss means a value disappeared.

### Gate 2 — normative parity

Every force class must come out `+0`. Two failure directions, both fatal:

- **Dropped** obligations mean a constraint on the reader vanished.
- **Invented** obligations are the more insidious half. A compressor writing connective prose reaches for "must" and "should" unprompted; in nine measured runs of comparable skills, every single one introduced normative drift, and no blind semantic auditor caught any of it.

Parity is on counts per force class, so a legitimate rephrase that keeps the force nets to zero. Each modal is counted by position, so a sentence carrying three `must` clauses counts three: keeping one and dropping two is caught. An earlier counter keyed on the sentence and collapsed them to one — re-scoring this skill's own accepted outputs under the fix surfaced one `NEVER` dropped on a document previously reported clean. If a passage carrying an obligation is genuinely general-concept material, the obligation is not general — restate it in the compressed doc and delete the surrounding explanation.

### Optional — blind recoverability check

For high-stakes documents: enumerate atomic claims from the original, then have a reader with access to **only** the compressed doc mark each `recoverable` / `ambiguous` / `lost`. Expect and accept losses in the general-concept bucket; anything else is a defect. The blindness is the whole point — a reader holding both texts confirms from memory every time.

## When to refuse or scope down

| Situation | Why |
| --- | --- |
| Tutorials and teaching material | Explaining general concepts *is* the deliverable |
| Legal, contractual, safety, compliance | Redundancy is deliberate and load-bearing |
| Already-focused reference docs | Use `densify`; there is no general-concept mass to remove |
| Reader is stated to be a novice | The core transform is the wrong one for that audience |

Partial application is normal: debloat the reference sections, leave the tutorial chapter, and say which is which.

### A small reduction is a result, not a refusal

**Never discard an output that passes the gate.** If the transform runs clean and the
cut is 8%, deliver the 8% and say it is 8%. Two independent runs on real system
documentation built a complete compressed candidate, ran the gate, got `ACCEPTED`,
and then **threw the whole thing away** because the cut was under 20% — handing back
nothing when they were holding a verified-correct result. A third spent four extra
passes climbing from 9.2% to 20.1% to clear the same number, which is the pressure
this skill exists to resist.

There is no minimum. The number to report is whatever was measured:

- Gate passes -> deliver it, lead with the measured cut, note that it is small.
- Nothing left to delete without touching protected mass -> say so and recommend
  `densify`. That is the refusal, and it is about *available mass*, not a percentage.

Refuse on the table above, on the document's kind. Never on the size of the result.

## Report format

```
tokens    12,493 -> 5,140  (59% cut)
deleted   S2 (what a job queue is), S5.1 thundering-herd explanation,
          backoff value table (derivable from the formula), 3 restated summaries
kept      all thresholds, error codes, field names, the 1-21600 Retry-After range
audience  retargeted novice -> competent; general-concept explanation removed
flags     S13.4 table contradicts its own formula (attempt 10 -> 1.4h, not capped);
          both figures preserved, unresolved in source
gates     invariants PASS - normative parity PASS (MAY 1->1, MUST 4->4, NEVER 2->2)
```
