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

`appliance.json` pins exact candidate source revisions. An open-PR source pin is reproducible input for review, **not** promotion evidence. Promotion gates stay false until the pinned heads have executable CI evidence, the Rust daemon/native desktop lockfiles are committed, and the BEAM runner has a supported standalone desktop shipment/entrypoint.

## Developer bootstrap

Build the pinned daemon/CLI candidates first:

```sh
./scripts/bootstrap.sh
```

Provision a real hostname through a named Cloudflare Tunnel. Account login, tunnel creation, and DNS routing happen here once; normal daemon restarts only run the already-provisioned tunnel:

```sh
./scripts/provision-cloudflare-tunnel.sh \
  scintilla-local \
  dev.example.com
```

On Windows use:

```powershell
./scripts/provision-cloudflare-tunnel.ps1 `
  -TunnelName scintilla-local `
  -Hostname dev.example.com
```

Then render machine-local desired state and start the appliance:

```sh
python3 scripts/render_runtime_manifest.py \
  --ingress-bin /absolute/path/to/scintilla-ingress \
  --ingress-root /absolute/path/to/runtime \
  --cloudflared-config .desktop/cloudflare/config.yml \
  --hostname dev.example.com
./scripts/doctor.sh
./scripts/up.sh
./scripts/status.sh
```

See `docs/cloudflare-tunnel.md` for the provisioning/runtime trust boundary. Cloudflare credential contents remain in Cloudflare's local credential store; Git and the Scintilla client/daemon API only carry non-secret identity/config paths.

Exact source revisions are pinned in `appliance.json`; mutable `latest` is not an update mechanism.

## Persistent daemon

After bootstrap and rendering `runtime.local.json`, install the daemon under the per-user OS service manager:

```sh
./scripts/install-service.sh
./scripts/status.sh
```

Linux uses a hardened systemd user unit, macOS uses a LaunchAgent, and Windows uses a logon Scheduled Task via `services/windows/install.ps1`. The service receives the same runtime directory and exact runtime manifest as the foreground lifecycle scripts. Uninstalling the service preserves appliance state.

The GUI is never the process owner. Closing the Flutter/Rust desktop UI must not tear down the local ingress, worker pools, Cloudflare Tunnel, or a requested lock-screen sleep inhibitor.
