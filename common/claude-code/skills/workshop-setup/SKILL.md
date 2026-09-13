---
name: workshop-setup
description: Install ts-gate, the stack packages the user names, the wb-reviewer agent with its criterion habit, and workbench when the project wants tracked items, into the current project, greenfield or brownfield, in the order that works, and walk the setup checklist with the user. TRIGGER when the user says "set up this project", "install workbench and the gate", "project setup", "add packages to the stack", or invokes /workshop-setup. For a project without TypeScript, skip ts-gate.
---

# Project setup

Three separate tools and a review step, one order. None of the installers
knows the others; the order is what makes them fit. Run each step, show its output, stop where it
says.

Paths: `workbench` and `stack` are on PATH. ts-gate lives under `workshop/` beside the skills tree in dotfiles,
reached through the `~/.claude/skills` symlink:

```
TS_GATE=$(readlink -f ~/.claude/skills/workshop-setup/../../workshop/ts-gate)
```

Read `$TS_GATE/CLAUDE.md` first: it is the gate's own contract and its
brownfield procedure.

## Which project is this

| | Greenfield | Brownfield |
|---|---|---|
| Tree | empty or scaffold only | history, code, maybe its own tooling |
| Review | `wb-reviewer.md` + the CLAUDE.md block (step 5) | the same |
| Workbench, if wanted | `workbench init` | `workbench adopt`, then the survey it prints |
| ts-gate severity | default (`error`) | `severity: "warn"` and ratchet, per `$TS_GATE/CLAUDE.md` "Brownfield" |
| ESLint config | install writes it | install prints a block; you merge it before the gate can be green |

## Steps

1. **Preconditions.** Inside git, at least one commit, `git status
   --porcelain` empty (commit or stash; `stack add` and `workbench adopt`
   refuse a dirty tree, ts-gate's installer does not check).
   Greenfield with nothing yet: scaffold and commit first —

   ```
   git init -b main && npm init -y && npm i -D vitest@5
   # vitest in package.json before ts-gate goes in: the installer detects the
   #   runner from package.json, and a peer-installed vitest (what @effect/vitest
   #   pulls in later) never lands there — without it the gate runs no tests
   # tsconfig.json: "strict": true, "noUncheckedIndexedAccess": true,
   #   "erasableSyntaxOnly": true, "noEmit": true, "module": "nodenext",
   #   "allowImportingTsExtensions": true (node runs the sources as they are, so
   #   relative imports are written with .ts: `from "./health.ts"`; nodenext
   #   otherwise demands .js, which node cannot resolve to a .ts file),
   #   "include": ["src"]
   # package.json: "engines": { "node": ">=<major>" }, the node this runs on;
   #   "scripts": { "start": "node src/index.ts" } — the run model, decided here
   # src/index.ts with one export (knip's entry)
   # .gitignore: node_modules
   git add -A && git commit -m "scaffold"
   ```

   Brownfield: `tsconfig.json` needs `strict: true`, `noUncheckedIndexedAccess: true` and an `include`; `tsc
   --noEmit` must pass before the gate goes in — the gate runs it repo-wide
   and blocks every stop on a red compile. A project that does not compile
   gets that as its first item, gate installed after.

2. **ts-gate** (TypeScript projects only). `bash "$TS_GATE/install.sh" .`
   Read every line it prints:
   - `eslint config exists, not touched` → merge the printed block into the
     existing config now. Until then knip fails on the unused gate file.
   - `biome config exists, not touched` → the gate formats with the
     project's own; it must leave `repos/**`, `ts-gate/**` and `.worktrees/**`
     alone (install prints a `WARNING` with the `files.includes` block when it
     does not; `gate:fix` would otherwise rewrite every file under them).
   - `vitest config exists, not touched` → add the printed `setupFiles`
     and `exclude` lines to it now; without them tests may reach the
     network and `npm test` runs the live tier.
   - `NOTE: workbench.premerge is '<x>'` → chain, do not replace:
     `git config workbench.premerge "<x> && npm run gate"`.
   - `WARNING` lines about tsconfig or knip entry → fix before going on.

   Then `npm run gate:full`. Greenfield: green. Brownfield: the first run is
   the baseline — knip's legitimate findings go into `ignore` /
   `ignoreDependencies` in `ts-gate/knip.json`, cycles are fixed, eslint runs
   at `warn` with the count recorded, all as `$TS_GATE/CLAUDE.md` says. Do not
   commit until `gate:full` exits 0 or every remaining red is a recorded
   warning. Commit: `ts-gate: install`.

3. **Remote.** Private: `git private` (the `private-remote` skill; needs
   `private.root`, which `setup-github` sets). Public: `gh repo create`.
   Push main. That is the whole delivery pipeline: the gate at premerge is
   the only CI, `npm run test:live` runs from the workstation with a
   gitignored `.env` and its output is pasted into the item, a release is
   `npm version <bump>` and `git push --follow-tags` by hand.

4. **stack.** Two questions, never a package list. The entry: `stack add
   effect` for a CLI, a library, a worker or a backend service; `stack add
   fullstack` (effect + tanstack-start, atom-react, shadcn) for an app with
   a UI. The database: `drizzle-postgres`, `drizzle-sqlite`, `drizzle-mysql`,
   `drizzle-libsql`, or none, added in the same `stack add`. A project that
   talks to any service or model adds `fixtures` too: the gate refuses the
   network in tests, and this is how test data gets in. `stack show
   <name>` prints what a preset expands to; a package later (`stack add
   drizzle-sqlite` in a CLI that grew a database) is the same command. `stack add <name>...` brings each
   in (a read-only subtree under `repos/`, the pinned dependency, a rule,
   skills, a line in CLAUDE.md), what a package needs first. Needs a clean tree, which step 2's commit gives it. A package not in
   the registry is added to dotfiles first (`common/claude-code/workshop/stack/CLAUDE.md`,
   "Adding a package" and "What enters the registry"), not improvised in the
   project. Commit: `stack: add <names>`. `stack add` works at any later time.

   `fullstack` on a greenfield project: the TanStack CLI scaffolds into a
   fresh directory, so before step 1's scaffold commit run

   ```
   npx @tanstack/cli create <app> --framework React --blank --package-manager npm \
     --no-toolchain --no-intent --non-interactive
   ```

   add `src/start.ts` (`export const startInstance = createStart(() => ({}))`
   from `@tanstack/react-start`; the blank scaffold lacks it and the `server`
   route option does not typecheck without that import), then continue from
   there with that tree. The wiring is `.claude/rules/tanstack-start.md` once
   the package is in.

5. **Review.** The default for every project: the reviewer agent and the
   habit that feeds it, without the item loop.

   ```
   WORKBENCH=$(readlink -f ~/.claude/skills/workshop-setup/../../workshop/workbench)
   mkdir -p .claude/agents && cp "$WORKBENCH/agents/wb-reviewer.md" .claude/agents/
   ```

   then append to CLAUDE.md, after the stack block:

   ```
   ## Review

   Before code for a feature or a bug fix, write how anyone will know it
   worked: a command and its expected output. Run it and see it fail. After
   the code: commit, then spawn the `wb-reviewer` agent (Agent tool) with
   that criterion and the diff range; answer its findings by number over
   SendMessage until each is fixed or stands, a fix being a new commit; stop
   at `open: none`.
   ```

   Commit: `review: wb-reviewer`. Measured 2026-09-13 on three seeded items,
   three runs each (`workshop/workbench/CLAUDE.md`, "Measured"): this finds
   what the full loop finds at 2.1× a bare session against the loop's 3.8×.

6. **workbench, when the user wants it.** Tracked items, a criterion frozen
   at `start`, parked calls for an absent user, an archive: `workbench init`
   (greenfield) or `workbench adopt` (brownfield; refuses a dirty tree, then
   prints the survey command). It renders the same `wb-reviewer.md` over the
   copy from step 5. Commit: `workbench: init` or `workbench: adopt`. Ask;
   never assume. Unattended, the loop parks what a bare session decides
   itself, so it earns its cost where someone reads the items.

7. **Checklist.** Init printed "setup — decide these with the user". Take
   each line to the user. `premerge` should already read `'npm run gate'`.
   One line init does not print — deploy: none (a CLI, a library), or a
   project-level `scripts/deploy` that ships a tag over ssh to the server
   and runs `docker compose up --build` in `~/srv/<name>`, with a
   `Dockerfile` whose base is `engines.node`. Written in the project, not
   here: the files become a stack package when a second project needs them.
   Brownfield: do the survey `workbench adopt` printed, with the user;
   nothing converts without approval.

8. **Trust the directory.** Open the project in Claude Code interactively
   once and accept the trust dialog. Until then every `permissions.allow`
   rule ts-gate and workbench wrote is ignored (hooks still run), and a
   non-interactive session started with `--permission-mode` is denied every
   `workbench` and `npm run gate` call. A worktree under a trusted checkout
   inherits the trust.

9. **Prove it.** `npm run gate:verify` (one model call: the seeded violation
   must block a session and the fix must release it; step 1 fails when
   `eslint.config.mjs` does not load `gate()`). `workbench status`,
   `stack status`.

## Order, and why

ts-gate first: `stack add` writes its dependencies into the gate's knip
ignores, which must exist by then, and the review block and `workbench init`
write tracked files. `stack add` between them: its subtrees need HEAD and a
clean tree, and its CLAUDE.md block should exist before the review block and
workbench's own are appended. Commit between each so every tool lands under
its own subject.

## Removing

`bash "$TS_GATE/uninstall.sh" .` removes exactly what its manifest lists,
including the premerge key if it is still `npm run gate`. `stack rm <name>`
removes one package's subtree, rule and skills and leaves its dependency; it
refuses while another added package needs it. Workbench has no uninstall; its files are
the committed `.claude/` copies and `workbench/`. The review step is
`.claude/agents/wb-reviewer.md` and the CLAUDE.md block.
