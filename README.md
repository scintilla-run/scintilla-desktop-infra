# Scintilla Desktop Infra

Single-host Scintilla appliance and desired-state authority for developer- and end-user-owned laptops/desktops. This repository stays separate from `scintilla-run/scintilla-infra`, which remains the production infrastructure authority.

## Topology

```text
Cloudflare edge -> cloudflared -> 127.0.0.1:8091 -> one BEAM ingress/control OS process
                                                -> supervised routing/control processes
                                                -> native/container worker pools

CLI / Rust desktop / Flutter desktop
             |
             v
authenticated 127.0.0.1:8765
             |
scintilla-desktop-daemon
             |
runtime.local.json desired state
```

`scintilla-desktop-daemon` is the machine lifecycle authority. The CLI, Flutter desktop app, and Rust desktop app are clients of its authenticated loopback API. This repo owns the pinned appliance inputs and the local desired-state manifest; clients request named transitions rather than supplying arbitrary executable commands.

The shared desktop protocol is `scintilla.local-control/v1`. Android/iOS uses a separate outbound hosting-agent contract and never connects to this loopback daemon.

## Current state

The candidate appliance pins exact component revisions in `appliance.json`. Its runtime manifest is `scintilla.desktop-runtime/v1` with `runtime_kind: scintilla-single-beam`. The daemon supervises ingress, declared host/container workers, Cloudflare Tunnel, digest-checked updates, and keep-awake policy.

Promotion remains gated on green component CI and a supported standalone BEAM shipment/entrypoint. Until those gates are satisfied this is a candidate appliance, not a promoted release.

## Developer bootstrap

```sh
./scripts/bootstrap.sh
python3 scripts/render_runtime_manifest.py \
  --ingress-bin /absolute/path/to/scintilla-ingress \
  --ingress-root /absolute/path/to/runtime \
  --cloudflared-credentials /absolute/path/to/.cloudflared/TUNNEL-ID.json
./scripts/doctor.sh
./scripts/up.sh
```

The generated `runtime.local.json` is ignored by git. Do not add API tokens, Cloudflare credential contents, daemon bearer tokens, passwords, or private keys to appliance or runtime manifests.

Normal local control is then:

```sh
scintilla daemon-capabilities
scintilla daemon-reconcile
scintilla daemon-status
scintilla daemon-tunnel-start
scintilla daemon-runtime-stop
```

## Contract sources

- `appliance.json` pins exact component/client revisions and promotion gates.
- `runtime/desktop-manifest.example.json` is the renderable appliance runtime template.
- `manifests/local-runtime.schema.json` defines the versioned daemon desired-state contract.
- `manifests/worker.schema.json` defines host/container workers.
- `manifests/control-plane.schema.json` defines CLI/Rust/Flutter/infra capabilities.
- `components.lock.json` reserves immutable component/artifact digest identity.
- `tests/manifest-contract/check.py` enforces the cross-file control-plane invariants.

## Security invariants

- daemon HTTP is loopback-only by default on `127.0.0.1:8765`;
- one BEAM ingress/control OS process owns local ingress/routing;
- process commands come from desired state, not normal client requests;
- Cloudflare credential contents stay in cloudflared's local credential store;
- updates are exact-revision/digest based; mutable `latest` is not an update mechanism;
- worker runtimes/capabilities are allowlisted;
- mobile hosting is typed/capability-scoped and is not a remote shell into the desktop daemon;
- production `scintilla-infra` remains a separate authority.

## Verification

```sh
python3 scripts/validate_manifest.py
python3 tests/manifest-contract/check.py
./scripts/doctor.sh
```
