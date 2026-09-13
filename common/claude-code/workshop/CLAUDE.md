# workshop/ (source tree)

The tools a project installs, as opposed to the skills it links. Three of them,
installed in this order by the `workshop-setup` skill:

| Tree         | Installed by                          | Into a project as                                                                                  |
| ------------ | ------------------------------------- | -------------------------------------------------------------------------------------------------- |
| `ts-gate/`   | `bash "$TS_GATE/install.sh" <project>` (the dotfiles source; the project copy refuses) | `ts-gate/` copied in, `eslint.config.mjs`, `biome.json` and `vitest.config.mjs` when absent, a `Stop` hook, `.claude/rules/ts-*.md`, allow rules for the gate and the test runner, `workbench.premerge` and `workbench.guards` |
| `stack/`     | `stack add <name>...` (the CLI is on PATH) | per package, each only when its conf asks: a `--squash` subtree at `repos/<name>`, a dependency, `.claude/rules/<name>.md`, `.claude/skills/` copies (from the registry, the subtree, or `npx skills add`), a line in the CLAUDE.md block; recorded in `.claude/stack.conf` |
| `workbench/` | `workbench init` (the CLI is on PATH) | `.claude/skills/` and `.claude/agents/` copies, one `SessionStart` hook, `workbench/` state         |

Two files leave this tree at deploy: `workbench/bin/workbench` and
`stack/bin/stack` → `~/.local/bin/`, because they are what opts a project in.
Everything else reaches a project through the installers and is committed
there, so worktrees and clones carry it.

## How the three fit

Separate tools, installed in the order above: ts-gate, commit, then `stack
add` (its subtrees need a clean tree), then `workbench init` (its CLAUDE.md
block goes after the stack's). Workbench knows nothing of the other two.
What ts-gate knows of workbench: `workbench.premerge`, `workbench.guards`,
the `permissions.allow` rules, `.worktrees/**` in its ignores, the `Never`
column of `workbench/GLOSSARY.md`, and `ts-lean-code.md`, the checklist
`wb-reviewer` applies (`ts-gate/CLAUDE.md`, Touchpoints). What stack knows
of ts-gate: a dependency it installs goes into `ts-gate/knip.json`'s
`ignoreDependencies`, a file it copies into `ignore`. What ts-gate knows of
stack: `eslint.gate.mjs` turns its money and Effect blocks on when
`.claude/stack.conf` lists `money` or `effect`. Effect itself is a stack
package (`stack add effect`, in every TypeScript project through
`workshop-setup`), not part of the gate.

## Working here

- `BACKLOG.md` beside this file: what is still to do on either tool. Read it
  first; add to it rather than to a project's backlog.
- Each tool's own `CLAUDE.md` holds its layout, commands and the platform facts
  it rests on. Lint and test from inside the tool's directory.
- A change to a skill, agent or command under `workbench/` marks every rendered
  copy stale; a change under `ts-gate/scripts/` reaches a project on its next
  `install.sh`. Say which in the commit.
