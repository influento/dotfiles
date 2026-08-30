# Pre-merge

The scope is the item about to merge. The sweep is rooted at the item's
worktree, not necessarily the checkout you were invoked in: the skeleton names
the item file there and, when the two differ, the root. Every path is relative
to that root — prefix Bash commands with `cd <root> &&`, give Read, Grep and
Glob absolute paths under it. `review-check` resolves every citation against
it, and the files the branch changed are the manifest: name each one you
covered. The item file is among them when the branch edited it, and it must
have: evidence is written on the branch, and the skeleton says when it is
missing. Read it and name it; the checks below are made against it. Check:

- the criterion is genuinely satisfied by the evidence recorded — the output
  pasted, not a table typed; each step settled by a block, not by a sentence
- the criterion field is steps and expected results only. Flag every step
  that is a guard ("still does what it did", "behaviour unchanged"), a
  typecheck or build, "by inspection", or a paragraph of rationale; flag a
  step whose command uses a flag or a file the item itself adds
- the criterion is the one that was written first: `git log -p` on the item
  file along the branch shows whether a step was reworded after the code.
  A miss recorded as a miss is fine; a step amended to the number the code
  produced is a finding that stops the merge
- the RED value for each step was measured and written in, not guessed and
  "corrected before the evidence was run"
- the root cause is stated, for a bug, and is a mechanism
- only the template's headings are present — no "For the operator", no
  "What this did not prove", no dated appendix; `archive` will refuse them
- the status is one of the five, with a trigger or a why when it needs one — `abandoned` never reaches a merge; an item
  about to merge as plain `open` has a fenced block under Evidence
- no script was written to satisfy a step and then deleted, and no scratch
  file is cited that the tree does not hold
- documentation: written where it should not have been, or a discovered fact
  left out of the item that found it
- tests, if any, stay within what the criterion describes
- the item's prose, the code it adds and the commit subject use the words in
  `workbench/GLOSSARY.md` — an identifier in the old word after a rename
  merged is a finding
- whether anything left unverified could in fact be verified now, by
  synthesising the event — `awaiting` and `unverified` are the user's call, not
  the agent's; report what could be verified, do not decide
- the item is one item: a rule applied to N files is not N items, and a
  bug found and fixed inside a feature branch is a bug item
- the review dialog ran before you: `rounds:` under the status line holds
  two rounds or more and ends `stop` (`call` only with a call parked for the
  item in `DECISIONS.md`), and every finding that stands has its one-line
  reason under Evidence. A branch that came to the gate straight from the
  code is a finding that stops the merge

The three most often missed: a guard standing in a criterion slot, a
discovered fact left out of the item whose work found it, and a test that
reaches past what the criterion describes.

End the report with one line, the last line, and nothing after it:

```
verdict: merge
verdict: hold — <what must change before this merges>
```

`hold` when any finding says the criterion is not met, a criterion slot holds a
guard or was reworded to fit, evidence is a summary rather than output, or a
section is outside the template. Everything else is a finding under `merge` —
recorded, acted on at triage, not a reason to stop. `review-check` refuses a
report with no verdict, records a `merge` for the branch commit it read, and
counts a `hold`; the branch is reviewed again, by a fresh reviewer, after the
fix.

The report sits untracked in the worktree and blocks `workbench merge` until
triage has `review-drop`ped it.
