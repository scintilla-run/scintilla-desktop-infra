# Scintilla Desktop Infra

Single-host desired-state authority for running Scintilla on a developer- or end-user-owned desktop.

The normal topology is intentionally small:

1. the OS user service manager starts `scintilla-desktop-daemon`;
2. the daemon loads `manifests/local-runtime.json` (or an explicitly configured manifest);
3. the daemon starts exactly one Erlang/OTP ingress/control-plane OS process;
4. the daemon starts host-native and/or container workers declared by the manifest;
5. the daemon owns Cloudflare Tunnel, update/rollback, and keep-awake lifecycle;
6. `scintilla-cli`, `scintilla-desktop-app.rs`, and `scintilla-flutter` request state transitions from the daemon.

Clients do **not** send arbitrary executable command lines. Process launch specifications live in this local infra checkout and are validated before use.

## Control-plane boundaries

The local daemon is the machine authority. Desktop clients use its authenticated loopback API. Mobile Flutter clients are capability agents: they may participate in hosting tasks implemented by the mobile application itself, but they do not gain a remote shell and they do not require exposing the desktop daemon off loopback.

The control-plane contract is described by:

- `manifests/local-runtime.schema.json` — machine desired state;
- `manifests/worker.schema.json` — native/container worker declarations;
- `manifests/control-plane.schema.json` — client/agent capability vocabulary;
- `components.lock.json` — immutable component identity and digest pins.

## Bootstrap

```sh
./scripts/bootstrap.sh
./scripts/doctor.sh
./scripts/install-user-service.sh
```

By default the daemon should be configured with:

```sh
SCINTILLA_DESKTOP_MANIFEST=$PWD/manifests/local-runtime.json
```

Copy `manifests/local-runtime.example.json` to `manifests/local-runtime.json` and replace only local paths/hostnames that are explicitly documented as machine-local. Do not add API tokens, Cloudflare credential contents, daemon bearer tokens, passwords, or private keys.

## Security invariants

- daemon HTTP stays loopback-only by default;
- one grandaddy BEAM process owns local ingress/routing;
- clients request named state transitions, not shell/eval;
- host/container commands come only from the local desired-state manifest;
- Cloudflare credentials remain in cloudflared's local credential store;
- component/update artifacts are digest-pinned;
- worker runtimes are an allow-list;
- mobile hosting is capability-scoped to app-implemented tasks, not process execution;
- production `scintilla-infra` remains a separate authority.

## Local verification

```sh
python3 tests/manifest-contract/check.py
./scripts/doctor.sh
```
