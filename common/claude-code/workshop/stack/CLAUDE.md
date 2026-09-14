# stack (source tree)

The libraries, toolkits and tools a project chooses, one at a time, and the
way of working with each. This directory is the CLI only; the packages live
beside it, under each language. Only `bin/stack` is deployed (→
`~/.local/bin/stack`); the registry is read from the workshop tree when a
project runs `stack add`, and what add copies is committed in the project so
worktrees and clones carry it.

No templates: a project's stack is whatever was added to it, and a preset
(`fullstack`) is only a list of packages — what it expands to is
recorded, the preset is not. No one shape: a private toolkit is a subtree
plus its own skills (`shardx-scripts`); a public library with a published
skill is that skill through skills.sh plus a short rule (`shadcn`); a plain
dependency is `DEP` and a rule. Every key is optional, the package is
whatever it needs.

## The registry

A package is `workshop/<language>/packages/[<section>/]<name>/`. A language
directory holds its gate and its packages together (`typescript/`: the
picks, sections and how its packages depend on the gate are in
`../typescript/CLAUDE.md`); `general/packages/` holds packages with no
language and has no sections except `presets/`: `shardx-scripts`, a private
toolkit (reference subtree, its two skills copied out of it, a rule). A
project may add packages from several languages and from `general`.

- Names are unique across the registry; `bin/stack` refuses a name found
  twice, on the lookup and in `list`.
- `NEEDS` never leave the package's language: a package needs only its own
  section or `<language>/shared`; a preset (`KIND=preset`) any section of its
  language. A typescript package never needs a `general` one, nor the
  reverse. `stack show` and `stack add` refuse a `NEEDS` outside that, naming
  both groups.
- A preset sits in `<language>/packages/presets/`, and nothing else does.
  A preset elsewhere could be needed from its section or `shared` and carry
  that package into any section. `show` and `add` refuse either misplacement.
- `stack list` prints a heading per `<language>/<section>`; `stack show`
  prints the package's group on its `in:` line.
- `STACK_REGISTRY` points the CLI at another tree (the tests' temp registry).

## Layout

| Path                            | What it is                                                                       |
| ------------------------------- | -------------------------------------------------------------------------------- |
| `bin/stack`                     | the CLI: `list`, `show`, `add`, `update` (per part: subtree pull, skills.sh update, re-copy), `rm`, `status` |
| `<package>/package.conf`        | `KEY=value`, read line by line, never sourced; keys below                         |
| `<package>/rule.md`             | optional; → `.claude/rules/<name>.md` verbatim                                    |
| `<package>/eslint.mjs`          | optional; → `.claude/eslint/<name>.mjs` verbatim, the rule's lifecycle (re-copied by update, removed by rm or when the registry drops it). Default export: an array of eslint flat config blocks, or a function of `{ tsconfigRootDir, severity }` returning one; `ts-gate/eslint.gate.mjs` appends every file there after its own blocks, so a project overrides one after the `gate()` spread. Inert without ts-gate |
| `<package>/skills/<s>/`         | optional; → `.claude/skills/<s>/`, own-written or vendored from upstream          |
| `<package>/files/<path>`        | optional; → `<path>` in the project once, never overwritten and never removed: source the project owns from the moment it lands (`money`'s `src/core/money.ts`) |
| `tests/stack.sh`                | end-to-end, in a temp project against a temp registry and a local bare "private" repo; also resolves every package of the shipped registry under the section rule |

`package.conf` keys, every one optional but `NOTE`:

| Key                     | Meaning                                                                                                   |
| ----------------------- | --------------------------------------------------------------------------------------------------------- |
| `KIND`                  | `toolkit` (run as scripts), `lib` (imported), `cli`, `preset` (NEEDS only, expanded, not recorded); shown in `list` and the CLAUDE.md line |
| `NEEDS`                 | package names, space separated, added first (transitively; a cycle is refused; within the section rule above). `rm` refuses a package another added one needs |
| `REFERENCE`             | a repository worth reading, as a `--squash` subtree at `repos/<name>`: `private:<repo>` → `<git config private.root>/<repo>.git`, or `git:<url>`. Only when the agent should read the source or its docs; most public libraries have none |
| `REF`                   | branch or tag for the subtree; default `main`. A pinned dependency pins its tag too (`effect@4.0.0-rc.115`) |
| `DEP`                   | package-manager specs, space separated, exact versions (`effect@4.0.0-rc.115`); installed with the runner the lockfile says |
| `DEV_DEP`               | the same, as dev dependencies (`-D`; bun `-d`)                                                            |
| `SKILLS_ADD`            | a skills.sh package (`shadcn/ui`): `npx skills add <pkg> --agent claude-code --skill <pick> -y --copy`, every prompt answered by flag; the CLI writes `.claude/skills/` and `skills-lock.json` |
| `SKILLS_PICK`           | which of that package's skills, comma separated; empty is every one (`--skill '*'`)                        |
| `SKILLS_FROM_REFERENCE` | a directory inside the subtree whose `<s>/SKILL.md` children are copied as skills after the subtree lands |
| `SETUP`                 | one command the user runs after add (`npx shadcn@latest init`); printed, never run, because it asks questions |
| `NOTE`                  | one line for the CLAUDE.md block: what it is and where to start                                           |

Skills reach a project three ways and `status` treats them differently: from
`<package>/skills/` (compared with the registry), from the reference
subtree (compared with a fresh link rewrite), or through skills.sh (left to
its lockfile). `rm` sends skills.sh skills back through `npx skills remove` so
the lockfile stays true.

`update` is per part, each with the mechanism it has: `git subtree pull` for
a reference, `npx skills update <names> -p -y` for skills.sh skills, a plain
re-copy for the rule and registry skills (those have no update of their own;
the registry is the source). The skills CLI's update ignores copy mode and
leaves `.agents/skills/<s>/` plus a symlink at `.claude/skills/<s>` (skills
1.x); `stack update` folds that back into a committed copy and removes
`.agents/`, so worktrees keep reading real files.

The private host never appears in this public repository: `private:` resolves
through `git config private.root`, which `setup-github` sets in
`~/.gitconfig.local`.

## What `add` puts in a project

Per package, what it `NEEDS` first, each part only when the conf names it: a
`--squash` subtree at `repos/<name>` as a read-only reference (needs HEAD and
a clean tree), the dependencies (and, when `ts-gate/knip.json` exists, their
names in `ignoreDependencies`, because the package lands before the code that
imports it; `update` writes them again, so a gate installed after the
package gets them from `stack update`), the rule, the lint config, the `files/` copied once (kept when present, never removed; a copied path goes into knip's `ignore` when `ts-gate/knip.json` exists, since nothing imports it yet; not on `update`, which keeps the file), the skills as committed copies, one line in the block
between `<!-- stack:start -->` and `<!-- stack:end -->` in CLAUDE.md, and a
row in `.claude/stack.conf` (`name|subtree|rule|skills`) that `status`,
`update` and `rm` read back. The row holds the name only, never a registry
path, so moving a package between sections changes nothing in a project. A
preset writes no row and no line: `stack add
fullstack` records `effect`, `atom-react`, `tanstack-start`, `tailwind`, `shadcn`, in that order (`stack show
fullstack` prints it).

A skill copied out of the subtree had relative links that climbed to its
repository root (`../../../docs/x.md` from `.claude/skills/<s>/`); in the
project it sits at the same depth, so the same climb now steps into
`repos/<name>/` — `copy_skill` rewrites exactly that prefix and nothing else.
`status` compares a copy against a fresh rewrite, so a differing copy is one
bit, as for workbench's agents: it does not say which side moved.

Rule or skill for a package: a rule (`.claude/rules/`, loaded by path or
always) for how the project works with the thing; a skill only for a task
("set up an account", "add a migration"), because skill descriptions compete
as triggers and a rule does not. Most public libraries need only the subtree
and a short rule saying what to read first; conventions grow into the rule as
they are learned.

## Commands

Run from this directory (`common/claude-code/workshop/stack/`):

- Lint: `shellcheck -x bin/stack tests/stack.sh`
- Test: `bash tests/stack.sh`. The registry's `eslint.mjs` files under the
  real gate are the language's test: `../typescript/tests/registry.sh`
- Real check: in a scratch git project with one commit, `stack add
  shardx-scripts`, then `stack status` and read the rewritten links in
  `.claude/skills/*/SKILL.md`

## Adding a package

1. Pick its place: `<language>/packages/<section>/<name>/`, the section its
   `NEEDS` allow (the rule above), or `general/packages/<name>/` when it has
   no language. Write `package.conf` (at least `KIND` and `NOTE`). First the
   language's "What enters the registry" test
   (`../typescript/CLAUDE.md` for TypeScript: the one pick for its need, and
   Effect-native or wrapped once?). The reason goes in the comment.
   `NEEDS=effect` for anything that imports it; `DEP` at an exact version.
2. If it publishes a skill (its docs, or `npx skills add <owner/repo> --list`):
   `SKILLS_ADD`, and `SKILLS_PICK` when not every skill applies. Nothing else
   is needed for the docs then; the skill carries them.
3. If instead its repository is worth reading: `REFERENCE` and `REF`. Private
   ones as `private:<repo>`. If it ships skills under `.claude/skills`,
   `SKILLS_FROM_REFERENCE=.claude/skills` and write none here.
4. If it is imported: `DEP`. If its own installer asks questions: `SETUP`.
5. `rule.md`: what is non-negotiable, where to start. Short; path-scoped with
   `paths:` frontmatter when the thing has files of its own, always-on
   otherwise. Skills only for tasks. What a lint rule can check goes in
   `eslint.mjs` instead, its plugin in `DEV_DEP`; the rule keeps what it
   cannot. A selector rule is an inline plugin rule named after the package
   (`money/no-number`), never a core rule that takes options
   (`no-restricted-syntax`): a later block would replace the gate's. A
   function export follows the gate's severity
   (`../typescript/gate/CLAUDE.md`, Rules).
6. `stack show <name>`, then `bash tests/stack.sh` (its shipped-registry leg
   resolves the new package), then a real `stack add` in a scratch project.
