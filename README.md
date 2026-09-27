# Scintilla Desktop Infra

Single-host infrastructure for self-hosting Scintilla on a trusted developer laptop or desktop.

This repository is intentionally separate from `scintilla-run/scintilla-infra`. Production Kubernetes, multi-host fleet, regional infrastructure, and cluster-wide control-plane concerns stay there.

## Desktop topology

```
Cloudflare edge
      |
 cloudflared
      |
127.0.0.1:8083
      |
one BEAM OS process / VM
      |
Scintilla ingress/router/runtime
      |
native and/or container workers
```

There is no nginx/Caddy/HAProxy in the default desktop path. Cloudflare Tunnel points directly at the loopback BEAM ingress.

"One Erlang process" means one BEAM **OS process**. The BEAM VM still contains normal supervised OTP processes for routing, worker dispatch, scheduling, workflows, and runtime services.

## Desired-state authority

`appliance.json` is the source-of-truth for exact source revisions. `runtime/desktop-manifest.example.json` is the versioned manifest consumed by `scintilla-desktop-daemon` PR #6.

The daemon is the long-running machine authority. `scintilla-cli`, Flutter, and the native Rust desktop application are peer clients of its authenticated loopback API and do not supervise one another.

## Bootstrap

Prerequisites: Git, Python 3, Rust/Cargo, Zed package manager, `cloudflared`, and credentials to read private Scintilla source repositories.

```sh
./scripts/bootstrap.sh
```

The bootstrap pins and builds the desktop daemon and CLI, and materializes the exact BEAM runner source.

The current runner still relies on the larger `remote/.../libs` build context used by production. Desktop promotion is therefore intentionally blocked until a **standalone BEAM shipment** can be built without cloning production infrastructure or the full remote source tree.

Once a standalone ingress release exists:

```sh
python3 scripts/render_runtime_manifest.py \
  --ingress-bin /absolute/path/to/scintilla_ingress \
  --ingress-root /absolute/path/to/release \
  --cloudflared-config "$HOME/.cloudflared/config.yml" \
  --hostname dev.example.com

./scripts/doctor.sh
./scripts/up.sh
```

Set `SCINTILLA_START_TUNNEL=1` to ask the daemon to launch the named tunnel after ingress starts. Stop everything with `./scripts/down.sh`.

## Security and update invariants

- daemon listens only on loopback and every `/v1/*` request requires the local bearer token;
- Cloudflare credentials remain in `cloudflared`'s local credential store;
- HTTP clients cannot submit arbitrary process argv or shell/eval commands;
- ingress/worker commands come from the trusted local runtime manifest;
- update artifacts are SHA-256 checked before manifest-declared OTP hot-update argv runs;
- component source pins are immutable full Git SHAs;
- mutable `:latest` / branch-head activation is forbidden;
- production `scintilla-infra` is not a dependency.

## Promotion gates

This branch is deliberately a **candidate**, not a release. Promotion requires:

1. `scintilla-desktop-daemon` PR #6 green on Linux/macOS/Windows;
2. companion CLI/UI clients green against the same API contract;
3. a self-contained BEAM ingress shipment from `gleam-lambda-runner`;
4. end-to-end proof: bootstrap → daemon → BEAM ingress → Cloudflare Tunnel → request → worker → response → clean shutdown/rollback.
