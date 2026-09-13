# Workbench (source tree)

The workbench tool, whole: an item-tracking workflow CLI, opted into per
project. Only `bin/workbench` is deployed (→ `~/.local/bin/workbench`);
everything else reaches a project through `workbench init`. `../BACKLOG.md`
holds what is still to do on the tools under `workshop/`; read it before
changing anything here.

## Layout

| Path        | What it is                                                                 |
| ----------- | -------------------------------------------------------------------------- |
| `bin/`      | the CLI                                                                    |
| `skills/`   | `workbench` — the dir is named exactly as the skill it renders to          |
| `agents/`   | `wb-worker`, `wb-reviewer` — listed in `WB_AGENTS`, not globbed            |
| `commands/` | `/bug /feature /idea /wb` — thin skills too, one per typed command         |
| `tests/`    | end-to-end loop plus failure paths, in a temp repo                         |

A command holds no rules, only the sizing check, the command and the fields,
and runs no `!` block (the tests refuse one): a quote or `$` in a title breaks
a substituted command, and the sizing call belongs before an id exists — an
agent that has already allocated `f-051` argues for a feature. `/bug` shadows
the builtin bug-report form, which loses nothing in a project with its own
tracker.

## What `init` puts in a project

The `workbench` skill and the `/bug /feature /idea /wb` commands, as
committed copies under `.claude/skills/`. Copies, not links: a symlink is
one machine's path and exists only in the checkout it was made in, so a
worktree or a fresh clone would have no commands and no hook. The price is
drift, paid visibly through the stamp: each copy carries source + copy
hashes; `status` flags stale and hand-edited ones, `init --force`
overwrites the latter. The `agents/` definitions go to `.claude/agents/` the same way,
with weaker bookkeeping: an agent is a flat `.md` with nowhere to hold a
stamp, so the check is `cmp`, `status` says only that a copy "differs from
its source", and `init` overwrites it either way. Which agents exist is
`WB_AGENTS`, not whatever sits in `agents/`; retiring one — out of the list
*and* deleted from `agents/` — reaps the copy on the next `init`, guarded
by `x-workbench: true` in the copy's own frontmatter, so a project's own
agent in the same directory is never touched.

It also merges into the project's `.claude/settings.json`: the
`SessionStart` hook that runs `status`, the `Bash(workbench:*)` allow rule,
and `autoMemoryDirectory` (memory tracked in the tree). The signal and gate
hooks and the status line an older init wired are removed on the next
`init`. And a block in the root `CLAUDE.md` (`claude_md_block`): the rule
that all domain work gets an item lives there, always in context, because
a skill description fires only when a request looks like a match and the
requests that most need the rule look like small favours.

`status` prints a `cap:` line per document over its line cap (`CAP_*`,
`git config workbench.cap.<name>` overrides); `references/docs.md`, "Line
caps", says what to cut.

## Extension points

Workbench knows no language or toolchain. What a project's tools plug in:

| Slot | Set by | What it does |
| ---- | ------ | ------------ |
| `WORKBENCH_ROOT` | the environment | where `init` renders from |
| `git config workbench.premerge "<command>"` | the tool that installs the command (ts-gate: `npm run gate`) | runs in the branch worktree before every squash; non-zero refuses the merge |
| `git config workbench.guards "<ERE>"` | the same tool | criterion steps matching it are refused at `start` as guards, beside the built-in "by inspection" / "behaviour unchanged" |
| `git config workbench.cap.<name>` | the user | line caps `status` reports |

`changed_declarations` (what `effects` and `merge` hold against `## Side
effects`) is the one place the CLI reads source: exported TS/JS symbols,
Go's capitalised names, Python's top-level defs, route path literals. A
default across languages with a fixed contract (`name\tfile` from the
diff's removed lines), not a toolchain dependency; a project that needs
another language adds a `sed` branch there.

## Adding files here

`skill_sources` enumerates `skills/workbench/` and each `commands/<name>/`,
and `skill_hash` covers everything under them. A file added inside one of
those dirs ships into every project that runs `init` and marks every
already-rendered copy stale. Maintainer-facing files (this one included)
belong at the root of this tree instead.

## Commands

Run from this directory (`common/claude-code/workshop/workbench/`):

- Lint: `shellcheck -x bin/workbench tests/*.sh`
- Test: `bash tests/workbench.sh` — end-to-end loop plus failure paths for
  `workbench`, in a temp repo

## Platform facts the design rests on

Sources: [Claude Code hooks](https://code.claude.com/docs/en/hooks),
[CLI reference](https://code.claude.com/docs/en/cli-reference).

- An `--agent` definition's `tools:` restricts the session.
- An arbitrary unknown frontmatter key on an agent is accepted and inert —
  probed 2.1.252: `x-workbench: true` on a definition still loaded, and its
  `tools:` still applied. That is what `render_agents` reaps by.
- An `--agent` definition's `skills:` does **not** restrict — probed 2.1.252:
  an agent listing one skill invoked a second one anyway.
- `effort:` on an agent is honoured when the agent is spawned by the Agent
  tool and when a `context: fork` skill names it in `agent:` (probed
  2.1.263), which is why `wb-reviewer` carries one.
- A `context: fork` skill takes its agent's `tools:` and nothing else;
  `allowed-tools` only pre-approves what is listed and removes nothing
  (probed 2.1.248). `background:` on a skill needs 2.1.218. A `!` block in
  a skill runs before the first turn, with `$ARGUMENTS` substituted.
- Subagents get the five-minute cache TTL whatever the plan; the main
  conversation gets an hour on a subscription within plan usage. The
  reviewer idles while the worker fixes, so `wb-reviewer` carries
  `experimental: cacheTtl: 1h` (honoured from 2.1.248).
- A worktree under a trusted repo inherits that trust. An untrusted
  directory (`hasTrustDialogAccepted` unset in `~/.claude.json`) drops the
  `permissions.allow` rules of its `.claude/settings.json` (stderr says
  `Ignoring N permissions.allow entries`) but still runs its hooks, `-p`
  included (probed 2.1.270). A `-p` run with no `--permission-mode` inherits
  `permissions.defaultMode` from `~/.claude/settings.json`; pass it
  explicitly in a probe.
- A `permissions.allow` rule for file writes is `Edit(<pattern>)`, which
  governs `Write` too; a `Write(<pattern>)` rule is accepted and ignored
  (probed 2.1.263). Relative patterns resolve from the project root.
- A `#` comment inside a skill's or an agent's frontmatter never reaches the
  model — probed 2.1.266.
- `.claude/rules/*.md` with a `paths:` glob loads into a subagent spawned with
  the Agent tool once it reads a matching file — probed 2.1.258, for
  `wb-reviewer` and `general-purpose`; the unscoped rules load regardless.
- A compact keeps `CLAUDE.md` and the `SessionStart` hook output and nothing
  else that was injected: an invoked skill's body and every `.claude/rules`
  file the session had read are gone from the compacted context. From
  agent-kit's README, not probed here. `status` says so when its `source` is
  `compact`.

## Measured

Before the dialog, a gate: a fresh-context check of the item against its
evidence. User-only at first, it ran zero times while a twenty-hour
unattended session merged forty-six times; made a required step of `merge`,
it found no code defect the dialog had not, blocked a correct item twice on
the wording of its criterion, and came out after three runs. The dialog is
the required read, and the item checks the gate made are `wb-reviewer`'s.

2026-09-13, three items, three runs per cell, `claude -p --effort low
--permission-mode acceptEdits`, Claude Code 2.1.270. Arms: A one session,
criterion in the prompt, "gate:local green, commit"; B = A plus one spawned `wb-reviewer` with the criterion and the diff
range, findings answered by number; C = `new` → `start` → `claude -p --agent
wb-worker` → `merge` by hand, no gate.

| | A | B | C |
|---|---|---|---|
| cost per item, mean | $0.60 | $1.29 (2.1× A; 1.6–2.7× by item) | $2.30 (3.8× A, 1.8× B) |
| wall, mean | 127 s | 264 s | 428 s (worker session only) |
| regression the reviewer found by running, absent | 0/6 | 6/6 | 6/6 |
| round 2 raised a finding that was fixed | – | – | 6/9 (once after an empty round 1) |

What the reviewer earned: a `slow-` batch id turned `NotFound` (never retried)
and a `Schema.DateFromString` that accepts `"1"` and reads zone-less strings in
the host's zone; every bare worker shipped both, every reviewer ran the case
and showed it. B and C found the same things; C added one crash in one round-3
run, B one whitespace-id case.