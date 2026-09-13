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
[CLI reference](https://code.claude.com/docs/en/cli-reference). Each line
names the launch mode it was probed in; a fact probed in one mode says
nothing about another (`skills:` below was the lesson). Modes workbench
uses: `claude --agent wb-worker` interactive and `-p`, always in a
`.worktrees/<branch>` worktree; `wb-reviewer` as an Agent-tool spawn from
that session; a plain main session for `/bug /feature /idea /wb`.

- An `--agent` definition's `tools:` restricts the session. An Agent-tool
  spawn's `tools:` restricts the spawn: `pa-reviewer`-shaped agent, no
  `Write` tool (probed 2.1.270).
- An arbitrary unknown frontmatter key on an agent is accepted and inert:
  `x-workbench: true` on a definition still loaded and its `tools:` still
  applied, under `--agent` interactive and `-p`, as an Agent-tool spawn,
  main checkout and worktree (probed 2.1.252, 2.1.270). That is what
  `render_agents` reaps by.
- `skills:` on an agent preloads the skill body **only into an Agent-tool
  spawn**. Under `claude --agent X` — interactive or `-p`, main checkout or
  worktree — the body never arrives (probed 2.1.270, haiku and sonnet, a
  sentinel absent while the agent body, CLAUDE.md, rules and memory were
  quoted). It restricts nothing either (2.1.252). `initialPrompt: /<skill>`
  on the agent is what loads a skill under `--agent`: interactive, it is
  the session's first turn, one model reply before the user types; with
  `-p`, the prompt becomes the command's `$ARGUMENTS` (`/<skill> <prompt>`,
  one turn). An Agent-tool spawn ignores `initialPrompt` (docs). This is
  why `wb-worker` carries both.
- `effort:` on an agent is honoured when the agent is spawned by the Agent
  tool and when a `context: fork` skill names it in `agent:` (probed
  2.1.263), which is why `wb-reviewer` carries one. In 2.1.270 a spawn's
  effort is observable from nowhere outside — not the subagent transcript,
  `--debug`, `ANTHROPIC_LOG=debug` nor `stream-json --verbose` — so that
  probe is the last word.
- A `context: fork` skill takes its agent's `tools:` and nothing else;
  `allowed-tools` only pre-approves what is listed and removes nothing
  (probed 2.1.248; workbench uses neither). `background:` on a skill needs
  2.1.218. A `!` block in a skill runs before the first turn, with
  `$ARGUMENTS` substituted; a command with `disable-model-invocation: true`
  is absent from the Skill tool's list and `claude -p "/bug x"` still runs
  it with `$ARGUMENTS` substituted (probed 2.1.270, main session).
- Subagents get the five-minute cache TTL whatever the plan; the main
  conversation gets an hour on a subscription within plan usage. The
  reviewer idles while the worker fixes, so `wb-reviewer` carries
  `experimental: cacheTtl: 1h` (honoured from 2.1.248; probed 2.1.270: an
  Agent-tool spawn from a `--agent -p` session in a worktree wrote
  `ephemeral_1h_input_tokens`, the sibling agent without the key wrote
  `ephemeral_5m`).
- A worktree under a trusted repo inherits that trust: no `Ignoring`
  line, and the worktree's `.claude/settings.json` `permissions.allow` held
  under `--agent -p --permission-mode default` — the listed command ran,
  an unlisted `touch` was refused (probed 2.1.270). An untrusted directory
  (`hasTrustDialogAccepted` unset in `~/.claude.json`) drops the
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
- `.claude/rules/*.md` without `paths:` load in every mode used — main
  session, `--agent` interactive and `-p`, an Agent-tool spawn from a main
  or an `--agent` session — and in a worktree it is the worktree's own
  copies that load, not the main checkout's (probed 2.1.270). A rule with a
  `paths:` glob loads once a matching file is read: `--agent -p` in a
  worktree, and an Agent-tool spawn from that session (probed 2.1.270;
  2.1.258 for `wb-reviewer` and `general-purpose` from a main session).
- In a worktree only the worktree's `CLAUDE.md` is in context; the main
  checkout's, two directories up, is not (probed 2.1.270, sonnet). The
  workbench block reaches a worker only once it is committed.
- `autoMemoryDirectory`'s `MEMORY.md` loads in every mode used, Agent-tool
  spawns included (probed 2.1.270).
- Hooks in the worktree's `.claude/settings.json` fire there: `SessionStart`
  (input carries `agent_type` under `--agent`) and `Stop` under `--agent`
  interactive and `-p` and in a main session; a `Stop` hook exiting 2 keeps
  a `-p` session going under `--agent` (the model answered the hook's
  message); `SubagentStart`/`SubagentStop` for an Agent-tool spawn from
  either kind of parent (probed 2.1.270).
- A compact keeps `CLAUDE.md` and the `SessionStart` hook output, and
  `SessionStart` fires again with `source: compact` (probed 2.1.270,
  interactive). 2.1.270 also re-attaches invoked skills after the boundary
  (`invoked_skills` attachment in the transcript, "Skills restored" in the
  UI) and the files that were read; whether `paths:` rules return was not
  settled — a quoting probe proves nothing, the summary itself carried
  every sentinel verbatim. `status` still says the skill body is gone when
  its `source` is `compact`; over-cautious now, not wrong.

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

The regressions were a `slow-` batch id turned `NotFound` (never retried) and
a `Schema.DateFromString` that accepts `"1"`: every bare worker shipped both,
every reviewer ran the case and showed it.