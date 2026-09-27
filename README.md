# Scintilla Desktop Infra

Single-host infrastructure for running Scintilla on a developer-owned laptop or desktop.

This repository is intentionally separate from `scintilla-run/scintilla-infra`, which remains the hosted/server infrastructure authority. Desktop self-hosting has different trust, lifecycle, power-management, update, worker, and credential boundaries.

## Ownership

| Repository | Responsibility |
| --- | --- |
| `scintilla-run/scintilla-desktop-infra` | desired desktop topology, install/service definitions, host integration, tunnel templates, worker policy, health/update policy, conformance fixtures |
| `scintilla-run/scintilla-desktop-daemon` | machine-local lifecycle authority; reconciles desired state and owns ingress, worker launch, updates, suspend/resume, power inhibition, tunnel lifecycle, and local IPC |
| `scintilla-run/scintilla-cli` | CLI client; daemon-backed lifecycle plus project build/deploy/dev workflows |
| `scintilla-run/scintilla-flutter` | desktop UI client for daemon status/actions/settings |
| `scintilla-run/scintilla-desktop-app.rs` | native Rust desktop UI client for daemon status/actions/settings |
| `scintilla-run/scintilla-infra` / `scintilla-run/scintilla-run-infra` | hosted/server infrastructure; not authoritative for an end-user desktop |

The daemon is the **single writer** for desktop runtime state. CLIs and desktop apps must not independently spawn/kill the Scintilla ingress server, local workers, containers, or `cloudflared` when the daemon is available.

## Desktop topology

```text
scintilla-cli / Flutter / Rust desktop app
                    |
                    v
         scintilla-desktop-daemon
           |         |          |
           v         v          v
     Erlang ingress  workers   cloudflared
       / control     |          named tunnel
          VM         +-- host processes
                     +-- containers
```

Scintilla desktop must support both containerized and non-containerized workers. The daemon owns launch policy, cancellation, timeout enforcement, resource accounting, cleanup, and worker-to-ingress attachment.

## Public exposure

Public exposure is opt-in. The Scintilla origin stays loopback-only and `cloudflared` is an outbound connector.

Persistent installs use a named Cloudflare Tunnel and a credentials file outside repositories/worktrees. Tunnel credentials must never appear in argv, logs, service definitions, or crash reports. Short-lived development may inject a token through a protected environment/secret store, but the daemon must never copy it into argv.

The daemon validates local readiness before bringing a public route online and withdraws/stops the route when ingress is intentionally drained or unhealthy.

## Lock-screen / power behavior

Both desktop apps expose one daemon-backed setting equivalent to:

```text
Keep Scintilla servers alive while this machine is locked/asleep
```

The daemon owns the platform-specific inhibitor. On macOS it may supervise `caffeinate` or use a native power-management API; clients do not launch competing keep-awake loops. Disabling the setting releases the inhibitor without stopping Scintilla. Explicit `stop` always wins.

## Runtime states

Clients render daemon-authoritative states from a shared vocabulary:

```text
stopped
starting
healthy
degraded
draining
updating
suspended
resuming
failed
```

Worker state remains separately observable so one failed worker does not falsely imply that ingress is down.

## Updates

Desktop updates are transactional: stage + verify, drain the replaceable ingress/runtime subtree, activate, verify readiness, commit the version marker only after success, and automatically roll back a failed activation. The daemon and the supervised Erlang ingress runtime are separate update targets; an Erlang hot upgrade must not require replacing the daemon.

## Initial deliverables

This repo should contain the declarative artifacts consumed/tested by the daemon:

- macOS, Linux, and Windows service/install definitions;
- an `ores-compose` desktop development/test profile;
- Cloudflare Tunnel templates with secret material excluded;
- ingress and worker health/readiness probes;
- worker runtime profiles for Rust, TypeScript, Python, Go, containers, and host processes;
- update/rollback policy and fixtures;
- daemon IPC conformance fixtures shared with the CLI and both desktop apps;
- CI checks rejecting plaintext credentials and token-bearing `cloudflared` argv.

See `docs/desktop-contract.md` for the control and security contract.