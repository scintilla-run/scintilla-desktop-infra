# Scintilla Desktop Infra

Single-host Scintilla appliance and desired-state authority for developer- and end-user-owned laptops/desktops. This repository remains separate from `scintilla-run/scintilla-infra`, which is the production infrastructure authority.

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

No nginx/Caddy/HAProxy layer is required by default. The daemon is the single local process authority; normal clients request named transitions and do not supply arbitrary executable commands. Android/iOS hosting uses a separate outbound agent contract rather than exposing this loopback daemon.

## Bootstrap

```sh
./scripts/bootstrap.sh
python3 scripts/render_runtime_manifest.py \
  --ingress-bin /absolute/path/to/scintilla-ingress \
  --ingress-root /absolute/path/to/runtime \
  --cloudflared-credentials /absolute/path/to/.cloudflared/TUNNEL-ID.json
./scripts/doctor.sh
./scripts/up.sh
./scripts/status.sh
```

`appliance.json` pins exact component revisions. Bootstrap also installs separate flags-2-env contracts for the public CLI and desktop daemon, so both binaries can run from the same appliance bin directory without configuration collision.

## Persistent daemon

```sh
./scripts/install-service.sh
./scripts/status.sh
```

Linux uses a hardened systemd user unit, macOS uses the `run.scintilla.desktop-daemon` LaunchAgent, and Windows uses a logon Scheduled Task. All modes carry the same `SCINTILLA_DAEMON_DATA_DIR`, daemon flags contract, and exact runtime manifest. Uninstall preserves appliance state.

## Contracts and security

- local protocol: `scintilla.local-control/v1`;
- daemon HTTP: loopback-only at `127.0.0.1:8765`;
- BEAM ingress: loopback-only at `127.0.0.1:8091`;
- runtime/worker schemas live under `manifests/`;
- Cloudflare credential contents stay in cloudflared's local credential store;
- updates are exact-revision/digest based; mutable `latest` is forbidden;
- worker runtimes/capabilities are allowlisted;
- remote shell and arbitrary client commands are disabled.

The candidate channel remains promotion-gated until component CI and the standalone BEAM shipment are ready.


## ORES Compose local deployment

The standardized desktop lifecycle is now declared in `.ores-compose.yaml`:

```sh
ores-compose check .ores-compose.yaml
ores-compose plan .ores-compose.yaml
ores-compose up .ores-compose.yaml
```

Where this product supports inbound public hosting, `.ores-compose.public.yaml` adds a remotely managed `cloudflared` connector using an OS-protected token file. A public/static/dedicated IP is not required. See [docs/local-deployment.md](docs/local-deployment.md).
