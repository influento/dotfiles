# Workbench (source tree)

The workbench tool, whole. Item-tracking workflow CLI, opted into per project.
Only `bin/workbench` is deployed out of this tree (→ `~/.local/bin/workbench`),
because it is what opts a project in; everything else reaches a project through
`workbench init`.

## Layout

| Path        | What it is                                                                               |
| ----------- | ---------------------------------------------------------------------------------------- |
| `bin/`      | the CLI                                                                                  |
| `skills/`   | `workbench` and `workbench-review` — each dir is named exactly as the skill it renders to |
| `agents/`   | `wb-worker`, `wb-reviewer`, `wb-gate` — listed in `WB_AGENTS`, not globbed                |
| `commands/` | `/bug /feature /research /idea /wb` — thin skills too, one per typed command              |
| `tests/`    | end-to-end loop plus failure paths, in a temp repo                                       |

## What `init` puts in a project

`workbench init` renders the `workbench` / `workbench-review` skills plus the
`/bug /feature /research /idea /wb` commands (`/wb rename` covers renames) as
committed copies under `.claude/skills/` — copies, not links, so worktrees and
other clones carry them. Each copy is stamped with source + copy hashes;
`status` flags stale and hand-edited ones, `init --force` overwrites the latter.

The `agents/` definitions go to `.claude/agents/` the same way, copied and
committed, but with weaker bookkeeping: an agent is a flat `.md` with nowhere
to hold a stamp, so the check is `cmp` and the answer is one bit. `status` says
an agent "differs from its source" without claiming whether it is behind or was
edited, and `init` overwrites it either way — a hand edit is lost silently.
Splitting those two needs a sidecar manifest of hashes; three static files have
not earned a second bookkeeping format. Which agents exist is `WB_AGENTS`, not
whatever sits in `agents/`, so a stray file cannot ship as an agent and a
renamed source fails the init instead of going missing from the project.

It also merges into the project's `.claude/settings.json`: a session hook, the
status line, an allow rule, `autoMemoryDirectory` (memory tracked in the tree),
and the signal/gate hooks.

## Sessions

`workbench lead` opens tmux session `wb-<repo>` with the lead in window 0; each
`start` then opens the item's worker as its own Claude session in its own window
(up to `git config workbench.maxWorkers`, 5; `--resources "<list>"` names what it
may hold), titled by the hooks with what it needs (`?` needs you, `↑` asked the
lead, `⟳` in review, `✓` ready, `!` parked a call, `·` stopped); `open <id|lead>`
switches or resumes, `mode attended|unattended` decides live whether questions go
to the user in-window or are parked; `round` keeps the review dialog honest
before the gate.
Without a lead `start` is git-only.

## Extension points

Two extension points:

- `WORKBENCH_ROOT` overrides where `init` renders from.
- A source file ending `.tpl` is rendered on the way in with `@@PROJECT@@` and
  `@@DEFAULT_BRANCH@@` substituted, the `.tpl` itself not copied — the hook for
  per-project skill content. Nothing shipped uses it; it is tested.

## Adding files here

`skill_sources` enumerates `skills/workbench/`, `skills/workbench-review/` and
each `commands/<name>/`, and `skill_hash` covers everything under them. A file added
inside one of those dirs ships into every project that runs `init` and marks
every already-rendered copy stale. Maintainer-facing files (this one included)
belong at the root of this tree instead.

## Commands

Run from this directory (`common/claude-code/workbench/`):

- Lint: `shellcheck -x bin/workbench skills/workbench-review/scripts/*.sh tests/*.sh`
- Test: `bash tests/workbench.sh` — end-to-end loop plus failure paths for
  `workbench`, in a temp repo

## Platform facts the session model rests on

Sources: [Claude Code hooks](https://code.claude.com/docs/en/hooks),
[CLI reference](https://code.claude.com/docs/en/cli-reference),
[tmux man](https://man.openbsd.org/tmux.1).

Hooks used: `SessionStart/End`, `PreToolUse`, `PostToolUse`, `PermissionRequest`
(decides by JSON `decision`; exit 2 is ignored), `SubagentStart/Stop` (the matcher
is `agent_type`), `Stop`. Every hook input carries `session_id`, `cwd` and
`permission_mode`.

- An `--agent` definition's `tools:` restricts the session.
- An `--agent` definition's `skills:` does **not** — probed 2.1.252: an agent
  listing one skill invoked a second one anyway, and its advertised skill
  listing was identical to an agent with no `skills:` field. The field is inert
  in the `--agent` path; `tools:` in the same file was enforced in the same run,
  so the frontmatter was parsed. `wb-worker` lists `workbench-review` regardless,
  because the day the field starts restricting is the day the gate stops running.
- `SendMessage` to a reply target carries `uds:` sockets, not names.
- Idle notices are documented as same-permission-class only, though one crossed
  classes in practice.
- tmux `#{window_id}` (`@N`) is stable; window names are not — which is why
  `open` targets ids.
- A worktree under a trusted repo inherits that trust.

The CLI surface these sit under: `workbench lead`, `open`, `signal`, `gate`, and
the definitions in `agents/`.
