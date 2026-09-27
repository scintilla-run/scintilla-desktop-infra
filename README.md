# Scintilla Desktop Infra

Single-host Scintilla appliance for developer-owned laptops and desktops. This repository is intentionally separate from `scintilla-run/scintilla-infra`, which remains the production infrastructure authority.

## Topology

```text
Cloudflare edge -> cloudflared -> 127.0.0.1:8083 -> one BEAM ingress/control OS process
                                                -> supervised routing/control processes
                                                -> native/container worker pools
```

`scintilla-desktop-daemon` is the machine lifecycle authority. CLI, Flutter, and Rust desktop apps are peer clients of its authenticated loopback API. No nginx/Caddy/HAProxy layer is required by default.

## Current state

A real candidate desktop daemon exists and consumes a local `scintilla-single-beam` runtime manifest. It supervises ingress, named host/container workers, Cloudflare Tunnel, digest-checked updates, and keep-awake policy.

The remaining promotion gates are explicit in `appliance.json`: candidate daemon/CLI CI must be green and the BEAM runner must have a supported standalone desktop shipment/entrypoint. Until then this repo is a candidate appliance, not a promoted release.

## Developer bootstrap

```sh
./scripts/bootstrap.sh
python3 scripts/render_runtime_manifest.py \
  --ingress-bin /absolute/path/to/scintilla-ingress \
  --ingress-root /absolute/path/to/runtime \
  --cloudflared-config /absolute/path/to/cloudflared.yml
./scripts/doctor.sh
./scripts/up.sh
./scripts/status.sh
```

Exact source revisions are pinned in `appliance.json`; mutable `latest` is not an update mechanism.

## Persistent daemon

After bootstrap and rendering `runtime.local.json`, install the daemon under the per-user OS service manager:

```sh
./scripts/install-service.sh
./scripts/status.sh
```

Linux uses a hardened systemd user unit, macOS uses a LaunchAgent, and Windows uses a logon Scheduled Task via `services/windows/install.ps1`. The service receives the same runtime directory and exact runtime manifest as the foreground lifecycle scripts. Uninstalling the service preserves appliance state.

The GUI is never the process owner. Closing the Flutter/Rust desktop UI must not tear down the local ingress or worker pools.
