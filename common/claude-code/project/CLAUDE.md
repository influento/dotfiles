# project/ (source tree)

The tools a project installs, as opposed to the skills it links. Two of them,
installed in this order by the `project-setup` skill:

| Tree         | Installed by                          | Into a project as                                                                                  |
| ------------ | ------------------------------------- | -------------------------------------------------------------------------------------------------- |
| `ts-gate/`   | `bash ts-gate/install.sh <project>`   | `ts-gate/` copied in, a `Stop` hook, `.claude/rules/ts-*.md`, two allow rules, `workbench.premerge` |
| `workbench/` | `workbench init` (the CLI is on PATH) | `.claude/skills/` and `.claude/agents/` copies, hooks, status line, `workbench/` state              |

Only one file leaves this tree at deploy: `workbench/bin/workbench` →
`~/.local/bin/workbench`, because it is what opts a project in. Everything else
reaches a project through the two installers and is committed there, so
worktrees and clones carry it.

## How the two fit

They are separate tools; workbench knows nothing of ts-gate. Every touchpoint
is on ts-gate's side: it sets `git config workbench.premerge "npm run gate"`
so `workbench merge` runs the gate in the branch worktree; its two
`permissions.allow` rules are what an unattended worker is allowed; its eslint
config ignores `.worktrees/**`; its `ts-lean-code.md` checklist is what
`wb-reviewer` applies in fresh context, which is why no hook runs it. Install
ts-gate first and commit between the two: its `git subtree add` needs a clean
tree and `workbench init` writes tracked files.

## Working here

- `BACKLOG.md` beside this file: what is still to do on either tool. Read it
  first; add to it rather than to a project's backlog.
- Each tool's own `CLAUDE.md` holds its layout, commands and the platform facts
  it rests on. Lint and test from inside the tool's directory.
- A change to a skill, agent or command under `workbench/` marks every rendered
  copy stale; a change under `ts-gate/scripts/` reaches a project on its next
  `install.sh`. Say which in the commit.

## ts-gate

Rejected tools: jscpd (`sonarjs/no-identical-functions` covers it), cloc
comment ratio, madge (dependency-cruiser covers it), api-extractor,
size-limit, type-coverage, Stryker, diff coverage. Each returns only with a
reason from a real codebase. No `agent` Stop hook: judgment review is
wb-reviewer's job.

- Decide tools, rules, severities in chat first; wire after agreement. Less code.
- Verify rule names and hook contracts against the installed package or the docs, never memory.
- After any change: scaffold a throwaway TypeScript project in a temp
  directory (`git init`, `package.json`, strict `tsconfig.json`, one commit),
  install, then `npm run gate:verify`.
- Smoke test for install/uninstall: install, install again, uninstall, diff against the pre-install tree.
