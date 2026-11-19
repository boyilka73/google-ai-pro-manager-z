# Google AI Pro Manager Z

**Phase 7 engineering source drop — not yet a production-ready application.**

A local-first Zig foundation for recording account metadata and independently verified subscription/renewal states. SurrealDB is the durable metadata store.

## Safety and scope

- No Google passwords, recovery codes, TOTP seeds, cookies, browser storage state, full payment card numbers, or CVC/CVV are accepted or persisted.
- No private Google API manipulation, eligibility bypass, forged offer references, or automated payment submission.
- Promotion stages (12 + 6 + 6) are separate records; the application must not claim a total until each stage is independently confirmed on the official user-visible account surface.
- Unknown or interrupted external operations are not retried until reconciled against fresh provider state.
- No background network activity is intended.

## Current implementation status

Phase 7 adds a pure recovery policy, safe diagnostic vocabulary, operations guidance and a release-check script. The complete Phase 1–6 application source tree is still being staged into this repository; this repository must not be mistaken for a complete source release yet.

**Important:** Zig compilation and live SurrealDB integration have not been verified in the authoring environment. The authenticated local API, UI, OS secret-store adapters and supported provider-facing adapter are not implemented. Do not deploy as a production system.

## Toolchain and commands

Pinned target: Zig 0.17.1. SurrealDB target: 4.0.1.

```sh
zig fmt --check build.zig src tests
zig build -Doptimize=ReleaseSafe
zig build test
python3 scripts/test-migration-runner.py
scripts/release-check.sh
```

See `docs/PHASE7_OPERATIONS.md` for deployment requirements and release criteria, and `db/README.md` for database setup (when the full database source tree is present).

## License

Apache-2.0. See `LICENSE` and `NOTICE`. Third-party dependency licenses must be reviewed before redistribution.
