#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
fail() { printf 'release-check: %s\n' "$1" >&2; exit 1; }
command -v zig >/dev/null 2>&1 || fail 'zig is required (expected 0.17.1)'
[[ "$(zig version)" == "0.17.1" ]] || fail "expected Zig 0.17.1, found $(zig version)"
command -v python3 >/dev/null 2>&1 || fail 'python3 is required'
[[ -f LICENSE ]] || fail 'LICENSE file is missing'
[[ -f SECURITY.md ]] || fail 'SECURITY.md is missing'
zig fmt --check build.zig src tests
zig build -Doptimize=ReleaseSafe
zig build test
python3 -m py_compile scripts/migrate-surrealdb.py scripts/test-migration-runner.py scripts/test-surrealdb-live.py
python3 scripts/test-migration-runner.py
for file in scripts/*.sh; do bash -n "$file"; done
if grep -RInE --exclude='*.md' --exclude='*.surql' '(AIza[0-9A-Za-z_-]{30,}|-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----)' src tests; then
  fail 'possible API key/private key pattern found; review manually'
fi
printf '%s\n' 'Release checks passed. Live SurrealDB tests and a security review are still required.'
