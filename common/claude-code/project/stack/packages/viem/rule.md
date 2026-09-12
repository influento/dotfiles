---
paths: ["src/evm/**"]
---

# EVM: viem

The only EVM library: no ethers, no web3.js, no per-chain SDK that wraps a
node. Every EVM call goes through one service, `src/evm/evm.ts`, that holds
the viem clients and exposes Effects; nothing else imports `viem` except for
types and pure helpers (`parseAbi`, `formatUnits`, `getAddress`, `isAddress`).

| Piece | How |
|---|---|
| clients | `createPublicClient({ chain, transport: http(url) })` per chain, built in the service's layer from `Config`; `createWalletClient` only where the project signs, with the key from `Config.Redacted` |
| calls | `Effect.tryPromise({ try: () => client.readContract(...), catch: (e) => new EvmError({ cause: e }) })`, one tagged error class; viem's own errors (`ContractFunctionRevertedError`, `BaseError.walk`) are matched inside the service to produce a finer tag where the caller can act on it |
| ABIs | `const abi = [...] as const` or `parseAbi([...])` in `src/evm/abi/`, so `readContract` is typed; never a JSON file cast to `Abi` |
| amounts | `bigint` end to end; `parseUnits`/`formatUnits` only at the edge that shows a human |
| addresses | `Address` from viem, checksummed by `getAddress` at the boundary where a string enters |
| retries, timeouts | `Schedule` and `Effect.timeout` around the Effect, not viem's `retryCount`/`timeout` transport options, so the policy is one place |
| events | `client.getLogs`/`watchContractEvent` wrapped as a `Stream` (`Stream.asyncPush` with the unwatch as the finalizer) |

API: the types under `node_modules/viem/` (`clients/`, `actions/`,
`utils/`), then https://viem.sh/llms.txt for the index of docs and
https://viem.sh/docs/<page> for one page.
