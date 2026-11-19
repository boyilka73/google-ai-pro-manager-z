# ADR-001: SurrealDB as the single database core; CozoDB capabilities as design inputs

- Status: Accepted (architecture direction; implementation validation pending)
- Date: 2026-11-20
- Scope: Google AI Pro Manager Z
- Decision owners: project maintainers

## Context

The project needs durable account and workflow state, graph-like relationships, recursive queries, audit/history, and a compact local-first deployment. Running SurrealDB and CozoDB as two peer databases would duplicate persistence, backup, migration, consistency, and operational responsibilities.

The project is implemented primarily in Zig. SurrealDB's documented embedded SDK languages currently include Rust, .NET, Go, Java, JavaScript, and Python; Zig is not listed. Therefore "embedded SurrealDB" is not automatically a direct in-process integration for this Zig application.

## Decision

Use **one authoritative SurrealDB datastore**. Do not add CozoDB as a second production database.

Adopt the following capability mapping:

| Need | Chosen approach |
|---|---|
| Durable local storage | SurrealKV, after validating the exact pinned release and deployment mode |
| Record and relationship model | SurrealDB records, graph edges, schema and constraints |
| Recursive traversal | SurrealQL recursive graph traversal |
| Shortest path / path collection | SurrealQL graph path algorithms where query semantics fit |
| Custom graph algorithms | Application-side Zig implementation first; evaluate Surrealism only for functions that benefit from running inside the database transaction |
| Temporal history | SurrealKV versioned queries for system-time snapshots; explicit application validity intervals for business/effective time |
| Datalog-like rules | Translate bounded use cases into SurrealQL; implement a dedicated Zig rule engine only if requirements cannot be expressed clearly and efficiently |
| Audit and recovery | Explicit append-only domain events and workflow records, not storage-engine history alone |

## Important implementation constraints

### Zig integration

Do not claim zero-copy or in-process embedding from Zig without a supported Zig SDK or a maintained FFI bridge. Initial implementation should use the existing local SurrealDB service interface with strict loopback binding, authentication, request limits, and explicit timeouts.

A Rust embedding shim is a possible future option, but it introduces a Rust ABI/FFI boundary, build matrix and lifecycle complexity. It must be justified by measured latency or deployment requirements before adoption.

### Surrealism / WASM

Surrealism extensions are Rust components compiled to WASM, not native libraries linked into SurrealDB. Data crosses the boundary through the extension ABI and serialization. Extensions execute in a sandbox with per-call resource limits and explicit capabilities. In SurrealDB 4.0, each call gets a fresh instance; transaction access is through a transaction handle valid for the call.

Therefore:
- do not describe extension execution as native-speed execution;
- do not assume direct access to arbitrary database memory;
- grant no network, filesystem, scripting, or write capabilities unless specifically required;
- pin extension artifacts and review/sign them;
- benchmark serialization, instance setup, query callbacks and contention;
- keep ordinary application logic in Zig unless an extension demonstrably improves correctness or locality.

### Temporal semantics

Surre alKV versioned queries answer what the database stored at a past system-time point, when versioning is enabled and supported by the selected datastore. This is not automatically equivalent to CozoDB's explicit Validity semantics.

For domain facts that have both:
- system time (when this application learned or stored the fact), and
- effective time (when the fact was true in the provider/domain),

store explicit `valid_from`, `valid_until`, `observed_at`, and source/evidence metadata. Use SurrealKV VERSION as an additional storage-level history mechanism, not as a replacement for the domain model.

### Graph and Datalog semantics

SurrealQL supports graph traversal, recursive path expressions, and path algorithms including `+path`, `+collect`, and `+shortest`. These cover useful graph-query use cases but do not make SurrealQL a drop-in Datalog engine. If the project later needs recursive rule evaluation, stratified negation, provenance, or broad rule composition, capture concrete query requirements and benchmark a Zig-side evaluator against SurrealQL before changing the database decision.

## Consequences

Positive:
- one source of truth and one backup/restore model;
- fewer moving parts and fewer cross-database consistency failures;
- native SurrealDB graph, relational and temporal features can be used directly;
- custom logic remains portable in Zig unless database-local execution is justified.

Trade-offs:
- SurrealQL is not full Datalog;
- Surrealism introduces a Rust/WASM toolchain and runtime boundary;
- Zig does not have a documented official embedded SDK in the currently reviewed embedding page;
- versioned storage adds write/storage overhead and must be enabled deliberately;
- graph analytics beyond built-in traversal may be better computed in the application.

## Acceptance criteria before production

1. Pin an exact SurrealDB server/SDK version and verify all used query syntax against that version.
2. Run integration tests against the exact SurrealKV configuration used in production.
3. Verify backup, restore, crash recovery, version retention and disk-full behaviour.
4. Benchmark graph traversal and temporal queries with representative data.
5. If Surrealism is adopted, measure end-to-end latency and enforce least-privilege capabilities.
6. Keep CozoDB out of runtime dependencies unless a future ADR documents a concrete, unreplaceable Datalog requirement.

## Sources

- SurrealDB embedding: https://surrealdb.com/docs/integrate/embedding
- Rust embedding and SurrealKV: https://surrealdb.com/docs/reference/rust/embedding
- SurrealDB 4.0 extension architecture: https://surrealdb.com/docs/learn/extensions/guides/extension-architecture
- Extension capabilities: https://surrealdb.com/docs/reference/query-language/statements/define/extension
- Recursive graph traversal: https://surrealdb.com/docs/learn/data-models/graph/recursive-traversals
- Graph path algorithms: https://surrealdb.com/blog/surrealdb-2-2-benchmarking-graph-path-algorithms-and-foreign-key-constraints
- SurrealKV VERSION queries: https://surrealdb.com/docs/reference/query-language/statements/select
- CozoDB validity/time travel: https://docs.cozodb.org/en/latest/timetravel.html
