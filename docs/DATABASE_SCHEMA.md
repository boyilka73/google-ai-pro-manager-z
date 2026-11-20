# Database schema baseline

Target: SurrealDB 4.0.1 with SurrealKV. The initial schema is in
`db/migrations/0001_core_schema.surql`.

## Data boundaries

The schema stores metadata and provider observations only. It must never store
Google passwords, recovery codes, TOTP seeds, cookies, browser storage state,
full card numbers, CVC/CVV, or reusable payment credentials.

`account_key` is an opaque application identifier (or keyed digest), not an
email address. `evidence_fingerprint` is an integrity/correlation field, not
cryptographic proof that a provider page was genuine. The trusted adapter and
user-visible confirmation process remain responsible for evidence provenance.

## Time model

- `observed_at`: when this application inspected the provider state.
- `valid_from` / `valid_until`: domain-effective interval, when known.
- SurrealKV version history: storage/system-time history, when enabled.

These are separate concepts. Storage version history does not replace explicit
domain validity fields.

## Lease protocol

`account_lease` is one record per account key. Acquisition must use the exact
record ID with `SELECT ... FOR UPDATE` in the same transaction as the create or
update. A plain query predicate such as "find an expired lease by account_key"
is not a safe lock protocol under snapshot isolation.

See [ADR-002](adr/ADR-002-surrealkv-lease-concurrency.md) for the required
algorithm and acceptance tests. The current Zig lease module is only an
in-memory reference implementation; it is not connected to this table.

## Migration status

This is a first schema draft, not a tested migration runner. Do not apply it to
valuable data until the SurrealDB 4.0.1 integration tests, migration ledger,
backup/restore path, and idempotent re-run test exist. Schema definitions use
`IF NOT EXISTS`; that alone does not prove the complete migration is safe to
replay after partial failure.
