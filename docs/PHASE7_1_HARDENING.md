# Phase 7.1 — Hardening notes

## Delivered primitives

- `src/core/evidence.zig` validates normalized provider observations for source classification, account binding, stage index, freshness (five-minute maximum), and fingerprint shape.
- `src/core/retry_policy.zig` separates safe pre-effect transient failures from permanent failures and operations whose external effect may have occurred. The latter always require reconciliation.
- `src/core/lease.zig` provides an in-memory lease reference with monotonic fencing tokens. Expiry arithmetic is checked before mutating the lease.
- `tests/tests.zig` imports the new modules so their unit tests are included in the Zig test build.

## Trust boundary

The evidence object is not cryptographic proof and its fields are not unforgeable. The provider adapter is a trust boundary: it may construct an observation only after inspecting an official user-visible provider surface. The core validates completeness and consistency, not the authenticity of a screenshot or browser session.

## Retry invariants

- Only failures known to occur before an external side effect may be retried automatically.
- Rate-limit delays are bounded to one hour.
- Possibly-effectful failures require a fresh provider read before any retry.
- Retry budgets are per stage in the integrated Phase 7.1 source archive.

## Lease limitation

The current lease type is an in-memory reference implementation. It does not coordinate multiple processes or survive restart. Production multi-process safety requires an atomic database compare-and-swap with owner, expiry and fencing token in the same transaction as the protected state transition.

## Verification status

Python migration tests: 8/8 passed. Python syntax and shell syntax checks passed. Zig formatting, compilation and unit tests remain unverified until Zig 0.17.1 is available. Live SurrealDB transaction and lease behavior remain unverified until tested against the pinned server.
