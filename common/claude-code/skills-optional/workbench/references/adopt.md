# Adopting an existing project

`workbench adopt` has already scaffolded `workbench/` and linked the skills.
What remains is a survey and a triage, and they run in different places: the
survey is a review sweep (`/workbench-review adopt`), forked and writing only
its report; the triage is a conversation in the invoking context. Neither is a
conversion script.

## The one fixed rule

**Shipped work never gets a backfilled item.** The criterion must precede the
code ([items.md](items.md), "Mutability"), so manufacturing archived items from
git history would produce exactly the artefact this system exists to prevent.
History stays in git.

Everything else is proposed and approved, never assumed.

## Survey — in the sweep

Look at how this project actually tracks work today. Do not guess in advance
what that will be — find it, then report it. Places worth opening:

- files that read like a list of intentions, whatever they are called
- `TODO` and `FIXME` markers in the code
- an issue tracker, if the repository is connected to one
- existing documentation, against the rules in [docs.md](docs.md)
- anything the project's own `CLAUDE.md` or README says about its process

Report what exists with counts and a few real examples, so the user is deciding
about something concrete rather than a category. The sweep asks nothing and
converts nothing; every decision below is taken at triage.

Three further things belong in the report:

- **How the app runs.** Whether there is something to watch unattended: a
  service, how it starts, a health endpoint, where it logs, what a restart is.
  Reported as facts, not as a contract — the contract is written with the user
  at setup ([reviews.md](reviews.md), "Watch shifts"). Big-picture goals the
  README or a roadmap states are reported the same way, as milestone
  candidates.

- **Vocabulary.** Words this project uses in a narrower sense than they are
  used generally, and especially two words already in use for one thing — that
  is the condition the glossary exists to end, and adoption is the cheapest
  moment to end it. List the candidates with where each occurs. Choosing
  between two existing words is a decision, not a survey finding; report both.
- **Documentation.** Audited, not migrated. Most of what a project accumulates
  is derivable from its code; what cost real work to discover is worth naming
  so triage can move it into the item that will use it, or a backlog line.
  It never becomes a document of its own ([docs.md](docs.md)).

## Triage — in the invoking context

After `workbench review-check` passes, go through the report with the user and
ask, for each thing found, which of these it is:

| Disposition | Where it goes |
|---|---|
| an idea, not yet thought through | one line in `workbench/BACKLOG.md` |
| known-broken and not yet fixed | a bug item, criterion written now |
| planned and not yet built | a feature item, criterion written now |
| already done | nothing — git has it |
| noise, stale, no longer true | deleted |

The second and third rows are the only ones that produce items at adoption
time, and they are legitimate: the code does not exist yet, so the criterion
still comes first. Everything else is a backlog line or a deletion.

Do not create items in bulk. A repository with two hundred `TODO` markers
yields two hundred backlog lines, not two hundred items — promoting a line to
an item is where the thinking happens, and it happens one at a time later.

Deleting someone's document is always their decision, which is why the docs
audit arrives as findings rather than as edits.

### Glossary

A fresh project starts with an empty glossary and fills it as the domain becomes
clear. An existing project already has its vocabulary, so filling
`workbench/GLOSSARY.md` is part of adoption — from the report's candidates,
proposed and approved, never written unilaterally. Once a choice between two
words is settled, the losing word becomes a `rename` item like any other. Rules
in [glossary.md](glossary.md).

## Setup

`workbench adopt` ran `init`, which printed the setup checklist; go through
it with the user after triage as SKILL.md "Setting up" describes, with the
survey's findings on how the app runs and what goals it states feeding the
milestone and watch lines.

## Finish

Leave the counter at zero. Old issue numbers are not item IDs, and aligning
them buys nothing while guaranteeing a collision later.

Remove the adoption report once triage is done with `workbench review-drop`
([reviews.md](reviews.md)).
