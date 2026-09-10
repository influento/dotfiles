---
name: project-setup
description: Install ts-gate, the stack packages the user names, and workbench into the current project, greenfield or brownfield, in the order that works, and walk the setup checklist with the user. TRIGGER when the user says "set up this project", "install workbench and the gate", "project setup", "add packages to the stack", or invokes /project-setup. For a project without TypeScript, skip ts-gate.
---

# Project setup

Three separate tools, one order. None of the installers knows the others; the
order is what makes them fit. Run each step, show its output, stop where it
says.

Paths: `workbench` and `stack` are on PATH. ts-gate lives under `project/` beside the skills tree in dotfiles,
reached through the `~/.claude/skills` symlink:

```
TS_GATE=$(readlink -f ~/.claude/skills/project-setup/../../project/ts-gate)
```

Read `$TS_GATE/CLAUDE.md` first: it is the gate's own contract and its
brownfield procedure.

## Which project is this

| | Greenfield | Brownfield |
|---|---|---|
| Tree | empty or scaffold only | history, code, maybe its own tooling |
| Workbench | `workbench init` | `workbench adopt`, then `/workbench-review adopt` |
| ts-gate severity | default (`error`) | `severity: "warn"` and ratchet, per `$TS_GATE/CLAUDE.md` "Brownfield" |
| ESLint config | install writes it | install prints a block; you merge it before the gate can be green |

## Steps

1. **Preconditions.** Inside git, at least one commit, `git status
   --porcelain` empty (commit or stash; the installer refuses otherwise).
   Greenfield with nothing yet: scaffold and commit first —

   ```
   git init -b main && npm init -y
   # tsconfig.json: "strict": true and "include": ["src"]
   # src/index.ts with one export (knip's entry)
   # .gitignore: node_modules
   git add -A && git commit -m "scaffold"
   ```

   Brownfield: `tsconfig.json` needs `strict: true` and an `include`; `tsc
   --noEmit` must pass before the gate goes in — the gate runs it repo-wide
   and blocks every stop on a red compile. A project that does not compile
   gets that as its first item, gate installed after.

2. **ts-gate** (TypeScript projects only). `bash "$TS_GATE/install.sh" .`
   Read every line it prints:
   - `eslint config exists, not touched` → merge the printed block into the
     existing config now. Until then knip fails on the unused gate file.
   - `NOTE: workbench.premerge is '<x>'` → chain, do not replace:
     `git config workbench.premerge "<x> && npm run gate"`.
   - `WARNING` lines about tsconfig or knip entry → fix before going on.

   Then `npm run gate:full`. Greenfield: green. Brownfield: the first run is
   the baseline — knip's legitimate findings go into `ignore` /
   `ignoreDependencies` in `ts-gate/knip.json`, cycles are fixed, eslint runs
   at `warn` with the count recorded, all as `$TS_GATE/CLAUDE.md` says. Do not
   commit until `gate:full` exits 0 or every remaining red is a recorded
   warning. Commit: `ts-gate: install`.

3. **stack.** Ask which packages this project uses; `stack list` shows the
   registry. Nothing is assumed, there are no presets — the user names them,
   `stack add <name>...` brings each in (a read-only subtree under `repos/`,
   the dependency, a rule, skills, a line in CLAUDE.md). Needs a clean tree,
   which step 2's commit gives it. A package not in the registry is added to
   dotfiles first (`common/claude-code/project/stack/CLAUDE.md`, "Adding a
   package"), not improvised in the project. Commit: `stack: add <names>`.
   Skip when the user names none; `stack add` works at any later time.

4. **workbench.** Greenfield `workbench init`; brownfield `workbench adopt`
   (refuses a dirty tree, then prints the survey command). Commit:
   `workbench: init` or `workbench: adopt`.

5. **Checklist.** Init printed "setup — decide these with the user". Take
   each line to the user. `premerge` should already read `'npm run gate'`.
   Brownfield: run `/workbench-review adopt` and triage its report with the
   user; nothing converts without approval.

6. **Prove it.** `npm run gate:verify` (one model call: the seeded violation
   must block a session and the fix must release it). `workbench status`,
   `stack status`.

## Order, and why

ts-gate first: its `git subtree add` needs HEAD and refuses a dirty tree, and
`workbench init` writes tracked files. `stack add` between them: its subtrees
need the same clean tree, and its CLAUDE.md block should exist before
workbench appends its own. Commit between each so every tool lands under its
own subject.

## Removing

`bash "$TS_GATE/uninstall.sh" .` removes exactly what its manifest lists,
including the premerge key if it is still `npm run gate`, and leaves `effect`
and `repos/effect`. `stack rm <name>` removes one package's subtree, rule and
skills and leaves its dependency. Workbench has no uninstall; its files are
the committed `.claude/` copies and `workbench/`.
