// A fixture is a real response, recorded once and committed under fixtures/,
// that a test reads instead of the network (ts-gate refuses the network in
// tests). Decoding goes through the wire Schema the production code uses, so
// a test sees exactly the types production sees; an invented object literal
// never stands in for a response.
//
//   const quote = yield* Fixture.load("jupiter/quote-sol-usdc.json", QuoteWire)
//   const ticks = Fixture.stream("solana/slots-2026-09-13.json", SlotWire)
//
// Recording is a live action, run once by a script, never inside a test:
//
//   Fixture.record("jupiter/quote-sol-usdc.json", QuoteWire, Jupiter.quote(sol, usdc))
import { Effect, Schema, Stream } from "effect";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";

/** Where fixtures live, relative to the project root: `fixtures/<source>/<name>.json`. */
export const FIXTURES = "fixtures";

export class FixtureError extends Schema.TaggedError<FixtureError>()(
  "FixtureError",
  {
    path: Schema.String,
    cause: Schema.Defect(),
  },
) {}

const file = (path: string) => join(FIXTURES, path);
const failed = (path: string) => (cause: unknown) =>
  new FixtureError({ path, cause });
const io = <A>(path: string, run: () => Promise<A>) =>
  Effect.tryPromise({ try: run, catch: failed(path) });
const write = async (target: string, text: string) => {
  await mkdir(dirname(target), { recursive: true });
  await writeFile(target, `${text}\n`);
};

/** Read `fixtures/<path>` and decode it through the wire schema. */
export const load = <S extends Schema.Top>(path: string, schema: S) =>
  Effect.gen(function* () {
    const text = yield* io(path, () => readFile(file(path), "utf8"));
    return yield* Effect.mapError(
      Schema.decodeUnknownEffect(Schema.fromJsonString(schema))(text),
      failed(path),
    );
  });

/** A recorded sequence (a JSON array) as a Stream, one decoded item at a time. */
export const stream = <S extends Schema.Top>(path: string, item: S) =>
  Stream.fromIterableEffect(load(path, Schema.Array(item)));

/**
 * Run `live` for real, encode the result through the wire schema and write
 * `fixtures/<path>`. A live action: a script or the CLI, once, its output
 * pasted as evidence — never a test (the network guard refuses it there).
 */
export const record = <S extends Schema.Top, E, R>(
  path: string,
  schema: S,
  live: Effect.Effect<S["Type"], E, R>,
) =>
  Effect.gen(function* () {
    const value = yield* live;
    const json = Schema.fromJsonString(schema, { space: 2 });
    const text = yield* Effect.mapError(
      Schema.encodeEffect(json)(value),
      failed(path),
    );
    yield* io(path, () => write(file(path), text));
  });
