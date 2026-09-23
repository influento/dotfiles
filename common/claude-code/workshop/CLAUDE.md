# workshop/ (source tree)

The tools a project installs, as opposed to the skills it links. Three of them,
installed in this order by the `workshop-setup` skill:

| Tree         | Installed by                          | Into a project as                                                                                  |
| ------------ | ------------------------------------- | -------------------------------------------------------------------------------------------------- |
| `typescript/gate/` | `bash "$TS_GATE/install.sh" <project>` (the dotfiles source; the project copy refuses) | `ts-gate/` copied in, `eslint.config.mjs`, `biome.json` and `vitest.config.mjs` when absent, a `Stop` hook, `.claude/rules/ts-*.md`, allow rules for the gate and the test runner, `premerge` in `.claude/workshop.conf` when the file has none, `git config workbench.guards` |
| `stack/`     | `stack add <name>...` (the CLI is on PATH; packages from `<language>/packages/`) | per package, each only when its conf asks: a `--squash` subtree at `repos/<name>`, a dependency, `.claude/rules/<name>.md`, `.claude/eslint/<name>.mjs`, `.claude/skills/` copies (from the registry, the subtree, or `npx skills add`), a line in the CLAUDE.md block; recorded in `.claude/stack.conf` |
| `workbench/` | `workbench init` (the CLI is on PATH) | `.claude/skills/` and `.claude/agents/` copies rendered from `.claude/workshop.conf`, two `SessionStart` hooks and a `FileChanged` hook, `workbench/` state |

The registry sits beside them, by language: `typescript/` holds the
TypeScript gate together with the packages written against it
(`typescript/CLAUDE.md`), `general/packages/` the packages with no language.
A second language gets the same shape, `<language>/gate/` and
`<language>/packages/`.

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
the `permissions.allow` rules, `.worktrees/**` in its ignores, `workbench/**`
left out of every tool and the `no-workbench` import rule (a spike's
folder), the `Never` column of `workbench/GLOSSARY.md`, and
`ts-lean-code.md`, the checklist
`wb-reviewer` applies (`typescript/gate/CLAUDE.md`, Touchpoints). How stack
and ts-gate depend on each other, and why the gate goes in first:
`typescript/CLAUDE.md`.

## .claude/workshop.conf

The settings a project changes now and then, one committed file for both
tools. Defaults live in the tools: a missing key is its default, and with no
file everything is. `workbench init` writes every key out, under a comment
saying what it does, so a setting is changed where it stands: the file's
values kept, a missing key at its default, ts-gate's keys where `ts-gate/`
exists, `premerge` and `main` commented out while unset. It rewrites the file
only when a key is missing, and moves lines that are none of its keys
(unknown keys, the project's own comments) to the end. A default a tool
changes later does not reach a file that already names the key. ts-gate's
install writes `premerge` when the file has none, over the commented-out
line. This table is the reference; the tools' docs link here.

- Format: `key=value` lines, the value to the end of the line, no quoting;
  `#` comment lines and blank lines skipped. Keys and values are trimmed,
  the last occurrence of a key wins. Parsed the same way in
  `workbench/bin/workbench`, `typescript/gate/scripts/stop-hook.sh` and
  `typescript/gate/eslint.gate.mjs`.
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
  copy stale; a change under `typescript/gate/scripts/` reaches a project on its next
  `install.sh`. Say which in the commit.
