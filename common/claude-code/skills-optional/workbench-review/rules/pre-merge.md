# Pre-merge

The scope is the item about to merge. Its file lives on its branch, so the
skeleton names the path — in the item's worktree, not necessarily the checkout
you run in; read it there. Check:

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
