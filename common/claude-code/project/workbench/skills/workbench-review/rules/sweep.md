# Sweep

Look over the scope for bugs, improvements and cleanup. Name what you covered.

A finding is one thing wrong or improvable, what it costs, and a suggested
fix when one is obvious. A bug is shown: the command run and the output that
is wrong, with its `path:line`. A cleanup, a document, a word is cited:
`path:line` is the whole evidence, the file being the thing itself. A bug you
read but could not make happen goes in one line under `unshown:` at the end,
not among the findings — a bug nobody can show is nothing to fix. Group by
area, worst first. A clean area is a line saying so.

Run `workbench status` first. An item listed as merged and still awaiting a
trigger whose named time has passed is a finding: the criterion was never run.
Say which item, and what would close it.
