---
paths: ["src/solana/jupiter*", "src/solana/jupiter/**"]
---

# Jupiter: @jup-ag/api

One service, `src/solana/jupiter.ts`, holds the client from
`createJupiterApiClient({ basePath, apiKey })` (both from `Config`; the
default base path `https://api.jup.ag/swap/v1` needs `apiKey`,
`https://lite-api.jup.ag/swap/v1` does not) and exposes three Effects over
its three methods: `quoteGet`, `swapPost`, `swapInstructionsPost`. Nothing
else imports `@jup-ag/api` except for its types (`QuoteResponse`,
`SwapRequest`).

- A call is `Effect.tryPromise` with one tagged `JupiterError`; the
  client's `ResponseError` carries the HTTP response, so the service reads
  `response.status` and the body once to attach the reason (rate limit, no
  route, bad mint) before the caller sees it.
- Amounts are the mint's base units as a `string`/`bigint`, never a decimal
  number; `slippageBps` is an integer.
- `swapPost` returns a base64 `swapTransaction`: `getBase64Encoder().encode`
  then `getTransactionDecoder().decode` from `@solana/kit` gives the
  `Transaction`; sign with the Solana service's signer, send through the
  Solana service.
  `swapInstructionsPost` is the path when the swap is one instruction among
  others in a transaction the project builds itself.
- A quote is stale after a few slots: quote and swap in one Effect, and a
  `TransactionExpired`-shaped failure means a new quote, not a resend.
- The `*Raw` methods (`quoteGetRaw`) are for reading headers; the plain
  ones are what the service calls.

API: `node_modules/@jup-ag/api/dist/index.d.ts` (`SwapApi`, the request and
response models), then https://dev.jup.ag/docs/swap-api.
