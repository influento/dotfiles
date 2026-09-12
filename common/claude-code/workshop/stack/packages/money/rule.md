---
paths: ["src/**"]
---

# Money

An amount is never a JS `number`: a float64 overflows wei and lamports and
loses precision on prices, and a float multiplication on an amount is a wrong
trade, not a crash. `src/core/money.ts` (from the `money` package, the
project's file now) gives the constructors; the project names its units and
kinds once, in `src/core/`, and every signature that carries money uses them:

```ts
export const Lamports = Units("Lamports")          // branded bigint
export type Lamports = typeof Lamports.Type
export const LamportsWire = UnitsFromString("Lamports")   // "1000000" off the RPC
export const Price = Decimal("Price")              // branded BigDecimal
export type Price = typeof Price.Type
export const PriceWire = DecimalFromString("Price")      // "1.25" off an API
```

- A value enters only through a decode at the boundary
  (`Schema.decodeUnknownSync(LamportsWire)(json.lamports)`, or the wire
  schema inside the response `Schema.Struct`). Never `BigInt(x)` or
  `BigDecimal.unsafeFromString` on outside data.
- Arithmetic stays in the underlying type: `bigint` operators for units,
  `BigDecimal.multiply`, `sum`, `subtract`, `divide`, `round` for kinds.
  The result is re-branded where it becomes a domain value:
  `Pnl.make(BigDecimal.subtract(exit, entry))`. A unit never meets a kind
  without an explicit conversion function in `src/core/` that says the scale.
- Out: `BigDecimal.format` for display, `String(units)` for the wire. The
  gate refuses `parseFloat`, `parseInt`, `Number(...)`, `.toNumber()` and
  `.toFixed()` under `src/`; a number is for counts and indices only.
- Storage and contracts carry the wire form (a string column, a string
  field) and decode on the way back; a database `real` or a JSON number
  for money is a review finding.
