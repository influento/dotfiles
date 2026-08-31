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
| `agents/`   | `wb-worker`, `wb-reviewer`, `wb-gate`                                                    |
| `commands/` | `/bug /feature /research /idea /wb` — thin skills too, one per typed command              |
| `tests/`    | end-to-end loop plus failure paths, in a temp repo                                       |

## What `init` puts in a project

`workbench init` renders the `workbench` / `workbench-review` skills plus the
`/bug /feature /research /idea /wb` commands (`/wb rename` covers renames) as
committed copies under `.claude/skills/` — copies, not links, so worktrees and
other clones carry them. Each copy is stamped with source + copy hashes;
`status` flags stale and hand-edited ones, `init --force` overwrites the latter.

It also merges into the project's `.claude/settings.json`: a session hook, the
status line, an allow rule, `autoMemoryDirectory` (memory tracked in the tree),
and the signal/gate hooks.

## Sessions

`workbench lead` opens tmux session `wb-<repo>` with the lead in window 0; each
`start` then opens the item's worker as its own Claude session in its own window
(up to `git config workbench.maxWorkers`, 5; `--resources "<list>"` names what it
may hold), titled by the hooks with what it needs (`?` needs you, `↑` asked the
lead, `⟳` in review, `✓` ready, `!` parked a call); `open <id|lead>` switches or
resumes, `mode attended|unattended` decides live whether questions go to the user
in-window or are parked; `round` keeps the review dialog honest before the gate.
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
- `SendMessage` to a reply target carries `uds:` sockets, not names.
- Idle notices are documented as same-permission-class only, though one crossed
  classes in practice.
- tmux `#{window_id}` (`@N`) is stable; window names are not — which is why
  `open` targets ids.
- A worktree under a trusted repo inherits that trust.

The CLI surface these sit under: `workbench lead`, `open`, `signal`, `gate`, and
the definitions in `agents/`.
