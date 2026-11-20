# ADR-002: Durable account leases on SurrealKV

- Status: Accepted for implementation; integration tests pending
- Date: 2026-11-20
- Scope: Cross-process exclusion for account-scoped workflow operations

## Context

The existing Zig `Lease` type is an in-memory reference primitive. It cannot coordinate multiple application processes and must never be treated as a durable lock.

The target datastore is SurrealKV under SurrealDB 4.0.1. SurrealKV provides snapshot isolation, not serializable isolation. Therefore an implementation must not rely on a plain read-then-write transaction to protect a decision based on a record read without writing it.

## Decision

Use one durable lease record per opaque account key. The transaction must explicitly register that exact record ID with `SELECT ... FOR UPDATE`, including when the record does not yet exist. The lease record is then created or conditionally updated in the same short transaction.

The account key must be a stable, non-secret internal identifier or a keyed digest. Do not use a Google email address, password, session identifier, cookie, or payment identifier as the record ID.

### Required acquisition algorithm

1. Derive the opaque account key outside the query and bind it as a parameter.
2. Begin a short transaction.
3. Read the exact `account_lease:<key>` record with `FOR UPDATE`.
4. If it exists and `expires_at > now`, abort with `LeaseHeld`.
5. Otherwise increment `fencing_token` (starting at 1), set a fresh random `owner_id`, `acquired_at`, `expires_at`, and `updated_at`.
6. Commit. A transaction conflict means acquisition failed; retry the entire transaction with a bounded policy.
7. Return the owner ID and fencing token only after confirmed commit.

The exact-record `FOR UPDATE` read is essential: it brings the lease record into commit-time conflict detection, and SurrealDB documents that an absent record ID is also covered. Concurrent first-time creators therefore cannot both commit a lease for the same ID.

### Required heartbeat, release, and protected writes

- Heartbeat and release must update only when both `owner_id` and `fencing_token` match and the lease has not expired.
- Every durable workflow mutation performed under a lease must validate the current owner and fencing token in the same transaction as the mutation.
- A stale worker must be rejected even if it resumes after a newer worker acquired the lease.
- Never use process-local time as the sole source for cross-process expiry decisions unless clock-skew bounds are explicitly enforced. Prefer a trusted coordinator clock or a documented bounded-skew policy.
- A lease does not authorize replay of an uncertain external side effect. Provider reconciliation remains mandatory.

## SurrealQL transaction shape (illustrative; integration-test before use)

```sql
BEGIN;
LET $current = SELECT * FROM ONLY account_lease:$account_key FOR UPDATE;

IF $current != NONE AND $current.expires_at > $now {
    THROW "LeaseHeld";
};

LET $next_fence = IF $current = NONE THEN 1 ELSE $current.fencing_token + 1 END;

UPSERT account_lease:$account_key CONTENT {
    account_key: $account_key,
    owner_id: $owner_id,
    fencing_token: $next_fence,
    acquired_at: $now,
    expires_at: $expires_at,
    updated_at: $now
};

COMMIT;
```

This is a query-shape sketch, not a claim that the exact syntax or SDK transaction behaviour has been tested. The implementation must verify the selected SurrealDB 4.0.1 parser, parameter binding, conflict error shape, and transaction cancellation semantics before relying on it.

## Consequences

- The database, not a Zig process, becomes the authority for lease ownership.
- Snapshot isolation remains sufficient only because the exact lease record is explicitly enrolled with `FOR UPDATE`.
- Transaction conflicts are expected under contention and must be handled as failed acquisition attempts.
- The lease is a coordination primitive, not proof that a provider operation completed.
- SurrealKV's lack of SERIALIZABLE isolation is not a blocker for this exact-record protocol, but it rules out unsafe predicate-only locking patterns.

## Acceptance tests

1. Two independent clients concurrently acquire a previously absent account lease; exactly one commits.
2. Two independent clients contend for an expired lease; exactly one new owner commits.
3. A stale fencing token cannot heartbeat, release, or mutate workflow state.
4. A heartbeat racing with expiry/reacquisition cannot resurrect an old owner.
5. Process termination after external checkout but before provider verification produces an uncertain operation, never an automatic retry.
6. Tests run against the exact pinned SurrealDB 4.0.1 + SurrealKV server, not a mock or in-memory-only substitute.

## References

- SurrealDB transactions and `FOR UPDATE`: https://surrealdb.com/docs/learn/querying/concepts-and-guides/transactions
- `BEGIN` statement and storage-engine isolation support: https://surrealdb.com/docs/reference/query-language/statements/begin
- SurrealDB 4.0 release notes: https://surrealdb.com/releases/4.0
