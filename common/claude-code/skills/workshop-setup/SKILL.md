---
name: workshop-setup
description: Install the gate the project's language has (ts-gate for TypeScript), the stack packages the user names, the wb-reviewer agent with its criterion habit, and workbench when the project wants tracked items, into the current project, greenfield or brownfield, in the order that works, and walk the setup checklist with the user. TRIGGER when the user says "set up this project", "install workbench and the gate", "project setup", "add packages to the stack", or invokes /workshop-setup.
---

# Project setup

Three separate tools and a review step, one order. None of the installers
knows the others; the order is what makes them fit. This skill owns the
order and the checklist, nothing language-specific: what a scaffold holds,
what an installer's output means, what a package needs, each tool says in
its own contract, and this skill points there. Run each step, show its
output, stop where it says.

Paths: `workbench` and `stack` are on PATH. The gates live under `workshop/`
beside the skills tree in dotfiles, reached through the `~/.claude/skills`
symlink:

```
WORKSHOP=$(readlink -f ~/.claude/skills/workshop-setup/../../workshop)
```

## Which project is this

| | Greenfield | Brownfield |
|---|---|---|
| Tree | empty or scaffold only | history, code, maybe its own tooling |
| Gate | default install | the gate's own brownfield procedure, in its contract |
| Review | `wb-reviewer.md` + the CLAUDE.md block (step 5) | the same |
| Workbench, if wanted | `workbench init` | `workbench adopt`, then the survey it prints |

## Steps

1. **Preconditions.** Inside git, at least one commit, `git status
   --porcelain` empty (commit or stash; `stack add` and `workbench adopt`
   refuse a dirty tree; a gate installer may not check).

   Greenfield with nothing yet: scaffold the least the tools going in need,
   commit `scaffold`. What that is belongs to the tools, not here: the gate's
   contract has a "Greenfield" section with the scaffold for its language
   (`$WORKSHOP/ts-gate/CLAUDE.md` for TypeScript); a stack entry that
   scaffolds itself says so in `stack show <entry>` (its `next:` line) and
   runs before the scaffold commit, the tree continuing from what it made.
   Nothing beyond what those two say: an extra dependency added here can
   conflict with what an installer pins later.

   Brownfield: the gate's "Project requirements" hold before it goes in
   (for ts-gate: strict compiler flags, an `include`, a green compile). A
   project that does not meet them gets that as its first item, gate
   installed after.

2. **Gate.** One per language; a language without one skips this step and
   sets `premerge=<the project's own check>` in `.claude/workshop.conf` by
   hand, so workbench still merges behind something.

   TypeScript: `TS_GATE=$WORKSHOP/ts-gate`, read `$TS_GATE/CLAUDE.md` (the
   gate's contract), then `bash "$TS_GATE/install.sh" .`. Act on every line
   it prints before going on (its "Install output" table says what each
   means), then run its full check green, or take the brownfield baseline
   its contract describes. Commit: `ts-gate: install`.

3. **Remote.** Private: `git private` (the `private-remote` skill; needs
   `private.root`, which `setup-github` sets). Public: `gh repo create`.
   Push main. That is the whole delivery pipeline: the gate at premerge is
   the only CI; the live test tier, where the gate has one, runs from the
   workstation with a gitignored `.env` and its output is pasted into the
   item; a release is a version bump and its tag, pushed by hand with the
   package manager's own command.

4. **stack.** Two questions, never a package list. The entry: `stack add
   effect` for a CLI, a library, a worker or a backend service; `stack add
   fullstack` for an app with a UI. The database: `drizzle-postgres`,
   `drizzle-sqlite`, `drizzle-mysql`, `drizzle-libsql`, or none, added in the
   same `stack add`. A project that talks to any service or model adds
   `fixtures` too: the gate refuses the network in tests, and this is how
   test data gets in. `stack show <name>` prints what a package or preset
   brings and what to run after it; a package later (`stack add
   drizzle-sqlite` in a CLI that grew a database) is the same command.
   `stack add <name>...` brings each in (a read-only subtree under `repos/`,
   the pinned dependency, a rule, a lint config the gate loads, skills, a
   line in CLAUDE.md), what a
   package needs first. Needs a clean tree, which step 2's commit gives it.
   A package not in the registry is added to dotfiles first
   (`$WORKSHOP/stack/CLAUDE.md`, "Adding a package" and "What enters the
   registry"), not improvised in the project. Commit: `stack: add <names>`.
   `stack add` works at any later time.

   The registry is TypeScript on Effect today. A project in another language
   has nothing to add until the registry has packages for it; the step is
   skipped, not improvised.

5. **Review.** The default for every project: the reviewer agent and the
   habit that feeds it, without the item loop.

   ```
   mkdir -p .claude/agents && sed 's/@@REVIEW_EXCHANGE_CAP@@/6/g' "$WORKSHOP/workbench/agents/wb-reviewer.md" > .claude/agents/wb-reviewer.md
   ```

   The source carries a setting as a token; this fills its default. Once
   workbench is in, it renders the file from `.claude/workshop.conf`.

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
   each line to the user. `premerge` should already read the gate's command
   (`npm run gate` for ts-gate, in `.claude/workshop.conf`). Settings the
   project wants off their defaults (models, efforts, caps, lint thresholds)
   go in that file: `$WORKSHOP/CLAUDE.md`, ".claude/workshop.conf". One line init does not print — deploy: none
   (a CLI, a library), or a project-level `scripts/deploy` that ships a tag
   over ssh to the server and runs `docker compose up --build` in
   `~/srv/<name>`, with a `Dockerfile` whose base image is pinned to the
   runtime version the project declares. Written in the project, not here:
   the files become a stack package when a second project needs them.
   Brownfield: do the survey `workbench adopt` printed, with the user;
   nothing converts without approval.

8. **Trust the directory.** Open the project in Claude Code interactively
   once and accept the trust dialog. Until then every `permissions.allow`
   rule the gate and workbench wrote is ignored (hooks still run), and a
   non-interactive session started with `--permission-mode` is denied every
   `workbench` and gate call. A worktree under a trusted checkout inherits
   the trust.

9. **Prove it.** The gate's own proof (ts-gate: `npm run gate:verify`, one
   model call; its contract says what the four checks are), `workbench
   status`, `stack status`.

## Order, and why

The gate first: `stack add` writes into the gate's config when one exists
(ts-gate's knip ignores), which must exist by then, and the review block and
`workbench init` write tracked files. `stack add` between them: its subtrees
need HEAD and a clean tree, and its CLAUDE.md block should exist before the
review block and workbench's own are appended. Commit between each so every
tool lands under its own subject.

## Removing

The gate's own uninstaller (`bash "$WORKSHOP/ts-gate/uninstall.sh" .`)
removes exactly what its manifest lists, including the premerge key if it is
still the gate's command. `stack rm <name>` removes one package's subtree,
rule and skills and leaves its dependency; it refuses while another added
package needs it. Workbench has no uninstall; its files are the committed
`.claude/` copies and `workbench/`. The review step is
`.claude/agents/wb-reviewer.md` and the CLAUDE.md block.
