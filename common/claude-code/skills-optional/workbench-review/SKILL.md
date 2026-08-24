---
name: workbench-review
description: Run a workbench review sweep in a forked context and return the report path.
argument-hint: "<sweep|pre-merge|docs|memory|adopt> [\"scope\"]"
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

The report is already open. It was created — and the tree's state recorded —
before your first turn, so nothing you do can hide from `review-check`.

```!
workbench review $reason $scope
```

That path is your one permitted write target. It holds a skeleton with the
reason and date.

## Rules for this reason

```!
${CLAUDE_SKILL_DIR}/scripts/rules.sh $reason
```

## Steps

1. Sweep the scope. If none was given, sweep what the reason implies and say
   in the report what you covered — a reader cannot tell an unswept area from
   a clean one.

2. Write findings into the report. Each one carries evidence: the command and
   its real output, or the file and line. A finding without evidence is an
   opinion, and the user is triaging it blind. There is no template; the shape
   follows the reason.

   Run whatever you need to *observe* — tests, greps, builds. Running a command
   is not modifying the tree; committing, editing, or fixing is.

3. Delete the skeleton's HTML comment, then return **only the report path** as
   your final message. The invoking turn needs it and nothing else.

   That comment holds the triage instructions, so the report arrives without
   them. This is deliberate: triage happens in the invoking context, and a
   report carrying instructions for its own disposal reads as if the sweep
   were running the triage.
