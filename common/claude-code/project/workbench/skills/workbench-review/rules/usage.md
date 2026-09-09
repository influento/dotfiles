# Usage

What the last items cost, and what would make the next ones cheaper. Nothing
here changes code: every suggestion is a setting, and the user sets it at
triage. The reference printed after these rules says what each figure is and
which lever moves it — read it before judging a number.

Run `workbench usage` first and paste its output into the report. Every
number below comes from there or from the archived items it lists; nothing
is estimated from a transcript.

Findings, worst first, each with the item ids and the numbers that show it:

- **the tail** — the two most expensive items of the window. Read their
  archived files: `rounds:`, `holds`, the length of Evidence. Say what made
  each expensive — review rounds, gate holds, a criterion run many times, a
  long fight with a Stop hook. One expensive item with a plain cause is a
  line; the same cause across the tail is a finding
- **cache** — items under 80% hit ratio, with their misses count. A low
  ratio with few misses is idle gaps: the session waited past its cache
  lifetime. Many misses is something changing the request prefix inside the
  session — a model or effort switch, a tool set that moved
- **holds** — the hold rate over the window, and whether items at one effort
  hold more than items at another. `effort=` is on every line, so the cohorts
  are the lines; fewer than three items in a cohort is no comparison, say so
- **turns** — p95 calls for the worker, the reviewer per instance, the gate.
  A cap set within a third of its p95 is a finding; no cap is not one — the
  p95s here are what a cap is set from, at twice the figure
- **the trend** — this window's median cost against the previous window's,
  when `workbench usage <2n>` shows one

The first usage review in a project — `workbench usage` says so when the
count since the last review equals the total — also raises the two decisions
that wait on exactly this data: turn caps for the reviewer and the gate, at
twice their p95 here, and whether the reviewer's effort comes down from
`medium`. Both are settings in the agent definitions' source, so the
suggestion names that, not a project file.

End the report with a `suggestions:` block, one line each: the lever, the
value, the finding it answers. Only levers the reference names. Under ten
records, "run more items first" is the whole block, and a correct one.
