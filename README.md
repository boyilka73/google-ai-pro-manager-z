# Google AI Pro Manager Z

**Phase 7 engineering source drop — not yet a production-ready application.**

A local-first Zig foundation for recording account metadata and independently verified subscription/renewal states. SurrealDB is the intended durable metadata store.

## Safety and scope

- No Google passwords, recovery codes, TOTP seeds, cookies, browser storage state, full payment card numbers, or CVC/CVV are accepted or persisted.
- No private Google API manipulation, eligibility bypass, forged offer references, or automated payment submission.
- Promotion stages (12 + 6 + 6) are separate records; the application must not claim a total until each stage is independently confirmed on the official user-visible account surface.
- Unknown or interrupted external operations are not retried until reconciled against fresh provider state.
- No background network activity is intended.

## Current implementation status

The full Phase 1–7 source archive exists as a separate engineering artifact, but the repository's source tree is still being staged and must not be mistaken for a complete buildable release. Phase 7.1 hardening primitives now committed here include provider-observation validation, conservative retry classification, lease/fencing tests, and expanded test imports. The full workflow integration is present in the Phase 7.1 source archive but has not yet been imported into this repository.

**Important:** Zig compilation and live SurrealDB integration have not been verified. The authenticated local API, UI, OS secret-store adapters and supported provider-facing adapter are not implemented. Do not deploy as a production system.

## Toolchain and commands

Pinned target: Zig 0.17.1. SurrealDB target: 4.0.1.

```sh
zig fmt --check build.zig src tests
zig build -Doptimize=ReleaseSafe
zig build test
python3 scripts/test-migration-runner.py
scripts/release-check.sh
```

See `docs/PHASE7_OPERATIONS.md` for deployment requirements and release criteria.

## License

Apache-2.0. See `LICENSE` and `NOTICE`. Third-party dependency licenses must be reviewed before redistribution.
