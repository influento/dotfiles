# stack (source tree)

The libraries, toolkits and tools a project chooses, one at a time, and the
way of working with each. Only `bin/stack` is deployed (→ `~/.local/bin/stack`);
the registry under `packages/` is read from this tree when a project runs
`stack add`, and what add copies is committed in the project so worktrees and
clones carry it.

No groups, no templates: a project's stack is whatever was added to it. And
no one shape: a private toolkit is a subtree plus its own skills
(`shardx-scripts`); a public library with a published skill is that skill
through skills.sh plus a short rule (`shadcn`); a plain dependency is `DEP`
and a rule. Every key is optional, the package is whatever it needs.

## Layout

| Path                            | What it is                                                                       |
| ------------------------------- | -------------------------------------------------------------------------------- |
| `bin/stack`                     | the CLI: `list`, `show`, `add`, `update` (per part: subtree pull, skills.sh update, re-copy), `rm`, `status` |
| `packages/shardx-scripts/`      | private toolkit: reference subtree, its two skills copied out of it, a rule       |
| `packages/shadcn/`              | public library: the `shadcn` skill through skills.sh, a path-scoped rule, a setup command printed |
| `packages/<name>/package.conf`  | `KEY=value`, read line by line, never sourced; keys below                         |
| `packages/<name>/rule.md`       | optional; → `.claude/rules/<name>.md` verbatim                                    |
| `packages/<name>/skills/<s>/`   | optional; → `.claude/skills/<s>/`, own-written or vendored from upstream          |
| `tests/stack.sh`                | end-to-end, in a temp project against a temp registry and a local bare "private" repo |

`package.conf` keys, every one optional but `NOTE`:

| Key                     | Meaning                                                                                                   |
| ----------------------- | --------------------------------------------------------------------------------------------------------- |
| `KIND`                  | `toolkit` (run as scripts), `lib` (imported), `cli`, `service`; shown in `list` and the CLAUDE.md line    |
| `REFERENCE`             | a repository worth reading, as a `--squash` subtree at `repos/<name>`: `private:<repo>` → `<git config private.root>/<repo>.git`, or `git:<url>`. Only when the agent should read the source or its docs; most public libraries have none |
| `REF`                   | branch or tag for the subtree; default `main`                                                             |
| `DEP`                   | package-manager specs, space separated (`effect@rc`); installed with the runner the lockfile says         |
| `SKILLS_ADD`            | a skills.sh package (`shadcn/ui`): `npx skills add <pkg> --agent claude-code --skill <pick> -y --copy`, every prompt answered by flag; the CLI writes `.claude/skills/` and `skills-lock.json` |
| `SKILLS_PICK`           | which of that package's skills, comma separated; empty is every one (`--skill '*'`)                        |
| `SKILLS_FROM_REFERENCE` | a directory inside the subtree whose `<s>/SKILL.md` children are copied as skills after the subtree lands |
| `SETUP`                 | one command the user runs after add (`npx shadcn@latest init`); printed, never run, because it asks questions |
| `NOTE`                  | one line for the CLAUDE.md block: what it is and where to start                                           |

Skills reach a project three ways and `status` treats them differently: from
`packages/<name>/skills/` (compared with the registry), from the reference
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

The Effect pattern from ts-gate, per package, each part only when the conf
names it: a `--squash` subtree at `repos/<name>` as a read-only reference
(needs HEAD and a clean tree, like ts-gate's), the dependency (and, when `ts-gate/knip.json` exists, its name in
`ignoreDependencies`, because the package lands before the code that imports
it), the rule, the skills as committed copies, one line in the block between
`<!-- stack:start -->` and `<!-- stack:end -->` in CLAUDE.md, and a row in
`.claude/stack.conf` (`name|subtree|rule|skills`) that `status`, `update` and
`rm` read back.

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

Run from this directory (`common/claude-code/project/stack/`):

- Lint: `shellcheck -x bin/stack tests/stack.sh`
- Test: `bash tests/stack.sh`
- Real check: in a scratch git project with one commit, `stack add
  shardx-scripts`, then `stack status` and read the rewritten links in
  `.claude/skills/*/SKILL.md`

## Adding a package

1. `mkdir packages/<name>`, write `package.conf` (at least `KIND` and `NOTE`).
2. If it publishes a skill (its docs, or `npx skills add <owner/repo> --list`):
   `SKILLS_ADD`, and `SKILLS_PICK` when not every skill applies. Nothing else
   is needed for the docs then; the skill carries them.
3. If instead its repository is worth reading: `REFERENCE` and `REF`. Private
   ones as `private:<repo>`. If it ships skills under `.claude/skills`,
   `SKILLS_FROM_REFERENCE=.claude/skills` and write none here.
4. If it is imported: `DEP`. If its own installer asks questions: `SETUP`.
5. `rule.md`: what is non-negotiable, where to start. Short; path-scoped with
   `paths:` frontmatter when the thing has files of its own, always-on
   otherwise. Skills only for tasks.
6. `stack show <name>`, then a real `stack add` in a scratch project.
