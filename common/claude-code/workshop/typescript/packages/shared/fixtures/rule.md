---
paths: ["**/*.test.ts", "**/*.test.tsx", "fixtures/**", "scripts/**"]
---

# Fixtures

A test never reaches the network (ts-gate's guard throws), so external data
enters a test as a fixture: a real response, recorded once, committed under
`fixtures/<source>/<name>.json`, read through `src/core/fixture.ts` (from the
`fixtures` package, the project's file now).

- **Read.** `Fixture.load(path, WireSchema)` decodes the file through the
  same `Schema` the production code decodes the response with, so the test
  sees production's types; `Fixture.stream(path, ItemSchema)` gives a
  recorded sequence one item at a time. A test whose input is an object
  literal shaped by hand from the types is a review finding: it proves the
  literal, not the code.
- **Record.** `Fixture.record(path, WireSchema, liveEffect)` runs the call
  for real and writes the file. It lives in a script (`scripts/record-<source>.ts`,
  `npm run record -- <what>`), never in a test, and a person runs it: once,
  the output pasted into the item as evidence, never looped. A test with no
  fixture for its case asks for a recording; it does not invent one.
- **Live tier.** Code that must be proven against the real endpoint or a real
  model gets a `*.live.test.ts` beside its unit test, run by
  `npm run test:live`, never by the gate. It is never the only test of that
  code.
- **Model output is a fixture too.** A unit test of a loop around a model
  replays a recorded completion; the model itself is exercised in the live
  tier.
- A fixture is data, committed as recorded. Trimming a large one is fine;
  editing values by hand is not, because then it is a literal again.
