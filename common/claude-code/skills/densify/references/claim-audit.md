# Blind claim audit

Gate 3, the semantic gate. Run after `verify.py` exits 0 — gates 1 and 2 prove the _tokens_ and the _obligation counts_ survived, not the _relationships between them_. Never the acceptance gate: blind auditors returned 40/40 recall on outputs that had lost 26 identifiers and dropped 25 obligations.

## Why blind

A reader holding both documents confirms recoverability from memory of the original. They read the compressed line, recognize the fact they already know, and mark it recoverable — even when the compressed text alone would not support it. This is not carelessness; it is unavoidable, and it makes the audit worthless.

The auditor must see **only the compressed document**. Where subagents exist, spawn one with the compressed file and the claim list, and nothing else. Where they do not, read the compressed doc in isolation and answer "does this text, alone, support the claim?" — not "do I know this to be true?"

## Step 1 — extract claims from the original

One line per atomic claim. A claim is a single subject–predicate–object with every qualifier attached to it. Split compound sentences; never split a qualifier away from what it modifies.

```
C01  Free tier limit = 100 req/min
C02  Free tier burst = 200 req
C03  Free tier keys expire after 90d of INACTIVITY (not 90d absolute)
C04  Enterprise keys never expire EXCEPT when contract lapses
C05  On limit exceeded, server returns 429
C06  On limit exceeded, server sets Retry-After header
C07  Client backoff is exponential, starts 1s, caps 60s
C08  Client retry count must not exceed 5
C09  C08 is normative MUST NOT, not a recommendation
```

Rules that decide whether the audit finds anything:

- **Qualifiers get their own emphasis.** C03 and C04 exist to test the exception, which is exactly what compression eats.
- **Normative force is a separate claim** (C09). A compressed doc that conveys the number but not the obligation has lost something a token diff cannot see.
- **Dependencies are claims.** "Step 3 requires the output of step 1" is a claim even though no noun was deleted.
- **Rationale is a claim.** In an ADR, "chose Postgres _because_ the team already operates it" is two claims: the choice, and the reason.
- Cap at ~60 claims for a long doc by sampling the risky sections — conditionals, exceptions, anything with numbers — rather than sampling uniformly. Uniform sampling wastes the budget on prose that was safe to cut.

## Step 2 — audit against the compressed doc alone

Each claim gets one of three marks:

| Mark          | Meaning                                                   |
| ------------- | --------------------------------------------------------- |
| `recoverable` | The compressed text alone states or directly entails this |
| `ambiguous`   | A reader could plausibly read it either way               |
| `lost`        | Not present, or the compressed text contradicts it        |

`ambiguous` is a failure, not a pass. If a spec can be read two ways, it will be read the wrong way by someone acting on it.

## Step 3 — restore

Everything not `recoverable` goes back into the document. Restore in the densest form that resolves the mark — usually a qualifier appended to an existing cell, not a new paragraph. Then re-run `verify.py`, since restoration changes the text and can break normative parity in the other direction.

## Worked example

Compressed doc under audit:

```
| Tier | req/min | Burst | Key expiry |
|---|---|---|---|
| Free | 100 | 200 | 90d |
```

| Claim                                  | Mark          | Reason                                  |
| -------------------------------------- | ------------- | --------------------------------------- |
| C01 limit 100                          | recoverable   | stated                                  |
| C02 burst 200                          | recoverable   | stated                                  |
| C03 expiry after 90d **of inactivity** | **ambiguous** | `90d` alone reads as 90 days from issue |

The deterministic gate passed this — `90d` is present, no token vanished. Only the blind read catches that the trigger condition was silently changed from _inactivity_ to _age_. Fix: `90d inactivity`. Three characters, and the difference between a correct doc and a wrong one.

## Recording the result

Keep the claim table with the output while iterating. Report only the marks that were not `recoverable`, and what was restored for each — a list of 60 passing claims is noise, but "restored 3 dropped conditions in §2, §5" is the thing the user needs to trust the result.
