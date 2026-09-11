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
- only the template's headings are present; `archive` refuses any other.
  The set is per class and lives in one place, `template_headings()` in the
  CLI: read it rather than recall it —
  `sed -n '/^template_headings()/,/^}/p' "$(command -v workbench)"`
- no script was written to satisfy a step and then deleted, and no scratch
  file is cited that the tree does not hold
- documentation: written where it should not have been, or a fact the code
  depends on written only in prose — an item line, a document — where the
  code cannot reach it
- tests, if any, stay within what the criterion describes
- the item's prose, the code it adds and the commit subject use the words in
  `workbench/GLOSSARY.md` — an identifier in the old word after a rename
  merged is a finding, and so is any word from the glossary's `Never`
  column: `grep -riw` each one over the item and the diff
- whether anything left unverified could in fact be verified now, by
  synthesising the event — `awaiting — <trigger>` (a time can be named for
  it) and `unverified — <trigger>` (none can) are the user's call, not the
  agent's, and ` (agent)` at the end marks one entered unattended for the user
  to confirm; report what could be verified, do not decide
- the item is one item: a rule applied to N files is not N items, and a
  bug found and fixed inside a feature branch is a bug item
- the review dialog ran before you: `rounds:` under the status line holds
  two rounds or more and ends `stop` (`call` only with a call parked for the
  item in `DECISIONS.md`), and every finding that stands has its one-line
  reason under Evidence. A branch that came to the gate straight from the
  code is a finding that stops the merge

A defect in the code that none of the checks above name is a finding only
when shown — the command run and the wrong output, not a reading of a line;
read but not shown goes in one `unshown:` line at the end, outside the
findings and outside the verdict.

The three most often missed: a guard standing in a criterion slot, a
discovered fact recorded in the item instead of in the code, and a test that
reaches past what the criterion describes.

End the report with one line, the last line, and nothing after it:

```
verdict: merge
verdict: hold — <what must change before this merges>
```

`hold` when any finding says the criterion is not met, a criterion slot holds a
guard or was reworded to fit, evidence is a summary rather than output, a
section is outside the template, or no review dialog ran. Everything else is a
finding under `merge` — recorded, acted on at triage, not a reason to stop.
`review-check` refuses a report with no verdict.
