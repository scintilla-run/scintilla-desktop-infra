# Desktop CLI repository boundary

Status: accepted for the current Scintilla desktop/local-runtime work.

## Decision

`scintilla-run/scintilla-cli` remains the canonical Rust CLI repository. Its typed `local-*` / desktop command family is the supported desktop CLI surface and is the explicit equivalent of a separately named `scintilla-desktop-cli` repository.

Do **not** create another Rust CLI repository solely to satisfy a naming pattern. Duplicating the CLI would create two argv/config authorities, two release streams, and a high risk that hosted and local deployment behavior diverge. The repository-family requirement is satisfied by a deliberate boundary plus a real local command surface in `scintilla-cli`, not by an empty alias repository.

## Ownership

- `scintilla-desktop-infra`: declarative single-host desired state, service packaging, routes, worker/runtime topology, and non-secret tunnel configuration.
- `scintilla-desktop-daemon`: sole machine-local lifecycle writer for Erlang ingress, workers, containers, tunnel, keep-awake, update/recovery state, and local receipts.
- `scintilla-cli`: canonical Rust operator CLI for hosted Scintilla and local desktop operations.
- `scintilla-desktop-app.rs`: native Rust peer UI client.
- `scintilla-flutter`: Flutter desktop/mobile peer client, capability-gated on mobile.

The CLI, Rust app, and Flutter client request typed transitions through the versioned daemon API. They must not independently supervise processes, containers, cloudflared, keep-awake helpers, or update commands when the daemon is present.

## Runtime semantics

This boundary preserves Scintilla's defining reusable worker/container semantics. Worker reuse policy belongs to the runtime/daemon desired state and must never be changed implicitly by CLI packaging.

## Promotion gates

The local command family is not considered complete merely because this ADR exists. The canonical Scintilla daemon protocol must be consolidated, the CLI must consume that exact protocol, and exact-head tests must prove stopped -> healthy -> tunnel reachable -> worker invocation -> update/restart -> shutdown/recovery. Zero-step Actions are admission failures, not green evidence.
