# Glossary

`workbench/GLOSSARY.md` holds the project's domain language. The agent
writes the items, and items are prose: if the vocabulary drifts, the
archive stops being searchable.

## What goes in

**Domain language only**: a word this project uses in a narrower or
different sense than generally. The highest-value entries are ordinary
words the project has **narrowed** — nobody misuses `MobPositionResolver`,
everybody misuses `drift`; a term with no general meaning usually needs no
entry. **Never the same concept twice.** **Brief**: a definition, not an
explanation. **Nothing that changes when the implementation changes**: if
a refactor edits the entry while the concept stayed the same, it was a
spec — "the region the world is partitioned into for loading" is an entry,
"a 16×16 tile region" is not.

## Coining

Vocabulary is settled while an item is being written, not at review. A
word the user uses in a sense the glossary does not give — or one that
could mean two things ("account": the Customer or the User?) — goes to the
user with the sizing answer, and the item is written in the word that
comes back. A new term's entry lands in the same commit as the item that
first uses it, never batched. A spike is no such item: it suggests an entry
under `## Suggestions`, and the entry lands with the first bug or feature
item that uses the word.

## Starting out

A fresh project starts with an empty glossary and fills it as the domain
becomes clear, revising earlier decisions. An adopted project fills it
with the user's words, read out of the code and the docs and confirmed
with them.

## Renaming a term

A rename is a feature item of its own ([items.md](items.md), "Renames and
refactors"), and **the glossary entry changes in the same commit as the
code**, never before: announcing a new word and deferring the code makes
both words legitimate for as long as the rename sits unstarted. It is
never absorbed into the item that exposed the problem — that widens it past
its criterion, frozen at `start`. Wanting a
rename is a line in `workbench/BACKLOG.md` until someone executes it.

Do it now is the default: a rename is mechanical, and the occurrence count
the item opens with is also its cost. If that count makes the rename real
work, it drops to a backlog line and the item in flight continues in the
existing word.

### Aliases

When the old word survives somewhere immutable — an archived item, a
merged commit subject — the entry carries it, attached to the living term,
never as a ghost entry under the old word:

```markdown
**region** — the area the world is partitioned into for loading. *(was: shard)*
```

A rename executed before anything merged leaves no alias.

## Homographs

A term that collides with an established word in the project's own stack
is a bad term; reject it at coinage. Where the domain genuinely uses the
colliding word, **establish before renaming whether the term has a
non-domain sense in this codebase**; if it does, scope the rename to the
paths holding the domain sense, and the criterion reads as two counts:

```
scope:      src/world/, src/entity/   — the domain sense only
criterion:  rg -w hook src/world src/entity reports 0
            rg -w hook src/ reports 7, all under src/plugins/,
            each the framework sense
```

The evidence records the counts and the paths, not a justification per
occurrence.

## Binding

The glossary binds prose — items, commit subjects, documents — and code
identifiers, which is why a rename obliges the symbols to move with it and
is its own item.

## Rejected words

A word rejected at coinage — the user said `customer`, not `account` — is
forgotten by the next session, and an alias records only a rename, so a
rejection has this table as its home:

```markdown
## Use, never

| Use | Never | Because |
|---|---|---|
| customer | account | `account` is the login record in `src/auth` |
```

One row per rejection, in the same commit as the item that first used the
chosen word. `Because` names what the rejected word already means here, or
is empty when it was merely the second word for one thing.
