# Documentation

The default is to write nothing. Every document written can later
contradict the code, and one the agent trusts while it is wrong is worse
than none.

## Decide in this order

1. **Write nothing.** If reading the code answers the question cheaply,
   that is the answer.
2. **Derivable from our own code?** Then do not write it — it will rot.
3. **A discovered fact about a system we do not control?** It becomes code
   — a check, a constant, a comment at the one call site that depends on it
   — or it is not written. It appears in an item only where a root-cause or
   criterion line needs it, never as a line of its own: an item is out of
   context the next time the fact matters.
4. **Only what is left** may be a document, and only if it passes the test
   below.

Knowledge that changes no decision has no category: not writing it down is
the correct outcome.

## The multi-file test

If learning something requires reading **more than one file**, a document
may hold it. If one file tells you, read the file.

| Write it | Do not |
|---|---|
| a flow that crosses several files, in order | what one function does |
| contracts — what one part guarantees another | signatures, parameters |
| ordering constraints: this before that, or state is lost | "this file contains the parser" |
| why the design is this shape when a simpler one looks possible | anything a good name already says |

## Kinds and where they live

| Kind | Where | Invalidated by |
|---|---|---|
| Rules — how work is done here | root `CLAUDE.md` | process change |
| Intent — what the project is for | root `CLAUDE.md` | decisions |
| Wiring — how parts fit together | `CLAUDE.md` in the deepest directory it covers | relevant code change |
| Rules only some files need — a file type across directories, a tool's own checklist | `.claude/rules/<name>.md` with a `paths:` glob, loaded when a matching file is read | process change |

That is the whole set; the minimum a project needs is rules, the others
are earned. `workbench/GLOSSARY.md` sits outside it: domain language,
written by default ([glossary.md](glossary.md)).

A nested `CLAUDE.md` loads automatically when a file in its directory is
opened with the Read tool — not on `cat`, `head` or `grep`, and the same
for a path rule. To understand an area rather than edit it, open its
`CLAUDE.md` deliberately. Keep prescriptive and descriptive parts in
separate sections.

## Line caps

`workbench status` prints one `cap:` line per file over its cap, naming
the file and its length, at every session start until the file is under
again:

| File | Cap | Override |
|---|---|---|
| root `CLAUDE.md` | 150 | `git config workbench.cap.claude <n>` |
| `workbench/GLOSSARY.md` | 300 | `git config workbench.cap.glossary <n>` |
| `workbench/BACKLOG.md` | 400 | `git config workbench.cap.backlog <n>` |
| `workbench/DECISIONS.md` | 200 | `git config workbench.cap.decisions <n>` |

Cutting is the way to silence it; the override is the user's, for a
document that is legitimately larger.

## No findings directory, no baselines file

A measured number goes in the item it was evidence for, with the command
that produced it. A discovered fact goes into the code that depends on it.
Neither gets a file of its own: nothing invalidates such a file, so nothing
ever reviews or deletes it.

## Repository documents or agent memory

One question: **could this fact become wrong because of a commit?**

| Answer | Home |
|---|---|
| Yes — it is tied to our code | a repository document, or the item itself |
| Yes — but it describes an external system | the code that depends on it; an item line only where a root cause or criterion needs it |
| No — it is about the user, their machine, preferences, or workflow | agent memory |
| No — it is credentials-adjacent | nowhere in the repository — memory lives in the tree here, so `CLAUDE.local.md` or the user's own `~/.claude/` |

Memory passes through no review and nothing invalidates an entry when a
commit makes it wrong, so technical facts about the project belong in the
repository.

Memory lives in the tree: `workbench init` points `autoMemoryDirectory` at
`.claude/memory/`, tracked, one store for every worktree — and for every
clone at the same path under `~`, since the setting is a path; `workbench
status` warns in a clone laid out differently, where
`.claude/settings.local.json` overrides it. Every session writes there
through the main checkout, so its edits show up as unstaged changes on the
default branch; commit them as housekeeping. `workbench merge` tolerates
them unstaged and refuses them staged.

Without that setting Claude Code keys the store to the checkout:
`~/.claude/projects/<slug>/memory/`, `<slug>` being the checkout's absolute
path with every character outside `[A-Za-z0-9]` replaced by `-`, so a
worktree gets a store of its own.

Facts that have drifted, or that should have been repository documents, are
what to read the store for when a session starts from it.

## Deleting means deleting

SKILL.md's rule of that name: no strikethrough, no "NOTE: removed, see git
history", no "previously this used", no `DEPRECATED — kept for reference`,
no changelog section. Git stores every deleted line. The single exception
is something the reader must act on, such as where a moved file went — a
pointer, not a record of a deletion.

## Scope

A changed file affects only documents on its own path: its directory, then
each parent. Root holds rules and intent, which code changes do not
invalidate, so in practice it is the one nested `CLAUDE.md` covering the
area, or nothing.

## Documentation ships with the work

Any document written goes in the same change as the code. The reviewer
checks the decision in both directions: something written that should not
have been, and a fact the code depends on written nowhere the code can
reach.
