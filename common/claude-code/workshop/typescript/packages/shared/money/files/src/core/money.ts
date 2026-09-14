// Money never travels as a number. Chain units (wei, lamports, satoshi) are
// integers: a branded bigint per unit. Prices, PnL, rates are exact decimals:
// a branded BigDecimal per kind. A plain number cannot reach a function that
// takes one of these; the only way in is a Schema decode at a boundary.
//
//   export const Lamports = Units("Lamports")
//   export type Lamports = typeof Lamports.Type
//   export const Price = Decimal("Price")
//   export type Price = typeof Price.Type
//
// Arithmetic stays in the underlying type (BigInt ops, `BigDecimal.multiply`,
// `BigDecimal.sum`) and is re-branded where the result becomes a domain value:
// `Pnl.make(BigDecimal.subtract(a, b))`.
import { Schema } from "effect"

/** A branded bigint: the integer unit of one chain or asset. */
export const Units = <B extends string>(brand: B) => Schema.BigInt.pipe(Schema.brand(brand))

/** The same unit as it arrives from a JSON-RPC response: a decimal string. */
export const UnitsFromString = <B extends string>(brand: B) => Schema.BigIntFromString.pipe(Schema.brand(brand))

/** A branded BigDecimal: an exact decimal kind (price, PnL, rate, fee). */
export const Decimal = <B extends string>(brand: B) => Schema.BigDecimal.pipe(Schema.brand(brand))

/** The same kind as it arrives from an API: a decimal string, never a float. */
export const DecimalFromString = <B extends string>(brand: B) => Schema.BigDecimalFromString.pipe(Schema.brand(brand))
