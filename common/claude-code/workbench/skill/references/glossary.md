# Glossary

`workbench/GLOSSARY.md` holds the project's domain language. It exists because
the agent writes the items, and items are prose: if the vocabulary drifts, every
item is written in slightly different words and the archive stops being
searchable. It is the standing exception to "write nothing by default"
([docs.md](docs.md)), and it earns that by passing the multi-file test — a
term's meaning is precisely the thing no single file tells you.

## What goes in

**Domain language only.** A word this project uses in a narrower or different
sense than it is used generally. Not well-known concepts, not anything a reader
could look up.

The highest-value entries are ordinary words the project has **narrowed**.
Nobody misuses `MobPositionResolver`; everybody misuses `drift`. A term with no
general meaning is safe and usually does not need an entry at all.

**Never the same concept twice.** Two words for one thing is the failure the
file exists to prevent, so it must not be the first thing the file does.

**Brief.** A definition, not an explanation. There is no space for prose here.

**Nothing that would change when the implementation changes.** That is the test
for whether an entry has become a spec: if a refactor edits the entry while the
concept stayed the same, it was never a glossary entry. "The region the world is
partitioned into for loading" is an entry. "A 16×16 tile region" is a spec.

## Starting out

A fresh project starts with an empty glossary and fills it as the domain becomes
clear — often over weeks, and often revising earlier decisions. That is normal
and is not a sign the file is being neglected.

An existing project fills it during adoption ([adopt.md](adopt.md)).

## Renaming a term

A rename is a `rename` item ([items.md](items.md)), and **the glossary entry
changes in the same commit as the code**. Never before.

This is the whole protection against a mixed vocabulary. Announcing a new word
and deferring the code makes both words legitimate for as long as the rename
sits unstarted, and items written in that window are split between them.
Wanting a rename is a line in `workbench/BACKLOG.md` until someone executes it,
so vocabulary churn is throttled by the cost of actually doing it.

Do it now is the default: a rename is mechanical, and the occurrence count the
item opens with is also its cost estimate. If that count comes back large enough
that the rename is real work, it drops to a backlog line and the item in flight
continues in the existing word.

### Aliases

When the old word survives somewhere immutable — an archived item, or a merged
commit subject — the entry carries it:

```markdown
**region** — the area the world is partitioned into for loading. *(was: shard)*
```

Attached to the living term, never left as a ghost entry under the old word: a
search for the old word still lands on the right definition, and the file grows
by a parenthetical rather than a line.

A rename executed before anything merged leaves no alias. Nothing immutable
refers to the old word, so recording it would be a changelog, which
[docs.md](docs.md) forbids.

## Homographs

A term that collides with an established word in the project's own stack is a
bad term. Reject it at coinage — picking a different word costs nothing on day
one, and renaming later costs an afternoon plus permanent ambiguity in every
search.

Where the domain genuinely uses the colliding word, the rename procedure has to
account for it. **Before renaming, establish whether the term has a non-domain
sense in this codebase.** If it does, scope the rename to the paths holding the
domain sense and confirm the occurrences outside that scope really are the other
sense before writing the criterion. The criterion then reads as two counts
rather than one:

```
scope:      src/world/, src/entity/   — the domain sense only
criterion:  rg -w hook src/world src/entity reports 0
            rg -w hook src/ reports 7, all under src/plugins/,
            each the framework sense
```

The agent does that checking. The evidence records the counts and the paths, not
a justification per occurrence.

## Binding

The glossary binds prose — items, commit subjects, documents — and code
identifiers. Inconsistent vocabulary in an item is a pre-merge review finding.

Because it binds code, a rename obliges the symbols to move with it, which is
exactly why the rename is its own item with its own criterion instead of being
absorbed into whatever work exposed the problem.
