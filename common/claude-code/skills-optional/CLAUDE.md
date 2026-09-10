# Optional skills (source tree)

Never deployed; opted into per project by symlink.

## Opting a project in

Symlink the skill directories it needs:

```bash
mkdir -p <project>/.claude/skills
ln -s ~/dev/infra/dotfiles/common/claude-code/skills-optional/go/* <project>/.claude/skills/
```

The `go/` subdirectory is a grouping only — Claude Code discovers skills as
`skills/<name>/SKILL.md`, so link the individual skill dirs
(`go-fundamentals`, `go-infra`, `go-reliability`, `go-tooling`), never the `go/`
dir itself.

Ignore the symlinks themselves in the project's `.gitignore`; `.claude/skills/`
as a whole only when every skill there is personal rather than team-wide.

A skill that belongs to one library or tool rather than to a language or a
vault goes under `../project/stack/packages/<name>/skills/` instead, and reaches
a project as a committed copy with `stack add <name>` — see
`../project/stack/CLAUDE.md`. The trees here are the candidates to move there.

Workbench is the exception to all of this: it is not opted into by symlink at
all — `workbench init` renders its skills as committed copies so worktrees and
other clones carry them. See `../workbench/CLAUDE.md`.
