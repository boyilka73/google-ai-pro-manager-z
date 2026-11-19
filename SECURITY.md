# Security Policy

## Scope

This project handles account metadata and provider-observed subscription status. It must not store Google credentials, recovery codes, TOTP seeds, cookies, browser session state, full card numbers, or CVC/CVV.

## Reporting

Please do not disclose vulnerabilities in public issues. Contact the repository owner privately through GitHub's security advisory/reporting interface where available. Include affected commit, reproduction steps, impact, and a minimal proof of concept. Do not include real credentials, payment data, or personal account identifiers.

## Deployment baseline

- Do not expose an unauthenticated local API.
- Bind local services to loopback and validate the accepted socket peer.
- Use CSRF protection, strict Origin checks, request-size limits and authentication for browser-facing state changes.
- Use HTTPS for remote database endpoints and a least-privilege SurrealDB user.
- Keep secrets outside source control, command-line arguments, logs and crash reports.
- Use synthetic data for tests and verify backups before schema upgrades.

## Status

This repository is an uncompiled development source drop until CI build and live database tests pass. Do not use it to automate account or payment actions.
