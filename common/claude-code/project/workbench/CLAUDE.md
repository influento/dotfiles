# Workbench (source tree)

The workbench tool, whole. Item-tracking workflow CLI, opted into per project.
Only `bin/workbench` is deployed out of this tree (→ `~/.local/bin/workbench`),
because it is what opts a project in; everything else reaches a project through
`workbench init`.

`../BACKLOG.md` holds what is still to do on the tools under `project/`; read it
before changing anything here.

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

Retiring one — out of `WB_AGENTS` *and* deleted from `agents/`, since
`agent_sources` dies on a name it lists but cannot find — reaps the copy from
the project on the next `init`. The reap is guarded by `x-workbench: true` in
the copy's own frontmatter, carried by the sources so it is true of the copies:
a project's own agent in the same directory has no marker and is never touched.
An unknown frontmatter key is inert — see "Platform facts" below.

It also merges into the project's `.claude/settings.json`: a session hook, the
status line, an allow rule, `autoMemoryDirectory` (memory tracked in the tree),
and the signal/gate hooks.

## Sessions

`workbench lead` opens tmux session `wb-<repo>` with the lead in window 0; each
`start` then opens the item's worker as its own Claude session in its own window
(up to `git config workbench.maxWorkers`, 5; `--resources "<list>"` names what it
may hold; at `--effort` `workbench.workerEffort`, low, one level up once the
item has held at the gate and the worker is opened again —
`workbench.workerEffortOnHold`, medium, `off` to keep the base; that reopen is
a fresh session with ` — held: <n>` on its dispatch line, never a resume,
since a resume at a new effort re-reads its whole history uncached — while the lead keeps the
global setting — the lead plans, the workers execute; the reviewer and the gate
run at medium by their own `effort:`, whatever the worker's; with `--strict-mcp-config`,
so no user-level MCP server rides in a worker's requests, plus `--mcp-config
workbench.workerMcp` when the project sets one), titled by the hooks with what it needs (`?` needs you, `↑` asked the
lead, `⟳` in review, `✓` ready, `!` parked a call, `·` stopped, `✗` its claude
died and `open` resumes it — a window alive with a shell in it, noticed on
any session's status-line repaint, never by a timer) and with the context
fill once it reaches `CTX_WARN` (`f-041 82%`; the status line records it
under `usage/<sid>.ctx` on every repaint and `status` says "compaction
soon", because a compacted or resumed session re-reads its history
uncached); `open <id|lead>`
switches or resumes, `mode attended|unattended` decides live whether questions go
to the user in-window or are parked; `round` keeps the review dialog honest
before the gate.
Without a lead `start` is git-only.

The status line records each registered session's cost and cache figures,
and `signal working` counts tool calls per agent type; both live under
`<git-common-dir>/workbench/usage/` until `archive` folds a worker's into its
item as one `usage:` line. `status` prints a `usage:` line when a review is
due (`USAGE_REVIEW_EVERY` records, or a threshold in the last five);
`workbench usage` tabulates; the `usage` review reason judges. The levers a
review may name: `skills/workbench/references/usage.md`.

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

Run from this directory (`common/claude-code/project/workbench/`):

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
- An arbitrary unknown frontmatter key on an agent is accepted and inert —
  probed 2.1.252: `x-workbench: true` on a definition still loaded (it appears
  in `--agent <bogus>`'s "Available agents" list, which is how a missing agent
  fails), and its `tools:` still applied. That is what `render_agents` reaps by.
- An `--agent` definition's `skills:` does **not** — probed 2.1.252: an agent
  listing one skill invoked a second one anyway, and its advertised skill
  listing was identical to an agent with no `skills:` field. The field is inert
  in the `--agent` path; `tools:` in the same file was enforced in the same run,
  so the frontmatter was parsed. `wb-worker` lists `workbench-review` regardless,
  because the day the field starts restricting is the day the gate stops running.
- An `--agent` definition's `model:` **does** apply on that path — probed
  2.1.263: `model: haiku` on the agent, the session's usage billed to Haiku.
  Its `effort:` does **not** — same probe, `effort: low` and `effort: max`
  both ran at the global level. The same `effort:` is honoured when the agent
  is spawned by the Agent tool and when a `context: fork` skill names it in
  `agent:` (both read the level under a parent set higher), and so is
  `model:` on the fork path. That is why the worker's effort is a `claude`
  flag in `claude_cmd` and the reviewer's is frontmatter.
- `--effort` is not kept by `--resume` — probed 2.1.263: a session started
  at low resumed at the global level. `claude_cmd` passes it on every
  invocation, as it does `--agent`, `--strict-mcp-config` and `--mcp-config`.
- Subagents get the five-minute cache TTL whatever the plan; the main
  conversation gets an hour on a subscription within plan usage. The
  reviewer idles while the worker fixes, so `wb-reviewer` carries
  `experimental: cacheTtl: 1h` (honoured from 2.1.248; ignored while the
  subscription is drawing on usage credits). The gate runs in one sitting
  and keeps the default.
- A new Claude Code version changes the system prompt, so a session resumed
  under it re-reads its whole history uncached. The lead's tmux session is
  created with `DISABLE_AUTOUPDATER=1` in its environment: workers and lead
  stay on one version until the session is next created.
- `SendMessage` to a reply target carries `uds:` sockets, not names.
- Idle notices are documented as same-permission-class only, though one crossed
  classes in practice.
- tmux `#{window_id}` (`@N`) is stable; window names are not — which is why
  `open` targets ids.
- A worktree under a trusted repo inherits that trust. An untrusted
  directory (`hasTrustDialogAccepted` unset in `~/.claude.json`) loads none
  of its `.claude/settings.json` — no allow rules, no hooks — even under
  `-p`, silently: a probe project made under `/tmp` or `~/.claude/jobs`
  measures nothing until it is trusted (2.1.263).
- A `permissions.allow` rule for file writes is `Edit(<pattern>)`, which
  governs `Write` too; a `Write(<pattern>)` rule is accepted and ignored
  (probed 2.1.263). Relative patterns resolve from the project root, so
  `Edit(workbench/reviews/**)` and `Edit(/workbench/reviews/**)` are the
  same rule.
- A `type: agent` Stop hook's subagent runs in `dontAsk` whatever the parent
  session's mode — probed 2.1.258 with the parent in `auto` and in `default`:
  `PermissionRequest` never fired for it, so `gate permission` cannot reach
  it. Only Claude Code's built-in read-only allowlist runs there (`git diff`,
  `git status`, `grep`, `tail`); a script (`bash x.sh`), `ls -la`, and piped
  or compound forms were refused (2.1.259). Anything else needs an explicit
  `permissions.allow` rule in the project's settings, which the hook agent
  does honour.
- A `#` comment inside a skill's or an agent's frontmatter never reaches the
  model — probed 2.1.266, a canary in the comment and one in the body, four
  runs, only the body's reported. The maintainer notes in
  `workbench-review/SKILL.md`'s frontmatter and `wb-gate.md`'s cost nothing
  at runtime.
- `.claude/rules/*.md` with a `paths:` glob loads into a subagent spawned with
  the Agent tool once it reads a matching file — probed 2.1.258 with a canary
  line, for `wb-reviewer` and `general-purpose`; the unscoped rules load
  regardless. A project's per-file rules reach the reviewer and the gate.

The CLI surface these sit under: `workbench lead`, `open`, `signal`, `gate`, and
the definitions in `agents/`.
