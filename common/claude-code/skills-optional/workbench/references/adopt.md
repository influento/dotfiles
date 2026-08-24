# Adopting an existing project

`workbench adopt` has already scaffolded `workbench/` and linked the skill.
What remains is a survey, and it is a conversation — not a conversion script.

## The one fixed rule

**Shipped work never gets a backfilled item.** The criterion must precede the
code ([items.md](items.md), "Mutability"), so manufacturing archived items from
git history would produce exactly the artefact this system exists to prevent.
History stays in git.

Everything else is proposed and approved, never assumed.

## Survey

Look at how this project actually tracks work today. Do not guess in advance
what that will be — find it, then report it. Places worth opening:

- files that read like a list of intentions, whatever they are called
- `TODO` and `FIXME` markers in the code
- an issue tracker, if the repository is connected to one
- existing documentation, against the rules in [docs.md](docs.md)
- anything the project's own `CLAUDE.md` or README says about its process

Report what exists with counts and a few real examples, so the user is deciding
about something concrete rather than a category.

## Ask

Then ask, for each thing found, which of these it is:

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

## Documentation

Existing documentation is audited, not migrated. Run it as a `docs` review
(see [reviews.md](reviews.md)): a report the user triages, so that deleting
someone's document is always their decision. Most of what a project accumulates
is derivable from its code and should go; what cost real work to discover moves
into the item that will use it, or a backlog line. It never becomes a document
of its own — see [docs.md](docs.md).

## Glossary

A fresh project starts with an empty glossary and fills it as the domain becomes
clear. An existing project already has its vocabulary, scattered through code,
documents and whatever tracking it used, so filling `workbench/GLOSSARY.md` is
part of adoption.

Propose the terms; do not write them unilaterally. Look for words this project
uses in a narrower sense than they are used generally, and especially for two
words already in use for one thing — that is the condition the glossary exists
to end, and adoption is the cheapest moment to end it.

Choosing between two existing words is a decision, not a survey finding. Put it
to the user, and once it is settled the losing word becomes a `rename` item like
any other. Rules in [glossary.md](glossary.md).

## Finish

Leave the counter at zero. Old issue numbers are not item IDs, and aligning
them buys nothing while guaranteeing a collision later.

Delete the adoption report once triage is done ([reviews.md](reviews.md)).
