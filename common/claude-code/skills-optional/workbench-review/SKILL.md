---
name: workbench-review
description: Run a workbench review sweep in a forked context and return the report path.
argument-hint: "<sweep|pre-merge|docs|memory|adopt> [\"scope: letters digits spaces hyphens\"]"
arguments: reason scope
disable-model-invocation: true
context: fork
agent: general-purpose
# background: false is load-bearing twice over. A backgrounded fork runs with the
# narrower background-subagent tool set, which may not include the write this
# sweep exists to perform; and the report path must come back in the invoking
# turn so triage happens in the same sitting. Do not restore the default.
background: false
# This list is the sweep's entire tool set, and it pre-approves the two
# preprocessed blocks below. Bash stays bare: the sweep greps, builds and runs
# tests. Edit is left out on purpose — it removes the convenient way to change
# a file, nothing more; 'workbench review-check' is the real gate.
allowed-tools: Read, Glob, Grep, Bash, Write
---

# Run a review sweep

You are running one sweep, now. Do the steps below and return.

## Contract

**Write exactly one file: the report at the path below. Modify nothing else.**
Not the code, not items, not `BACKLOG.md`, not `GLOSSARY.md`. If a finding is
trivially fixable, record the fix as a suggestion in the report — never apply
it. Findings become items only after the user triages them, and that happens
outside this fork.

## Report

The report already exists at the path below. It was created — and the tree's
state recorded — before your first turn, so nothing you do can hide from
`review-check`.

```!
workbench review "$reason" "$scope"
```

That path is your one permitted write target. It holds a skeleton with the
reason and date. `Read` it before you `Write` it — `Write` refuses a file it
has not seen.

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

3. Return **only the report path** as your final message. The invoking turn
   needs it and nothing else.
