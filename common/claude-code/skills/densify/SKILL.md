---
name: densify
description: Losslessly restructure a markdown document so every fact becomes findable — prose into tables, obligations onto their own lines, conditions into "cond → outcome". Nothing recoverable is dropped, so use it when the document must survive intact: specs, RFCs, ADRs, runbooks, audit and handoff material, contracts, meeting notes. Triggers on "make this tighter", "denser", "more scannable", "restructure", "tabulate", or a request to make a document usable under time pressure. This is a readability transform, not a compression one — measured size change on already-dense material is 4–11%. If the goal is fitting a context budget by deleting over-explanation, use debloat instead.
---

# densify

Restructure a markdown document so that every fact, decision, and constraint in it becomes findable — without losing one of them. Grammar, flow, and literary quality are expendable. Data is not.

## What this skill actually delivers

**A losslessly restructured document — not fewer tokens.** This is the single most important thing to be honest with the user about, because the name and the word "densify" both suggest otherwise.

What is *measured* is the losslessness. What is *intended* is that the result is easier to find facts in, and that part has been tested and is **not** demonstrated — see "Do not oversell findability" below. Offer the guarantee, not the benefit.

Measured on three fact-dense documents (a wire spec, an operations runbook, and a tool-config reference), against a neutral scorer:

| | dense spec | runbook | config reference |
| ------------------------- | ------ | ------ | ------ |
| protected mass            | 47.6%  | 49.2%  | 40.0%  |
| token change              | −4.9%  | −4.5%  | −10.7% |
| share of removable glue   | 9.3%   | 8.9%   | 17.8%  |
| invariant tokens lost     | 0      | 0      | 0      |
| normative drift           | 0      | 0      | 0      |

These three are one consistent version. The threshold rule and Gate 4 were added afterwards; re-measuring the runbook with them cost 0.3 points of capture (8.9% → 8.6%) and removed all four defects, so treat the glue row as ~0.3 points optimistic. The spec and config reference were not re-run, which is why they are not mixed into the table.

Read the first row before the second. Forty to fifty per cent of these documents is protected mass — inline code, identifiers, numerals with units, obligation keywords — which a lossless rewrite may not touch. A 4.9% cut on a document that is half untouchable is 9.3% of everything that could have gone.

So the deliverable is a document where an operator under a page deadline finds the threshold in one scan instead of four paragraphs, and where every obligation sits on its own line. The size change is a footnote. A user who needs a document to fit a context budget is asking for `debloat`, and should be told so.

**Report the protected share alongside any size figure.** Without it the number is uninterpretable and reads as failure. Five successive versions of this skill were measured on these documents and the spread was 1.9% to 17.5% of glue — the differences came almost entirely from whether the telegraphic pass was applied exhaustively and whether splits were paired with hoists, not from anything the reader would call effort.

### Do not oversell findability

Findability is this skill's whole rationale, and it has been measured twice. Neither test showed the rewrite beating the source. Say so if asked; do not claim a lookup speedup.

Thirty single-answer questions were written against the runbook — thresholds, timeouts, host names, "which of these two limits applies when X" — and answered two ways:

| test | what the reader sees | source | this skill | bare "compress it" prompt |
| ------------------------------ | -------------------- | ------ | ------ | ------ |
| whole-document lookup          | the entire file      | 30/30  | 30/30  | not run |
| retrieval, top-1 chunk         | 1,200-char window    | 96.7%  | 96.7%  | 66.7%  |
| retrieval, top-3 chunks        | 1,200-char windows   | 100%   | 96.7%  | 80.0%  |

Two things follow, and they point in opposite directions:

- **Against the source, this transform is findability-neutral.** A reader holding the whole document is already saturated — restructuring cannot help someone who has read everything. Under retrieval it came out level at k=1 and one question *behind* at k=3. So the honest claim is the guarantee (nothing was lost, every obligation is on its own line, every threshold is in a cell), not a measured improvement in lookup.
- **Against a naive compression, the difference is enormous.** The bare-prompt output lost a third of the answers outright, because the facts were gone, not merely rearranged. That is the comparison that justifies using a skill at all.

Beware the instrument, too: an early version of the retrieval test chunked by line count, which handed the mega-paragraph source ~3,000 characters per window against the rewrite's ~600 and inverted the result. Findability tests reward whichever document wraps least unless the window is equalised on characters.

## The one failure mode that matters

"Shrink as much as possible" and "lose nothing" pull in opposite directions, and only one of them is measurable. Given both goals, the natural drift is to hit an impressive percentage by deleting the things that are cheap to delete and expensive to notice missing — qualifiers, exception clauses, units, the _why_ behind a decision.

So: **size change is a reported metric, never a target.** Never accept a percentage goal from the user as binding — say plainly that this transform does not produce percentages, and offer the measurement instead. The stop condition is "no further move available that does not lose meaning", not a number.

Do not compensate for a small number by reaching for content. In a controlled benchmark, a bare "compress this, preserve everything" prompt hit 10–18% on these same documents by losing 408, 86 and 81 invariant tokens, dropping 103 obligations and **inventing** 36 — on a runbook it took `MUST` from 75 to 15. That output looks authoritative and will get someone paged. A 4% rewrite that holds parity is the better artifact, every time.

## Workflow

1. **Measure and triage.** Read the whole doc. Check the refusal conditions below — they are about document _kind_, not about a size threshold. There is deliberately no minimum-reduction floor: an already-dense doc is the normal case here, and a 3% rewrite that makes 160 obligations individually findable is a success, not a refusal. Refuse on the rows in the table, not on a percentage.
2. **Plan before rewriting.** Emit a restructuring plan: for each section, the target form and the risk. Do this against the _whole_ document — a pattern repeated across four sections collapses to one table, and that move is invisible section-by-section. Do not put a projected percentage in the plan; project the target _form_ instead.
3. **Execute the ladder** in order (below). Steps 1–4 are near-lossless; step 5 is where damage happens, so it runs last and only on what survived.
4. **Verify** with `scripts/verify.py` until it exits 0, then the blind audit. Non-negotiable — see Verification.
5. **Report**: before/after sizes, the reduction achieved, what was cut and why, anything deliberately left alone.

Write output to `<name>.dense.md` alongside the original by default. Overwrite in place only on explicit instruction — this transform is lossy by nature and the user needs the original to check your work against.

## Never touch these

A rewrite eats these first unless they are explicitly fenced off:

| Category                                                  | Why it is fragile                                                      |
| --------------------------------------------------------- | ---------------------------------------------------------------------- |
| Numbers, units, thresholds, versions, dates               | "under 200ms" → "fast" is the single most common real loss             |
| Qualifiers: `unless`, `only if`, `except`, `not`, `up to` | Highest information density per token in any spec; first thing dropped |
| Identifiers: paths, env vars, flags, type/function names  | Must survive byte-identical or the doc is worse than useless           |
| Fenced code, inline code, URLs                            | Copy through verbatim. Never "tidy" them                               |
| Normative force: MUST / SHOULD / MAY                      | "should" → "recommended" changes what the reader is obliged to do      |
| Rationale in ADRs and design docs                         | The _why_ is the artifact, not redundancy around it                    |
| Anything you do not understand                            | Inability to see a fact's purpose is not evidence it has none          |

When two facts conflict in the original, preserve both and flag the contradiction. Silently picking one is a decision the author did not authorize.

## The ladder

Apply in this order. It is ordered by **ascending risk**, not by descending yield — the two do not correlate, and assuming they did was a design error in an earlier version of this skill.

1. **Meta-text.** Introductions that announce what the section will say, "as mentioned above", transitions, closing paragraphs that restate the opening. Typically 20–40% of a human-written doc and 40–60% of an LLM-written one, and near zero in a spec or runbook. Zero information loss.
2. **Restatement.** The same fact stated as prose, then as an example, then in a summary. Keep the single most precise form — usually the example, because it carries concrete values. Beware the false positive: in a runbook, the same threshold appearing in three sections is not restatement, because an operator reads one section mid-incident. Leave it and say you did.
3. **Structural conversion.** Repeated-shape prose → **labelled lines, not tables by default.** This is the readability payload, and the form you pick decides whether it also pays in tokens.

   Measured on five items sharing two attributes, taken from a real spec:

   | form                         | tokens | vs prose   | glue    |
   | ---------------------------- | ------ | ---------- | ------- |
   | original prose               | 101    | —          | 51      |
   | `\|` markdown table          | 100    | −1.0%      | 54 (up) |
   | `·`-separated labelled lines | 80     | **−20.8%** | 34      |

   Read that table honestly, because it is easy to over-claim from: `·` costs 2
   tokens in `o200k`, exactly what `, ` and ` and ` cost. So:

   - **table → `·` lines pays.** You drop a header row, a separator row, and two
     pipes plus two spaces per cell. Measured 10.5% on a document that was nine
     tables.
   - **prose → `·` lines does not pay.** Measured **+1.0%** and **+2.3%** on two
     prose-heavy documents. Labels must now be repeated on every line, and where
     labels are identifiers they are protected mass you just multiplied.

   Convert prose to lines anyway — one fact per line is the product — but do it
   for findability and expect the tokens to come from step 5. Never report a form
   conversion to the user as a saving.

   See Format selection.
4. **Hierarchy flattening.** Four heading levels each wrapping three lines → one table with a category column. Headings cost a line plus a blank line plus reading overhead; earn them.
5. **Telegraphic rewrite — the mechanism, not the afterthought.** Run it over every surviving line. It is mandatory, and skipped only on legal, safety, contractual or compliance text.

   Measured three times on three documents: **this is the only step that changes size.** On one spec, form conversion alone came in at **+2.3%** — an increase — and the same document reached −3.2% only once this pass was applied hard. Steps 1–4 buy findability. Step 5 buys tokens. A rewrite that reports a small number almost always skipped this pass or applied it to the first few sections and drifted.

   Apply every move on this list to every line:

   | move                            | before → after                                              |
   | ------------------------------- | ----------------------------------------------------------- |
   | drop articles                   | `the replica must close the socket` → `replica must close socket` |
   | drop copulas                    | ``frame_max`` is capped at 4 MiB` → `` `frame_max` capped 4 MiB`` |
   | drop `that` / `which`           | `a frame that exceeds` → `frame exceeding`                  |
   | denominalize                    | `perform a validation of` → `validate`                      |
   | `in order to` → `to`            | —                                                            |
   | passive → active                | `must be transmitted by the peer` → `peer must transmit`     |
   | drop the universal actor        | one-actor doc: `the operator must run X` → `must run X`      |
   | consequence → `→`               | `and therefore the connection closes` → `→ connection closes` |
   | shared subject → stem           | see Obligation stem hoisting                                 |

   **Sweep for residue before you report.** Agents consistently apply this pass to the first sections and drift. On a document that had run the pass "thoroughly", 63 occurrences of `be`, 25 of `is` and 31 of `that` were still sitting in the output. Before reporting, grep your own output for `\b(be|is|are|was|were|that|which|the|a|an)\b` and justify every survivor or remove it. A copula that survives is a token you chose to spend.

   **Never** touched by this pass, no exceptions: `unless`, `only`, `except`, `not`, `up to`, `at least`, `at most`, `while`, every unit, every number, every identifier, every normative keyword.

   **Keep `if` and `when` as written.** Collapsing both into `→` erases the difference between a condition and a point in time, and the deterministic gate only counts them in a bucket — it will not stop you. Use `→` for the *consequence* arm, never as a replacement for the condition marker.

## Obligation stem hoisting — the largest single move on a spec

A spec or runbook repeats a subject and a condition across every obligation that shares them. That repetition is the biggest removable mass in the document, and removing it is fully lossless.

Three sentences sharing a subject and a qualifier:

```
A replica must not reorder records inside a segment, even when two records share `commit_ts_us`.
A replica must not coalesce records inside a segment, even when two records share `commit_ts_us`.
A replica must not deduplicate records inside a segment, even when two records share `commit_ts_us`.
```

Hoist the shared part into a stem and keep **one modal per item**:

```
Replica, inside a segment, even when two records share `commit_ts_us`:
- must not reorder records
- must not coalesce records
- must not deduplicate records
```

62 tokens → 37, a 40% reduction on that passage, with `MUST NOT` still counting 3.

## Split and hoist are one move, never two

This is the most important rule in this skill, and getting it half-right costs more than not doing it.

Splitting a multi-obligation sentence onto separate lines makes each obligation addressable. It also **repeats the subject on every line**, and subjects in a spec are identifier-shaped — protected mass. Measured: a document split into one-obligation-per-line without hoisting gained 45 protected tokens and its capture fell from 6.9% to 4.0%. The findability was real; it was paid for in tokens that did not need to be spent.

So the two moves are a single operation:

```
A replica must not reorder records inside a segment.
A replica must not coalesce records inside a segment.
A replica must not deduplicate records inside a segment.
```

**Wrong** — split without hoist. Subject paid three times:

```
- A replica must not reorder records inside a segment
- A replica must not coalesce records inside a segment
- A replica must not deduplicate records inside a segment
```

**Right** — split and hoist together. Subject and shared condition paid once, modal still per item, count still 3:

```
A replica, inside a segment:
- must not reorder records
- must not coalesce records
- must not deduplicate records
```

**Whenever you split, check the resulting lines for a shared leading subject or condition and hoist it in the same edit.** Never leave a split block unhoisted and move on — you will not come back to it. If the items turn out not to share a subject, the split still stands; just say so.

Two obligations sharing a subject is enough to hoist. Do not wait for three.

**One obligation per line is legal in this version.** Earlier versions of this gate counted one statement per force class per source *sentence*, so splitting a sentence carrying three `must` clauses into three lines registered as two **invented** obligations. Three documents were measured against that gate and all three were damaged by it: 45 of one spec's 130 modal-bearing sentences carried 2+ same-class modals (52 blocked splits), 204 of 467 output lines were pushed past 80 columns to satisfy it, and one rewrite altered `never mid-segment` to `not mid-segment` purely to make the arithmetic work. The gate now counts each modal occurrence separately, so **split freely — one obligation, one line** — and expect the count to match.

**Keep the modal inside every item. This is not a style preference.** Hoisting the modal into the stem as well —

```
Replica must not, inside a segment:
- reorder records
```

— reads as one obligation to the gate, collapses `MUST NOT 3 → 1`, and is rejected. Measured, it also buys only 4 further tokens out of 37. There is no version of this worth failing parity for, so do not attempt it and do not propose a gate change to permit it.

### Never hoist a value the obligation is meaningless without

A subject hoists cleanly. A **threshold does not.** This is measured, not stylistic, and Gate 4 blocks on it.

```
Rebuilt node, for at least 2 h:
- must be brought back as replica
- must not be promoted
```

`must not be promoted` now carries no duration. Anything reading a window rather than the whole document — a retriever, a grep, a person scanning one screen — lands on the obligation without the number that defines it. The line is still fluent, complete-looking English, which is exactly why no other gate catches it. Write it as:

```
Rebuilt node:
- must be brought back as replica
- must not be promoted for at least 2 h
```

**Keep the number in the item.** Repeating `2 h` across three items costs about two tokens each; losing it costs the reader the obligation. Measured, the fix cost 0.3 points of capture and removed all four defects on a runbook.

Hoist subjects, actors and section scope freely. Never hoist a duration, threshold, count, version, or any qualifier of degree out of the line whose meaning depends on it.

**Do not over-apply this.** The two cases look alike and only one is a defect. On a wire spec, 8 of 8 hoists were *scope* hoists — stems naming the actor or trigger (`ERR_RATE_LIMIT`, `epoch`, `SIGHUP`) — where repeating the identifier per item is pure noise. "Fixing" those would have cost tokens to improve nothing. Gate 4 reports the two classes separately; act only on the ones it calls defects.

Test each hoisted block by reading one item alone with the stem covered. If the item is no longer actionable, put the value back.

Rules:

- **A hoisted block must fit in one screen.** If stem and items span more than ~15 lines, a reader or retriever will see items without the stem. Split into two blocks, each with its own stem.
- Hoist only what is **identical** across every item. A condition true of two items out of three stays in those two items.
- Never hoist across differing force. A `MUST` and a `SHOULD` sharing a subject are two stems, not one.
- Never hoist a condition into a stem and then add exceptions per item — the reader now has to compose stem and item to know what applies, and that is the decoder ring the readability floor forbids.
- The stem must be a grammatical lead-in that each item completes. Read stem + item aloud for every item before accepting it.

**Do not measure yourself in characters or lines.** Both mislead badly here. On the spec above, character count fell 5.8% while tokens fell 2.2% — most of the character saving was table alignment padding, which the tokenizer folds to nothing. Line count went _up_, 255 → 440, because the source packed mega-paragraphs and the output puts one rule per line. If a token figure is wanted, count tokens.

## Format selection

Make this mechanical, not aesthetic:

| Input shape                            | Output form                                  |
| -------------------------------------- | -------------------------------------------- |
| N items sharing **2–3** attributes     | `label · attr · attr` lines — **the default** |
| N items sharing **≥4** attributes      | `\|` table, N rows                            |
| Column alignment is itself the aid     | `\|` table (byte layouts, matrices, grids)    |
| Ordered steps with side effects        | numbered list                                |
| Condition → outcome pairs              | `cond → outcome` lines                       |
| Single causal chain                    | inline `A → B → C`                           |
| State transitions                      | `from · event · to` lines                    |
| Unordered non-parallel facts           | bullets                                      |
| One item                               | a sentence — never a one-row table           |

**The table is now the exception, not the default.** A `|` table costs a header
row, a separator row, and two pipes plus two spaces per cell. Measured against
the prose it replaces, that is a net token *loss* at 2–3 columns. It only starts
paying at ≥4 columns, or where the reader's eye needs aligned columns to compare
values down a column rather than read facts across a line.

**Never** emit a table whose purpose is to look organised. If you cannot name the
column-wise comparison a reader will make, use `·` lines.

**Readability floor** — this is where density and usability collide, and density loses:

- Every row or line must be understandable without reading its neighbours.
- No invented abbreviations, no symbol keys the reader has to learn. Density that ships with a decoder ring is not density. `·` as a field separator and `→` for causation are the two exceptions — both are self-evident in context and neither needs a legend.
- A `·` line stays on one screen line. **Hard limit 120 characters.** Past that the line is not findable and the whole point is lost. If a line exceeds it: split the obligations one per line (now legal — see stem hoisting), move a long field to an indented sub-line, or promote the block to a table. Never ship a 200-character `·` line and call it dense. Count them before you report: if any line exceeds 120 characters, say how many and why.
- Max ~5 columns in a table. Beyond that it wraps and becomes unreadable, which costs more than the lines it saved.
- Cells and fields hold values, not paragraphs. A field needing two sentences means the shape is wrong.
- Put the label first on every `·` line. The reader scans the left edge; a line whose distinguishing value is in field three is not findable.

Read `references/format-selection.md` for worked before/after conversions, including the cases where a table is the wrong answer.

## Verification

Three gates. A rewrite that has not passed all three is not finished.

**Gates 1 and 2 are one command, and the rewrite is not done until it exits 0:**

```bash
python3 scripts/verify.py ORIGINAL.md ORIGINAL.dense.md [--ignore ORIGINAL.ignore]
```

It prints `ACCEPTED` or `REJECTED` with every failure listed, and runs Gates 1, 2 and 4. The exit code is the verdict — do not read the sub-gate output and form your own view. Measured across a 4-arm benchmark, every skill whose gates were prose instructions rather than one command shipped an output that failed its own gates.

**Expect the gates to reject work you thought was finished.** Both times a gate was sharpened here, outputs that had already been accepted turned out to be defective: fixing the normative counter surfaced 6, 3 and 0 dropped obligations across three accepted documents, and adding Gate 4 rejected a fourth. That is the gate working, not the gate being pedantic.

### Gate 1 — deterministic (blocking)

Extracts numbers (unit-normalized, so `90 days` and `90d` match but `90 days` and `90 seconds` do not), code fences, inline code, URLs, and identifier-shaped tokens from both files, then reports what disappeared. Markdown scaffolding is stripped first, so a prose list becoming a table does not register as loss.

- Any loss listed is blocking. Restore the listed tokens; do not rationalize them away.
- Advisories flag drops in negation/condition/ordering/bound words. These are counted in semantic buckets, so a legitimate synonym swap nets to zero. A real drop means a condition may have vanished — check each one against the original before accepting. Normative keywords are no longer advisory; see Gate 2.
- `--ignore FILE` whitelists tokens that were genuinely redundant. Use sparingly; every entry is an assertion that you checked.
- `--json` for hook or CI integration. `--stats FILE` for sizes only.

This runs before showing the user anything. It catches most real loss for free.

### Gate 2 — normative parity (blocking)

Every force class — MUST / MUST NOT / SHOULD / SHOULD NOT / MAY / NEVER / ALWAYS — must come out unchanged in count. Dropping an obligation removes a constraint on the reader; inventing one imposes a constraint the author never wrote. Both are fatal and they do not cancel.

This gate is blocking rather than advisory because advisory did not work. Measured on three generated documents, this skill dropped 6, 19, and 9 normative statements and invented 2, 0, and 3 — while losing not a single number, identifier, or code span. Byte-safety on values and drift on obligations turn out to be independent properties, and only the first was being enforced.

**Each modal is counted by position, so one obligation per line is legal.** A source sentence carrying three `must` clauses becomes three lines with the count unchanged — split freely. An earlier counter keyed on the sentence and collapsed same-force repeats to one, which blocked 52 splits on one spec and 13 on another, forced 204 of 467 output lines past 80 columns, and pushed one rewrite into altering `never` to `not` purely to satisfy the arithmetic. It also hid real loss: re-scoring three previously-accepted outputs under the fixed counter found 6, 3 and 0 dropped obligations.

Two counter bugs are fixed and worth knowing about, because output can be written to trip them: a modal placed immediately after a `·` or `/` separator, and a soft line wrap falling between `must` and `not` (which read as `MUST`, inverting a prohibition). If a count looks wrong, check for those two shapes in your own output before assuming the rewrite is at fault.

There is **no disposition mechanism**. A nonzero delta is a defect to fix, not a finding to justify. A comparable skill shipped `should` 35 against a source's 61 while reporting acceptance, because it was allowed to write an explanation instead of a fix.

### Gate 3 — blind claim audit (semantic)

The deterministic gate cannot see a dropped _relationship_ — that step 3 depends on step 1, that the timeout applies only to retries. So:

1. Enumerate atomic claims from the **original**: subject–predicate–object plus every qualifier attached.
2. Have a reader with access to **only the compressed document** — no original in context — mark each claim `recoverable` / `ambiguous` / `lost`.
3. Restore anything not marked `recoverable`.

**Never treat this as the acceptance gate.** In a controlled benchmark, blind auditors returned 40/40 claim recall for outputs that had lost 26 identifiers and dropped 25 obligations. It measures whether a reader can reconstruct claims; it does not detect drift. Gates 1 and 2 decide acceptance.

The blindness is the entire point. A reader holding both texts will confirm recoverability from memory of the original, every time, and the audit becomes theater. Use a subagent where available; where not, read the compressed doc in isolation and be honest about what it alone supports. Protocol and claim-extraction format: `references/claim-audit.md`.

### Gate 4 — stranded thresholds (blocking)

Runs inside `verify.py`; there is no separate command. It is the one gate that reads the **output alone**, because this defect has no counterpart in the source to diff against — the transform introduces it. Measured on three documents, the pattern appears in the output and never in the source.

`scripts/hoist_audit.py` can be run standalone on any markdown file while drafting (exits 1 on defect), but acceptance comes from `verify.py`.

| gate | why it passes a stranded threshold |
| --------------------- | ---------------------------------- |
| 1, invariant tokens   | `2 h` is still in the document. It moved into the stem; it was not deleted. Set comparison passes. |
| 2, normative parity   | `must not be promoted` is still exactly one MUST NOT. Count and force unchanged. Passes. |
| 3, blind claim audit  | Has returned near-perfect recall on outputs missing 26 identifiers and 25 obligations. Has never caught this class. |

So without this gate all three can jointly certify a document in which an obligation reads complete and is not. It is also strictly cheaper than the retrieval test that first found the defect, which needs 30 hand-written questions per document and resolves to only 3.3 points per question.

The output separates two things that look alike — read the labels before fixing anything:

- **Defects** are hoisted *parameters*: a duration, threshold or count the obligation is about. Fix by putting the value back in the item, never by deleting the stem.
- **Scope hoists** are correct and are reported only for context. A stem naming the actor, subsystem or triggering condition (`ERR_RATE_LIMIT`, `epoch`, `SIGHUP`) is doing its job; repeating it per item is pure noise. Measured on a wire spec, 8 of 8 hoists were this kind and "fixing" them would have cost tokens to improve nothing.

## When to refuse or scope down

Say so plainly rather than damaging the document:

| Situation                                                    | Why                                                     |
| ------------------------------------------------------------ | ------------------------------------------------------- |
| Order of exposition _is_ the content (tutorials, onboarding) | Restructuring destroys the teaching sequence            |
| Persuasive or narrative documents                            | Rhetoric is the payload                                 |
| Legal, contractual, safety, or compliance text               | Redundancy there is deliberate and load-bearing         |
| Already fully tabular (a doc that is 60%+ table rows)        | Steps 3 and 4 have nothing to convert; say so           |
| The user's stated goal is a context budget                   | Wrong tool — route to `debloat` and say why          |

Note what is **not** on this list: "already-dense reference (API docs, specs)". Those are this skill's primary target, not a refusal. A spec is exactly the document where obligations need to be individually findable and where nothing may be deleted.

Partial application is fine and often correct: densify the reference sections of a doc, leave the walkthrough alone, and say which is which.

## Report format

Close with this, not with a description of how hard you worked:

Lead with the guarantee, not the percentage. The guarantee is what the user is buying.

```
lossless  verify.py ACCEPTED — 0 invariant tokens lost, normative parity exact
          (MUST 75 · MUST NOT 34 · NEVER 15 · MAY 15 · SHOULD 11 · ALWAYS 5)
findable  9 prose blocks → tables (shard map, lag gates, wal_status, exit codes);
          160 obligations now one per line; 14 conditionals → cond → outcome
tokens    13465 → 12918  (4.1%)   — incidental; this is not a compression tool
kept      every threshold, the "unless quorum is lost" clause, rationale in §4
left      §7 (tutorial — sequence is the content); §10 already tabular
flags     §3.1 and §5.1 contradict on the sh01 pool ceiling (60 vs 40) —
          present in the original, both preserved verbatim, not reconciled
```

If the size figure is small, state it without apology and without hunting for more. If the user wanted a budget saving, tell them this transform does not produce one and name `debloat`.
