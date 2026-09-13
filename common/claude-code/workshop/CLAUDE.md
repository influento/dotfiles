# workshop/ (source tree)

The tools a project installs, as opposed to the skills it links. Three of them,
installed in this order by the `workshop-setup` skill:

| Tree         | Installed by                          | Into a project as                                                                                  |
| ------------ | ------------------------------------- | -------------------------------------------------------------------------------------------------- |
| `ts-gate/`   | `bash "$TS_GATE/install.sh" <project>` (the dotfiles source; the project copy refuses) | `ts-gate/` copied in, `eslint.config.mjs`, `biome.json` and `vitest.config.mjs` when absent, a `Stop` hook, `.claude/rules/ts-*.md`, allow rules for the gate and the test runner, `premerge` in `.claude/workshop.conf` when the file has none, `git config workbench.guards` |
| `stack/`     | `stack add <name>...` (the CLI is on PATH) | per package, each only when its conf asks: a `--squash` subtree at `repos/<name>`, a dependency, `.claude/rules/<name>.md`, `.claude/skills/` copies (from the registry, the subtree, or `npx skills add`), a line in the CLAUDE.md block; recorded in `.claude/stack.conf` |
| `workbench/` | `workbench init` (the CLI is on PATH) | `.claude/skills/` and `.claude/agents/` copies rendered from `.claude/workshop.conf`, two `SessionStart` hooks and a `FileChanged` hook, `workbench/` state |

Two files leave this tree at deploy: `workbench/bin/workbench` and
`stack/bin/stack` → `~/.local/bin/`, because they are what opts a project in.
Everything else reaches a project through the installers and is committed
there, so worktrees and clones carry it.

## How the three fit

Separate tools, installed in the order above: ts-gate, commit, then `stack
add` (its subtrees need a clean tree), then `workbench init` (its CLAUDE.md
block goes after the stack's). Workbench knows nothing of the other two,
beyond listing ts-gate's keys in `.claude/workshop.conf` where ts-gate is
installed. What ts-gate knows of workbench: the `premerge` key, `workbench.guards`,
the `permissions.allow` rules, `.worktrees/**` in its ignores, the `Never`
column of `workbench/GLOSSARY.md`, and `ts-lean-code.md`, the checklist
`wb-reviewer` applies (`ts-gate/CLAUDE.md`, Touchpoints). What stack knows
of ts-gate: a dependency it installs goes into `ts-gate/knip.json`'s
`ignoreDependencies`, a file it copies into `ignore`. What ts-gate knows of
stack: `eslint.gate.mjs` turns its money and Effect blocks on when
`.claude/stack.conf` lists `money` or `effect`. Effect itself is a stack
package (`stack add effect`, in every TypeScript project through
`workshop-setup`), not part of the gate.

## .claude/workshop.conf

The settings a project changes now and then, one committed file for both
tools. Defaults live in the tools: a missing key is its default, and with no
file everything is. Neither `workbench init` nor ts-gate's install creates
it, except install writing `premerge` (and init moving an old git config key
in). This table is the reference; the tools' docs link here.

- Format: `key=value` lines, the value to the end of the line, no quoting;
  `#` comment lines and blank lines skipped. Keys and values are trimmed,
  the last occurrence of a key wins. Parsed the same way in
  `workbench/bin/workbench`, `ts-gate/scripts/stop-hook.sh` and
  `ts-gate/eslint.gate.mjs`.
- An unknown key, a line without `=` or an invalid value is never fatal:
  the default applies, and `workbench status` warns (ts-gate's keys only
  where a `ts-gate/` directory exists). `workbench config list` shows each
  key's effective value and whether it comes from the file.
- Applies from the next session. Workbench renders what Claude Code reads
  (agent frontmatter and bodies, the skill) into the committed copies; a
  `FileChanged` hook renders on an edit made while a session is open, and
  `status` names copies an edit left out of date (`workbench config render`).
  ts-gate's keys need no render: the Stop hook and eslint read the file each
  run.
- Per branch: a worktree cut before a settings commit keeps its branch's
  values until it is rebased.

| key | default | valid | consumer |
|---|---|---|---|
| `worker.model` | `inherit` | `inherit` or a token without spaces | `wb-worker.md` frontmatter `model:`; `inherit` omits the line, and the session's `--model`, `ANTHROPIC_MODEL`, `model` setting or default decides |
| `worker.effort` | `inherit` | `inherit` `low` `medium` `high` `xhigh` `max` | `wb-worker.md` frontmatter `effort:`; `inherit` omits it (`--effort`, `effortLevel`) |
| `reviewer.model` | `inherit` | as `worker.model` | `wb-reviewer.md` `model:`; `inherit`: the Agent tool's `model` argument, `CLAUDE_CODE_SUBAGENT_MODEL`, then the spawning session's model |
| `reviewer.effort` | `inherit` | as `worker.effort` | `wb-reviewer.md` `effort:`; `inherit`: the spawning session's effort |
| `review.exchange_cap` | `6` | positive integer | the exchange count in both agent bodies; text only, nothing enforces it |
| `review.round_cap` | `5` | positive integer | `workbench round` parks the dialog at this round (the item's checkout); the skill states it |
| `cap.claude` `cap.glossary` `cap.backlog` `cap.decisions` | `150` `300` `400` `200` | positive integer | the `cap:` lines of `workbench status`; the table in the skill's `references/docs.md` |
| `premerge` | unset: no gate | any command | `workbench merge` runs it in the branch worktree before the squash; read from the main checkout. ts-gate's install writes `npm run gate` when the key is absent |
| `main` | auto-detect: `origin/HEAD`, then `main`, `master` | a branch name; `status` warns when no such branch exists | the default branch every workbench command lands on |
| `gate.repeat_cap` | `3` | positive integer | identical Stop-hook failures before the hook lets the session stop |
| `gate.output_lines` | `80` | positive integer | failure lines the Stop hook feeds back |
| `lint.complexity` | `15` | positive integer | `sonarjs/cognitive-complexity` |
| `lint.max_nesting` | `3` | positive integer | `sonarjs/no-nested-functions` threshold |
| `lint.max_lines` | `1000` | positive integer | `max-lines` (warn) |
| `lint.max_lines_per_function` | `100` | positive integer | `max-lines-per-function` (warn) |
| `lint.max_statements` | `30` | positive integer | `max-statements` (warn) |
| `lint.max_params` | `6` | positive integer | `max-params` (warn) |
| `lint.max_depth` | `4` | positive integer | `max-depth` (warn) |

The `lint.*` keys change thresholds only: severities and the
skip-blank-lines and skip-comments options stay as `eslint.gate.mjs` has
them. `git config workbench.guards` stays git config; ts-gate owns it.

## Working here

- `BACKLOG.md` beside this file: what is still to do on either tool. Read it
  first; add to it rather than to a project's backlog.
- Each tool's own `CLAUDE.md` holds its layout, commands and the platform facts
  it rests on. Lint and test from inside the tool's directory.
- A change to a skill, agent or command under `workbench/` marks every rendered
  copy stale; a change under `ts-gate/scripts/` reaches a project on its next
  `install.sh`. Say which in the commit.
