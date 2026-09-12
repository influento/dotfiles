# workshop/ (source tree)

The tools a project installs, as opposed to the skills it links. Three of them,
installed in this order by the `workshop-setup` skill:

| Tree         | Installed by                          | Into a project as                                                                                  |
| ------------ | ------------------------------------- | -------------------------------------------------------------------------------------------------- |
| `ts-gate/`   | `bash ts-gate/install.sh <project>`   | `ts-gate/` copied in, `eslint.config.mjs`, `biome.json` and `vitest.config.mjs` (tests never reach the network; `*.live.test.ts` is the live tier, `npm run test:live`) when absent, a `Stop` hook, `.claude/rules/ts-*.md`, allow rules for the gate and the test runner, `workbench.premerge` |
| `stack/`     | `stack add <name>...` (the CLI is on PATH) | per package, each only when its conf asks: a `--squash` subtree at `repos/<name>`, a dependency, `.claude/rules/<name>.md`, `.claude/skills/` copies (from the registry, the subtree, or `npx skills add`), a line in the CLAUDE.md block; recorded in `.claude/stack.conf` |
| `workbench/` | `workbench init` (the CLI is on PATH) | `.claude/skills/` and `.claude/agents/` copies, hooks, status line, `workbench/` state              |

Two files leave this tree at deploy: `workbench/bin/workbench` and
`stack/bin/stack` → `~/.local/bin/`, because they are what opts a project in.
Everything else reaches a project through the installers and is committed
there, so worktrees and clones carry it.

## How the two fit

They are separate tools; workbench knows nothing of ts-gate. Every touchpoint
is on ts-gate's side: it sets `git config workbench.premerge "npm run gate"`
so `workbench merge` runs the gate in the branch worktree; its two
`permissions.allow` rules are what an unattended worker is allowed; its eslint
config ignores `.worktrees/**` and reads the `Never` column of
`workbench/GLOSSARY.md` into `id-match` when the file exists; its
`ts-lean-code.md` checklist is what
`wb-reviewer` applies in fresh context, which is why no hook runs it. Install
ts-gate first and commit between the two: `workbench init` writes tracked
files.

`stack` brings each package in the same shape — reference subtree, pinned
dependency, rule — and knows about ts-gate only where the gate would
otherwise go red: a dependency it installs goes into `ts-gate/knip.json`'s
`ignoreDependencies` when that file exists, and `repos/**` is already in the
gate's ignores. The one read in the other direction: `eslint.gate.mjs`
switches its money block on when `.claude/stack.conf` lists `money`. It goes between the two because its subtrees need a clean tree
and `workbench init` should render its CLAUDE.md block after the stack's.
Workbench knows nothing of either.

Effect is a stack package, not part of the gate: `stack add effect` (alone,
or through the `service` and `fullstack` presets) puts the subtree, the pinned
dependency and the rule in; `workshop-setup` does that in every TypeScript
project, so `ts-lean-code.md` can name Effect without the gate installing it.
The registry is Effect-first by rule (`stack/CLAUDE.md`, "What enters the
registry"), which is what keeps a second ORM or a second schema library out.

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
