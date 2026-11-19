# Phase 7 — operational hardening

Phase 7 adds explicit recovery decisions, a closed diagnostic vocabulary, and a release gate. It does not add an automatic Google checkout/claim flow, browser session capture, credential storage, or payment submission.

## Recovery contract

An operation interrupted while pending or running must first become uncertain. The coordinator then obtains a fresh observation from the official, user-visible provider account surface:

| Stored state | Provider observation | Decision |
|---|---|---|
| pending / running | any | mark uncertain |
| uncertain | unknown | wait; do not retry |
| uncertain | effect present | reconcile as completed |
| uncertain | effect absent | permit a new attempt after recording the observation |
| succeeded / reconciled | any | never replay |
| failed | any | manual review |

The pure policy is in src/core/recovery_policy.zig. The caller must persist the observation and audit event atomically before starting a new operation. The policy never initiates I/O or retries.

## Diagnostics contract

Use src/security/safe_diagnostics.zig's closed ErrorCode vocabulary. Never log raw HTTP request/response bodies, authorization headers, URL query strings, cookies, browser profiles, user-entered credentials, payment details, or TOTP material. Map provider errors to stable codes before they reach logs or support bundles.

## Release gate

Run scripts/release-check.sh with Zig 0.17.1. It checks formatting, ReleaseSafe build, unit tests, migration-runner tests, Python syntax, shell syntax, and coarse API-key/private-key patterns. This is not a DLP tool or security audit.

A release candidate additionally requires:
1. surreal db validate 'db/**/*.surql' using the pinned server.
2. scripts/test-surrealdb-live.sh against a disposable database with synthetic data.
3. The complete OS build matrix.
4. Manual review of migration compatibility, backups/restores, threat model, and third-party licenses.

## Deployment rules

- Bind any future UI/API to loopback by default. Validate the actual accepted socket peer, not just Host or Origin.
- Require per-installation authentication, CSRF protection for state-changing browser requests, strict Origin checks, bounded request bodies, and rate limits before exposing an API.
- Use HTTPS for remote SurrealDB endpoints. Plain HTTP is permitted only for exact loopback hosts.
- Use a dedicated least-privilege SurrealDB user; never run the app as database root.
- Keep database tokens out of the repository and process arguments. Prefer the OS secret store; environment variables are a deployment fallback and may be visible to privileged process inspection or crash diagnostics.
- Back up metadata and test restoration before schema upgrades.
- Never store Google credentials, recovery codes, TOTP seeds, cookies, browser storage state, full payment card numbers, or CVC/CVV.

## Scope boundary

The product records account metadata and independently verified subscription/renewal states. It must not bypass eligibility checks, alter private provider APIs, forge offer references, evade account controls, or submit payment actions. Future provider integration must use supported user-visible flows and remain opt-in, reviewable, and independently verifiable.
