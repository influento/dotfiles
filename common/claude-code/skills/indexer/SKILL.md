---
name: indexer
description: Scan-list register for documents. One line per source section — topic name, then one clause on what the section decides. TRIGGER when user says "indexer", "index this file", "name the topics", "what is in this file", or invokes /indexer.
---

## Task class

The input is a document. The output is a scannable index of its topics.

The output is not a summary. A reader uses the index to find the section to open.

## The line

Give one line to each major section of the source. Use this form:

`**Topic name** — one clause, 100 characters or fewer for the whole line.`

- Name the topic with the word a reader looks for. If the heading is opaque, use the reader's word.
- Write what the section decides. Do not write that the section "covers" or "discusses" a subject.
- Put one topic on one line. Never put two topics on one line.
- Write one clause. Never write a second sentence.

## Coverage

This rule binds before all others. Read every heading in the source. Give each heading a line, or name it in a `dropped:` line at the end. Never omit a heading in silence.

Count the headings before you write. Count the lines after you write. If the two counts are different, correct the output before you send it.

## Budget

The budget is proportional, not fixed. One section gets one line. A document with 50 sections gets 50 lines.

Write 2 lines or fewer of prose above the list. These lines say what the document is. Write no closing summary.

## Register

Drop articles, filler, hedges, and pleasantries.
Keep these exact: identifiers, paths, flags, numbers, units.
Make the topic name bold. The reader scans the left edge of the list.
Put an em dash between the name and the clause.

## Out of scope

This register drops mechanisms, reasons, invariants, and failure paths. Under-answering is correct here. If the reader needs a mechanism, the reader must ask for a different register.

## Self-check before you send

1. Is the heading count equal to the line count? If the counts are different, add the missing lines or a `dropped:` line.
2. Is a line longer than 100 characters? Cut the clause.
3. Does a line name two topics? Divide it into two lines.
4. Does a clause say "covers X" or "discusses X"? Write what X is instead.
5. Is there a closing summary? Delete it.

## Persistence

This register is active until the user says "stop indexer", "normal mode", or "verbose again". A bare "stop" does not end it.

## Unchanged by indexer

Code, comments, commit messages, file contents, and quoted material stay as they are.
