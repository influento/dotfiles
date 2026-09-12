---
paths: ["src/solana/**"]
---

# Solana: @solana/kit

Kit, not `@solana/web3.js`: `Connection`, `PublicKey`, `Keypair`,
`Transaction` and `sendAndConfirmTransaction` do not exist here. Kit is
functions over plain values: `address()`, `createSolanaRpc()`,
`createTransactionMessage()` piped through `setTransactionMessageFeePayerSigner`,
`setTransactionMessageLifetimeUsingBlockhash`, `appendTransactionMessageInstructions`,
then `signTransactionMessageWithSigners` and `sendAndConfirmTransactionFactory`.
Check a name in `node_modules/@solana/kit/dist/types/` (and the `@solana/<pkg>/dist/types/` it re-exports) before writing it: the README lags the types.

Every RPC call and every send goes through one service, `src/solana/solana.ts`;
nothing else imports `@solana/kit` except for types, codecs and pure helpers
(`address`, `lamports`, `getBase58Decoder`, the `@solana/codecs` builders).

| Piece | How |
|---|---|
| clients | `createSolanaRpc(url)` and `createSolanaRpcSubscriptions(wsUrl)` in the service's layer, URLs from `Config`; the cluster brand (`mainnet(...)`, `devnet(...)`) matches the URL |
| calls | an RPC method returns a pending request; `Effect.tryPromise({ try: () => rpc.getBalance(a).send({ abortSignal }), catch })` with one tagged `SolanaError` wrapping kit's `SolanaError` (`isSolanaError(e, SOLANA_ERROR__...)` inside the service where the caller can act on the code) |
| signers | `createKeyPairSignerFromBytes` from `Config.Redacted` bytes at layer build, once; the signer is a value the service holds, never rebuilt per call |
| send | `sendAndConfirmTransactionFactory({ rpc, rpcSubscriptions })` built once in the layer; a send is `Effect.tryPromise` around it with `abortSignal` from the interrupt |
| compute | `fillTransactionMessageProvisoryResourceLimits` while building, then `estimateAndSetResourceLimitsFactory(estimateResourceLimitsFactory({ rpc }))` before signing anything that is not trivial. `estimateComputeUnitLimitFactory`, which the package README still shows, is not in 8.3.0's types |
| programs | a generated client (`@solana-program/*`, Codama) over hand-written instruction data; the codec of an account is a `getXDecoder()` from that client |
| retries, timeouts | `Schedule` and `Effect.timeout` around the Effect; a blockhash expiry is a new message, not a retry of the old one |
| subscriptions | `rpcSubscriptions.accountNotifications(a).subscribe({ abortSignal })` is an `AsyncIterable`: `Stream.fromAsyncIterable`, the abort in the finalizer |

API: `node_modules/@solana/kit/README.md` for the helpers kit adds, then the
README of the package that owns a function (`node_modules/@solana/rpc/`,
`transaction-messages/`, `signers/`, `codecs/`, `errors/`), then
https://www.solanakit.com/docs.
