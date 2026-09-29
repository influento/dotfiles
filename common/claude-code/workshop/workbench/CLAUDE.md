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
| `agents/`   | `wb-reviewer` — listed in `WB_AGENTS`, not globbed                        |
| `commands/` | `/bug /feature /spike /idea /wb` — thin skills too, one per typed command  |
| `tests/`    | end-to-end loop plus failure paths, in a temp repo                         |

A command holds no rules, only the sizing check, the command and the fields,
and runs no `!` block (the tests refuse one): a quote or `$` in a title breaks
a substituted command, and the sizing call belongs before an id exists — an
agent that has already allocated `f-051` argues for a feature. `/bug` shadows
the builtin bug-report form, which loses nothing in a project with its own
tracker.

## What `init` puts in a project

The `workbench` skill and the `/bug /feature /spike /idea /wb` commands, as
committed copies under `.claude/skills/`. Copies, not links: a symlink is
one machine's path and exists only in the checkout it was made in, so a
worktree or a fresh clone would have no commands and no hook. The price is
drift, paid visibly through the stamp: each copy carries source + copy
hashes; `status` flags stale and hand-edited ones, `init --force`
overwrites the latter. The `agents/` definitions go to `.claude/agents/` the same way,
with weaker bookkeeping: an agent is a flat `.md` with nowhere to hold a
stamp, so the check is `cmp` against the render, `status` says only that a
copy "differs from its source", and `init` overwrites it either way. Which agents exist is
`WB_AGENTS`, not whatever sits in `agents/`; retiring one — out of the list
*and* deleted from `agents/` — reaps the copy on the next `init`, guarded
by `x-workbench: true` in the copy's own frontmatter, so a project's own
agent in the same directory is never touched.

Copies are renders, not plain copies: sources carry `@@TOKENS@@` for the
count keys of `.claude/workshop.conf` (`review.exchange_cap` is
`@@REVIEW_EXCHANGE_CAP@@`), and an agent gets `model:` and `effort:` last in
its frontmatter from `reviewer.*`, left out at `inherit`, every
other line passing through. The keys and what each changes:
`../CLAUDE.md`, ".claude/workshop.conf". Rendered, not looked up at run
time: a skill `!` block goes through permission checks and aborts the skill
when one fails, an untrusted directory drops `permissions.allow`, and
`disableSkillShellExecution` blanks it. `workbench config render` re-renders
the shipped copies and nothing else; `init` renders too. `status` tells a
copy only the settings left behind (`config: copies out of date`) from a
stale one and a hand edit: a skill by rendering its source again and
comparing hashes, an agent by reading back the values its copy was rendered
with (`agent_rendered_with`) and rendering with those.

It also merges into the project's `.claude/settings.json`: the
`SessionStart` hook that runs `status`, a second `SessionStart` entry
running `config watch` (JSON naming the file in `watchPaths`, kept apart from
status's plain text), a `FileChanged` hook on `workshop.conf` running
`config render`, the `Bash(workbench:*)` allow rule,
and `autoMemoryDirectory` (memory tracked in the tree). The signal and gate
hooks and the status line an older init wired are removed on the next
`init`. And `.claude/rules/workbench.md` (`rules_content`), overwritten
whenever it differs, and named by `status` then: the rule that all domain
work gets an item lives there, always in context, because a skill
description fires only when a request looks like a match and the requests
that most need the rule look like small favours. Its "Documentation"
section is there for the same reason: whether to write a document comes up
in any session, housekeeping included, and none of them loads the skill
for it. A rule without `paths:` rather than the root `CLAUDE.md`: it
reaches the same sessions, is read from disk again after a compact (probed
below), counts against no line cap, and leaves the project's own file
alone; `init` removes the block an older one wrote there.

`status` prints a `cap:` line per document over its line cap (`cap.<name>`
in `.claude/workshop.conf`), telling the agent to cut and leaving a larger
cap to the user. `init` moves `git config workbench.cap.*`, `workbench.main` and
`workbench.premerge`, which older versions read, into the file and unsets
them, then writes every key out (`conf_fill`, `conf_layout`; which lines
survive a rewrite: `workshop/CLAUDE.md`).

The settings, like the copies, are committed per branch: a worktree started
before a settings commit keeps its branch's values until it is rebased.
`round` reads the item's checkout, `merge`'s `premerge` and `status` the main
checkout, everything else the checkout it runs in.

## Where each rule lives

The skill ships no `references/`: nothing guarantees a reference is read.
Each rule sits where the role that needs it is sure to see it:

| Content | Home | Seen by |
|---|---|---|
| the concept: the loop, the hard rules, sizing, whose decisions are whose | `skills/workbench/SKILL.md` | any session, through a command (`/wb <id>` for the item's own); re-attached after a compact from 2.1.270 |
| documentation, and the rule that domain work is an item | `.claude/rules/workbench.md` (`rules_content`) | every session and spawn, again after a compact |
| how a field is written — the criterion, root cause, evidence — and everything particular to a spike | the template comment on that field (`write_bug`, `write_feature`, `write_spike`, `criterion_comment`, `evidence_comment`) | whoever fills the field, until it is filled |
| what a glossary entry is, coining, aliases, homographs | the `GLOSSARY.md` header (`write_glossary`) | whoever edits the glossary |
| working an item: measuring, tests, events, the review dialog | SKILL.md, "Working an item" and "The review dialog" | whichever session the user opens for the item |
| the review method and its checklist | `agents/wb-reviewer.md` | the reviewer, which loads no skill |
| what a situation needs — duplicate IDs, caps, awaiting items | the CLI's output where it detects it | whoever runs the command |

A template comment is deleted once its field is filled, so it can carry
only what writing that field needs; what a later phase needs goes in
SKILL.md, "Working an item". The reviewer's checklist repeats rules by
design, for the same reason. One session per item, opened by the user in
its worktree: `start` tells the session that ran it to stop there.

## Extension points

Workbench knows no language or toolchain. What a project's tools plug in:

| Slot | Set by | What it does |
| ---- | ------ | ------------ |
| `WORKBENCH_ROOT` | the environment | where `init` renders from |
| `premerge=<command>` in `.claude/workshop.conf` | the tool that installs the command (ts-gate: `npm run gate`, when the key is absent) | runs in the branch worktree before every squash; non-zero refuses the merge |
| `git config workbench.guards "<ERE>"` | the same tool | criterion steps matching it are refused at `start` as guards, beside the built-in "by inspection" / "behaviour unchanged" |
| the other keys of `.claude/workshop.conf` | the user | models, efforts, review caps, line caps, the default branch: `../CLAUDE.md` |

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
- Needs git 2.38 or later (`merge-tree --write-tree`) and GNU coreutils,
  findutils and sed (`date -r`, `find -printf`, `chmod --reference`, `sed
  -i`): Linux, or macOS with the GNU tools first on `PATH`

## Platform facts the design rests on

Sources: [Claude Code hooks](https://code.claude.com/docs/en/hooks),
[CLI reference](https://code.claude.com/docs/en/cli-reference). Each line
names the launch mode it was probed in; a fact probed in one mode says
nothing about another (`skills:` below was the lesson). Modes workbench
uses: a plain session the user opens, for `/bug /feature /spike /idea /wb`
and for working an item in its `.worktrees/<branch>` worktree; `wb-reviewer`
as an Agent-tool spawn from that session. A `wb-worker` agent run with
`claude --agent` was retired: it cost 1.8× a session plus reviewer for the
same regressions found ("Measured"); the facts probed through it stay.

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
  one turn). An Agent-tool spawn ignores `initialPrompt` (docs). The
  retired `wb-worker` carried both.
- `effort:` on an agent is honoured when the agent is spawned by the Agent
  tool and when a `context: fork` skill names it in `agent:` (probed
  2.1.263). The agent carries none in source: `reviewer.effort` renders
  it, and the default `inherit` leaves it to the session. In 2.1.270 a spawn's effort is not in the subagent transcript,
  `--debug`, `ANTHROPIC_LOG=debug` or `stream-json --verbose`; the
  observable is `$CLAUDE_EFFORT` in the spawn's own Bash (below).
- Claude Code reads agent definitions at session start, before
  `SessionStart` hooks run: a definition rewritten by a `SessionStart` or
  `PreToolUse` hook, or by hand mid-session, applies from the next session
  (probed 2.1.270). Hence render on change, never at session start. The
  loop end to end, `-p`, sonnet: `reviewer.effort` changed from `high` to
  `low`, then a new session at `--effort medium` spawned `wb-reviewer` and
  a `general-purpose` control; `printenv CLAUDE_EFFORT` in each spawn's Bash
  read `low` and `medium`, both when a session's Bash tool made the edit and
  when a plain shell `sed` made it while a session was open (probed
  2.1.270). Asked to run a probe command without reviewing, `wb-reviewer`
  may refuse; ask again in the next session.
- A `FileChanged` matcher (`workshop.conf`) alone watches the project root
  only: an edit of `.claude/workshop.conf` through the Bash tool fired
  nothing within 60 s. With a `SessionStart` hook printing
  `hookSpecificOutput.watchPaths` naming the absolute path, the same edit
  ran `workbench config render` inside the session, and so did an edit from
  a plain shell while a `-p` session was open. The two `SessionStart`
  entries together work: `status`'s plain text reached context (the model
  named an item id only `status` printed) and the watch took (probed
  2.1.270, `-p`, sonnet and haiku). An edit made with no session open is
  watched by nothing; `status` names the copies it left out of date.
- In `-p --permission-mode default`, a Bash `sed -i` on
  `.claude/workshop.conf` is refused as an edit to a sensitive file
  (`permission_denied`, `safetyCheck`) even with `--allowedTools
  "Bash(sed:*)"`; `bypassPermissions` let it through (probed 2.1.270). A
  session asked to change a setting needs the user's approval for that edit.
- `model:` on an agent is honoured under `claude --agent wb-worker -p`:
  `stream-json --verbose` (`init` event and `modelUsage`) showed
  `claude-haiku-4-5-20251001` with a rendered `model: haiku`, and the
  session default (`claude-opus-5[1m]` here) with the line left out (probed
  2.1.270).
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
  checkout's, two directories up, is not (probed 2.1.270, sonnet). So
  `.claude/rules/workbench.md` reaches an item's session only once it is
  committed on main before `start`.
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
  UI) and the files that were read. `status` still says the skill body is
  gone when its `source` is `compact`; over-cautious now, not wrong.
- A `.claude/rules/*.md` without `paths:` is read from disk again after a
  compact, re-attached as an `instructions` attachment on the first turn
  after `compact_boundary`, as `CLAUDE.md` is; one with `paths:` is not —
  its `nested_memory` attachment does not return, and only what the summary
  kept remains (probed 2.1.284, `-p`, sonnet, `/compact`, 3 runs per arm).
  The summary quotes a codeword verbatim, so a plain before/after probe
  proves nothing: the codeword was swapped on disk before the compact, and
  the no-`paths:` rule answered with the new word 3/3, the `paths:` rule
  with the old 3/3.

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