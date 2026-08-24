---
name: workbench-review
description: Run a workbench review sweep in a forked context and return the report path.
argument-hint: "<sweep|pre-merge|docs|memory|adopt> [scope]"
arguments: reason scope
disable-model-invocation: true
context: fork
agent: general-purpose
# background: false is load-bearing twice over. A backgrounded fork runs with the
# narrower background-subagent tool set, which may not include the write this
# sweep exists to perform; and the report path must come back in the invoking
# turn so triage happens in the same sitting. Do not restore the default.
background: false
---

# Run a review sweep

You are running one sweep, now. Do the steps below and return.

## Contract

**Write exactly one file: the report path printed in step 1. Modify nothing
else.** Not the code, not items, not `BACKLOG.md`, not `GLOSSARY.md`. If a
finding is trivially fixable, record the fix as a suggestion in the report —
never apply it. Findings become items only after the user triages them, and
that happens outside this fork.

## Steps

**Step 1 first, before reading or running anything.** It records the state of
the tree, and that record is what proves afterwards that you wrote only your
report. Work done before it is invisible to that proof.

1. Open the report:

   ```bash
   workbench review $0 $1
   ```

   It prints the path and writes a skeleton holding only the reason and date.
   That path is your one permitted write target.

2. Read the rules for this reason in
   `.claude/skills/workbench/references/reviews.md`, and for `docs` or `adopt`
   also `docs.md` or `adopt.md` beside it.

3. Sweep the scope. If `$1` is empty, sweep what the reason implies and say in
   the report what you covered — a reader cannot tell an unswept area from a
   clean one.

4. Write findings into the report. Each one carries evidence: the command and
   its real output, or the file and line. A finding without evidence is an
   opinion, and the user is triaging it blind. There is no template; the shape
   follows the reason.

   Run whatever you need to *observe* — tests, greps, builds. Running a command
   is not modifying the tree; committing, editing, or fixing is.

5. Delete the skeleton's HTML comment, then return **only the report path** as
   your final message. The invoking turn needs it and nothing else.

   That comment holds the triage instructions, so the report arrives without
   them. This is deliberate: triage happens in the invoking context, which has
   `reviews.md`, and a report carrying instructions for its own disposal reads
   as if the sweep were running the triage.

## What a pre-merge sweep covers

The list is in `reviews.md`. The two findings agents most often miss: a
discovered fact left out of the item whose work found it, and a test that
reaches past what the criterion describes.
