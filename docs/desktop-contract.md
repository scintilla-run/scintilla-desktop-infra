# Scintilla desktop self-host contract v1

This document defines the contract between desktop infrastructure, `scintilla-desktop-daemon`, `scintilla-cli`, and both desktop applications.

## 1. Authority

`scintilla-desktop-daemon` is the only component allowed to mutate machine-local Scintilla lifecycle state once installed. The CLI and desktop apps are clients. `scintilla-desktop-infra` owns declarative topology, platform integration, worker policy, security policy, and conformance fixtures.

Direct CLI-only local development remains useful when no daemon is installed, but when the daemon is reachable local lifecycle commands must route through it instead of creating a second ingress VM or independent worker supervisor.

## 2. IPC

Preferred transports:

- macOS/Linux: Unix domain socket owned by the current user;
- Windows: named pipe restricted to the current user;
- test/debug fallback: loopback-only HTTP on `127.0.0.1`/`::1`.

Every request and response carries a protocol version. Unknown major versions fail closed with an actionable compatibility error.

Minimum operation family:

```text
status
doctor
start
stop
restart
drain
suspend
resume
upgrade.plan
upgrade.apply
upgrade.rollback
tunnel.status
tunnel.start
tunnel.stop
tunnel.configure
keep_alive.get
keep_alive.set
workers.list
workers.start
workers.stop
workers.cancel
logs.follow
events.follow
```

Mutating operations return an operation ID so clients can follow progress without guessing from process state.

## 3. Runtime topology

The desktop appliance contains one long-lived Erlang ingress/control VM plus workers launched by the daemon.

Workers may be:

- containerized;
- non-container host processes;
- Rust;
- TypeScript/Node.js;
- Python;
- Go;
- additional runtimes admitted by the Scintilla worker contract.

The daemon is responsible for launch, environment construction, cancellation, timeout enforcement, termination escalation, cleanup, and ownership tracking. The ingress server routes work; it does not become a second host-level process supervisor.

## 4. Runtime identity

The daemon records more than a PID before signaling any ingress or worker process. Ownership evidence includes PID plus stable identity such as process start time, executable/container identity, and activated build/version. PID reuse must never allow Scintilla to signal an unrelated process.

Container identity must likewise be tied to an expected immutable image/build identity before destructive operations.

## 5. Suspend/resume

Suspend is an explicit state transition, not an untracked OS signal. The daemon:

1. acquires the local lifecycle lease;
2. prevents new work from being assigned;
3. drains active work to the configured deadline;
4. snapshots/records the durable local state needed to resume safely;
5. suspends eligible ingress/worker processes or containers;
6. records final state and ownership evidence.

Resume verifies identity and compatibility before accepting new work. Per-worker suspend capability is explicit; unsupported runtimes are drained/stopped instead of pretending they were safely suspended.

## 6. Cloudflare Tunnel

The public edge is optional and outbound-only.

Persistent installs use a **named tunnel with a credentials file** kept outside repositories and worktrees. The daemon never emits a tunnel token into argv. Token/environment mode is development-only and secrets are redacted from logs, events, diagnostics, crash reports, and UI state.

A tunnel may become externally healthy only after the local Scintilla readiness probe succeeds. Tunnel, ingress, and worker health are distinct fields so clients can show partial failures accurately.

## 7. Power inhibition

`keep_alive=true` is a daemon setting shared by all clients. Platform implementations may use native APIs or supervised helpers (`caffeinate` on macOS), but helper lifecycle belongs to the daemon. No UI or CLI launches its own loop.

The inhibitor is released on explicit disable, daemon shutdown, explicit Scintilla stop when policy requests it, or failed ownership validation.

## 8. Updates and rollback

Update workflow:

```text
resolve -> download -> verify -> stage -> preflight -> drain -> activate -> ready -> commit
                                                        \-> failure -> rollback
```

Ingress/runtime artifacts are verified before activation. The last-known-good version remains addressable until the new version passes readiness. Daemon updates and Erlang ingress hot updates are separate operations.

Worker updates are generation-based: in-flight work remains pinned to its admitted generation while new work routes to the newly activated generation after verification.

## 9. Client behavior

All clients converge on daemon-observed state:

- `scintilla-cli`
- `scintilla-flutter`
- `scintilla-desktop-app.rs`

No client invents its own lifecycle status model or worker inventory. UI toggles issue daemon operations and render the resulting daemon state.

CLI examples targeted by the contract:

```text
scintilla desktop status
scintilla desktop start
scintilla desktop stop
scintilla desktop suspend
scintilla desktop resume
scintilla desktop tunnel status
scintilla desktop tunnel up
scintilla desktop keep-alive on
scintilla desktop workers
scintilla desktop upgrade --check
```

`scintilla dev` should use the daemon-backed local runtime when the daemon is reachable and preserve the current direct/loopback development mode as an explicit fallback for machines without the daemon.

## 10. Worker isolation

Desktop self-hosting is not allowed to silently weaken an endpoint's requested isolation. A definition marked containerized remains containerized unless the user explicitly selects a development-only override that is surfaced in status and diagnostics.

Host workers receive only declared environment/secrets and inherit no ambient credentials by default. Container and host launchers enforce configured wall-clock timeout and cancellation behavior.

## 11. Locks

Single-machine exclusion starts with a local lock/lease owned by the daemon. Cross-machine/distributed coordination must use `oresoftware/ores-locks-and-leases` with the currently approved durable backend; desktop infra does not define another lock protocol.

## 12. Conformance requirements

CI in this repo will ultimately provide fixtures proving:

- daemon/CLI/app protocol version compatibility;
- state-machine transitions;
- stale PID/container identity protection;
- update rollback;
- tunnel token redaction and argv rejection;
- loopback-only origin defaults;
- keep-alive ownership/release;
- containerized-vs-host worker policy preservation;
- timeout/cancellation cleanup;
- ingress remains alive across compatible worker generation updates.
