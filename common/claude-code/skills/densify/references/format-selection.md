# Format selection — worked conversions

Read when deciding what shape a section should become. Each case gives the tell, the conversion, and where it goes wrong.

> **The default target shape is `label · attr · attr` lines, not a table.** The
> worked examples below were written when a table was the default, so read every
> "→ table" conversion as "→ `·` lines" unless the block has four or more
> attributes per item, or unless the reader's question is answered by comparing
> values *down* a column (byte-offset layouts, matrices, ranked magnitudes).
> Measured: converting a table to `·` lines removed a header row, a separator row
> and two pipes per cell for a 10.5% token reduction on a nine-table document,
> while a `|` table against the prose it replaced came out at **−1.0%** — it
> costs about what the connectives it removes cost. See SKILL.md, ladder step 3.

## Contents

- [1. Parallel prose → table](#1-parallel-prose--table)
- [2. Nested headings → table with a category column](#2-nested-headings--table-with-a-category-column)
- [3. Conditional prose → condition/outcome pairs](#3-conditional-prose--conditionoutcome-pairs)
- [4. Narrative causation → arrow chain](#4-narrative-causation--arrow-chain)
- [5. Bullets that should stay bullets](#5-bullets-that-should-stay-bullets)
- [6. Where a table is the wrong answer](#6-where-a-table-is-the-wrong-answer)
- [7. Telegraphic rewrite patterns](#7-telegraphic-rewrite-patterns)
- [8. Symbols worth using](#8-symbols-worth-using)

---

## 1. Parallel prose → table

**Tell:** consecutive paragraphs with the same internal structure. Usually signalled by repeated sentence openings ("The X tier allows…", "The Y tier allows…").

**Before** (9 lines):

```
The Free tier allows 100 requests per minute, with a burst capacity of 200
requests. Free tier keys expire after 90 days of inactivity.

The Pro tier allows 1000 requests per minute, with a burst capacity of 5000
requests. Pro tier keys do not expire.

The Enterprise tier allows 10000 requests per minute with a burst of 50000.
Enterprise keys do not expire, unless the contract lapses.
```

**After** (5 lines):

```
| Tier | req/min | Burst | Key expiry |
|---|---|---|---|
| Free | 100 | 200 | 90d inactivity |
| Pro | 1000 | 5000 | never |
| Enterprise | 10000 | 50000 | never, unless contract lapses |
```

Note what survived: every number, and the `unless contract lapses` exception. The exception is the most compressible-looking and least droppable thing on the page.

**Failure mode:** attributes present for some rows and absent for others. Three `N/A` cells means the items were not actually parallel — split into two tables or keep prose.

---

## 2. Nested headings → table with a category column

**Tell:** `###` and `####` levels wrapping two or three lines each. The heading text is itself data and belongs in a cell.

**Before** (~24 lines with blanks):

```
### Authentication errors
#### 401
Returned when the API key is missing or malformed. Client should re-read config.
#### 403
Returned when the key is valid but lacks scope. Client should not retry.

### Rate errors
#### 429
Returned when the quota is exceeded. Client should back off per Retry-After.
```

**After** (6 lines):

```
| Class | Code | Cause | Client action |
|---|---|---|---|
| Auth | 401 | key missing/malformed | re-read config |
| Auth | 403 | key valid, scope insufficient | do not retry |
| Rate | 429 | quota exceeded | back off per `Retry-After` |
```

**Failure mode:** flattening levels that carry navigational meaning in a long doc. If readers reach the section by anchor link from elsewhere, the heading has a second job — keep it.

---

## 3. Conditional prose → condition/outcome pairs

**Tell:** "if… then", "when… the system", "in the case where".

**Before:**

```
If the queue depth exceeds 1000, the writer pauses. If it exceeds 5000, the
writer sheds load by dropping the lowest-priority messages, unless the
durability flag is set, in which case it blocks instead.
```

**After:**

```
| Queue depth | Writer |
|---|---|
| >1000 | pause |
| >5000 | shed lowest-priority · if `durability` set → block instead |
```

The nested exception rides inside the cell rather than becoming its own row — it modifies one outcome, not the whole table.

**Failure mode:** conditions that overlap or are order-dependent. A table implies independent rows. If evaluation order matters, use a numbered list and say so explicitly.

---

## 4. Narrative causation → arrow chain

**Before:**

```
The client sends a request. The gateway validates the token and, assuming it
is valid, forwards the request to the router, which selects a backend based on
the shard key and then proxies the response back to the client.
```

**After:**

```
client → gateway (validate token) → router (select backend by shard key) → backend → client
```

**Failure mode:** branching. An arrow chain implies one path. Two outcomes means a table or a list, not an arrow with a parenthetical fork.

---

## 5. Bullets that should stay bullets

Facts that share a topic but not a structure resist tabulation. Forcing them produces a two-column table where one column is a made-up label:

```
| Aspect | Detail |          ← the "Aspect" column is invented scaffolding
```

Keep them as bullets, just shorter. Bullets are already dense; the win is in the wording, not the shape.

---

## 6. Where a table is the wrong answer

| Situation                              | Use instead                               |
| -------------------------------------- | ----------------------------------------- |
| Fewer than 3 items                     | inline sentence or bullets                |
| Cells would hold 2+ sentences          | bullets, or split the table               |
| Would need 6+ columns                  | two tables, or bullets grouped by heading |
| Items share a topic but not attributes | bullets                                   |
| Order of evaluation matters            | numbered list                             |
| Content is one item with many facets   | bullets under a heading                   |

---

## 7. Telegraphic rewrite patterns

Apply last. Each of these is safe; the danger is in improvising beyond them.

| Pattern                | Before                             | After             |
| ---------------------- | ---------------------------------- | ----------------- |
| Denominalize           | performs a validation of the token | validates token   |
| Drop copula            | The timeout is set to 30s          | timeout 30s       |
| Drop articles in cells | the primary node                   | primary node      |
| Passive → active       | is invoked by the scheduler        | scheduler invokes |
| Hedge → fact or cut    | It should be noted that X          | X                 |
| Purpose clause         | in order to avoid                  | to avoid          |
| Existential            | There are three modes:             | Modes:            |

**Never** shorten by replacing a specific with a general: `retries 3 times` → `retries a few times` is a loss, not a compression, even though it saves characters.

---

## 8. Symbols worth using

Only these — they are unambiguous and need no key:

| Symbol    | Means                         | Example            |
| --------- | ----------------------------- | ------------------ |
| `→`       | leads to, becomes, then       | `429 → back off`   |
| `·`       | field separator inside a cell | `pause · log warn` |
| `≥ ≤ > <` | bounds                        | `≥3 rows`          |
| `—`       | not applicable / none         | `expiry: —`        |

Do not invent others. A symbol the reader must decode costs more attention than the words it replaced.
