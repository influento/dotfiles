# Docs

Audit every document in the scope against the code it describes, and the
vocabulary of recent items against `workbench/GLOSSARY.md`. A finding is a
document that contradicts the code, one that should not exist under the rules
below, a fact that belongs in an item, or an item written in words the glossary
does not use.

When the scope is a file `workbench status` named in a `cap:` line, the
finding is the file itself: it is over its line cap, and the report says
which lines go — by the rules below, a line that restates the code, a
derivable one, a deleted thing's record — and which stay. Raising the cap
is a suggestion for the user, never the fix.

The rules follow.
