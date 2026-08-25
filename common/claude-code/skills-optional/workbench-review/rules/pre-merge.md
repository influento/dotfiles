# Pre-merge

The scope is the item about to merge. The sweep is rooted at the item's
worktree, not necessarily the checkout you were invoked in: the skeleton names
the item file there and, when the two differ, the root. Every path is relative
to that root — prefix Bash commands with `cd <root> &&`, give Read, Grep and
Glob absolute paths under it. `review-check` resolves every citation against
it, and the files the branch changed are the manifest: name each one you
covered. The item file is among them — the branch carries it — so read it and
name it; the checks below are made against it. Check:

- the criterion is genuinely satisfied by the evidence recorded
- the root cause is stated, for a bug
- documentation: written where it should not have been, or a discovered fact
  left out of the item that found it
- tests, if any, stay within what the criterion describes
- the item's prose and the commit subject use the words in
  `workbench/GLOSSARY.md`
- whether anything left unverified could in fact be verified now, by
  synthesising the event — `awaiting` and `unverified` are the user's call, not
  the agent's; report what could be verified, do not decide

The two most often missed: a discovered fact left out of the item whose work
found it, and a test that reaches past what the criterion describes.

The report sits untracked in the worktree and blocks `workbench merge` until
triage has `review-drop`ped it.
