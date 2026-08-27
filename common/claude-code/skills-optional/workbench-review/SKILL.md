---
name: workbench-review
description: Run a workbench review sweep in a fresh forked context and return the report path. Invoke at the gates the workbench skill names — pre-merge before every 'workbench merge', sweep when a milestone's items are all archived, memory when .claude/memory changed — and otherwise only when the user asks.
argument-hint: "<sweep|pre-merge|docs|memory|adopt|watch> [\"scope: paths or words; no quotes, backticks, $ or backslash\"]"
arguments: reason scope
# Model-invocable on purpose: 'workbench merge' refuses without a passed
# pre-merge, and an unattended session has to be able to reach it. The fork
# is a fresh context either way, and the baseline below is taken before its
# first turn whoever started it: references/rationale.md, "Why the agent
# invokes the pre-merge review itself".
context: fork
agent: general-purpose
# background: false is load-bearing: the report path must come back in the
# invoking turn, so review-check and triage follow in the same sitting and a
# worker's review loop stays one step. Do not restore the default.
background: false
# The sweep's entire tool set; it also pre-approves the two preprocessed
# blocks below. No Edit, Bash bare: references/rationale.md, "Why the sweep's
# contract is not enforced by a hook".
allowed-tools: Read, Glob, Grep, Bash, Write
---

# Run a review sweep

You are running one sweep, now. Do the steps below and return.

## Contract

**Change nothing tracked. Write the report at the path below, and anything
you need under its scratch directory — nothing else.** Not the code, not
items, not `BACKLOG.md`, not `GLOSSARY.md`. Helper scripts, captured output,
probes: `workbench/scratch/<report>/`, which the skeleton names; it is ignored
by git and deleted with the report. If a finding is trivially fixable, record
the fix as a suggestion in the report — never apply it. Findings become items
only after triage, and that happens outside this fork.

## Report

The report already exists at the path below. It was created — and the tree's
state recorded — before your first turn, so nothing you do can hide from
`review-check`. For `watch`, the path is the shift's report, shared by every
tick: read it before writing, and append.

```!
${CLAUDE_SKILL_DIR}/scripts/open.sh "$reason" "$scope"
```

**If that output is not a path** — it starts with `workbench:`, or is any
other message — return it verbatim as your final message and do nothing
else. It is the reason no report was opened.

That path holds a skeleton with the reason and date. `Read` it before you
`Write` it — `Write` refuses a file it has not seen. For `watch`, never
`Write` it: the report is the shift's whole timeline, and a rewrite can drop
what earlier ticks recorded. Append through Bash instead —
`cat >> "<report>" <<'EOF' … EOF`. The one in-place edit a watch makes is
the liveness line, with `sed -i` on that line alone.

## Rules for this reason

```!
${CLAUDE_SKILL_DIR}/scripts/rules.sh "$reason"
```

## Steps

1. Sweep the scope. If none was given, sweep what the reason implies and say
   in the report what you covered — a reader cannot tell an unswept area from
   a clean one.

   The skeleton may list two things. Nested `CLAUDE.md` files under the scope:
   `Read` each before sweeping its area — they load on `Read` only, never on
   `cat`, `head` or `grep`. And, when the scope names paths, the files in
   scope: name every one you covered, or the directory with its trailing
   slash (`src/world/`) when you covered all of it. `review-check` fails on any
   file left unnamed — say why it was skipped rather than leaving it silent.

2. Write findings into the report. Each one carries evidence: the command and
   its real output, or the file and line as `path:line`. A finding without
   evidence is an opinion, and the user is triaging it blind. `review-check`
   resolves every `path:line` against the tree; one that points nowhere fails
   the report. There is no template; the shape follows the reason.

   Run whatever you need to *observe* — tests, greps, builds. Running a command
   is not modifying the tree; committing, editing, or fixing is.

3. For `pre-merge`, end the report with its verdict line as the rules say —
   `verdict: merge` or `verdict: hold — <what must change>` — last line, nothing
   after it.

4. Return **only the report path** as your final message. The invoking turn
   needs it and nothing else.
