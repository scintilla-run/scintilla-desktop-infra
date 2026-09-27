# Cloudflare Tunnel for a local Scintilla host

The desktop appliance uses a **named Cloudflare Tunnel** to expose the loopback Scintilla ingress without opening a listening port on the router or binding the daemon to the LAN.

## Trust boundary

There are two deliberately separate phases:

1. **Provisioning** — account-authenticated operations such as `tunnel login`, `tunnel create`, and `tunnel route dns`. These are owned by `scintilla-desktop-infra` bootstrap tooling and should run only when the operator creates/changes the tunnel or hostname.
2. **Runtime** — starting/stopping the already-provisioned tunnel with `cloudflared tunnel --config <path> run <name>`. This is owned by `scintilla-desktop-daemon` and may happen repeatedly during normal restart/reconcile without requiring account-level DNS mutation.

Cloudflare credential **contents** never enter the desktop daemon API, CLI arguments, Flutter/Rust UI state, Git, or logs. The generated runtime config contains only the tunnel UUID and the local path to Cloudflare's credential JSON.

## macOS / Linux provisioning

```sh
./scripts/provision-cloudflare-tunnel.sh \
  scintilla-local \
  dev.example.com
```

The command:

- runs `cloudflared tunnel login`;
- reuses the named tunnel if it already exists, otherwise creates it;
- resolves its UUID;
- routes `dev.example.com` to that named tunnel;
- writes `.desktop/cloudflare/config.yml` by default;
- verifies the credential file exists without reading or copying its contents.

To use a credential file outside the default Cloudflare directory, set `SCINTILLA_CLOUDFLARED_CREDENTIALS_FILE` to its local path before provisioning.

## Windows provisioning

```powershell
./scripts/provision-cloudflare-tunnel.ps1 `
  -TunnelName scintilla-local `
  -Hostname dev.example.com
```

The PowerShell flow has the same boundary and writes `.desktop\cloudflare\config.yml` by default.

## Generated config shape

The local config is equivalent to:

```yaml
tunnel: <uuid>
credentials-file: /local/path/.cloudflared/<uuid>.json

ingress:
  - hostname: dev.example.com
    service: http://127.0.0.1:8083
  - service: http_status:404
```

The terminal `http_status:404` ingress rule is required so unexpected hostnames do not fall through to an implicit origin.

## Render the desktop runtime manifest

After provisioning the tunnel and installing a standalone Scintilla ingress/BEAM shipment:

```sh
python3 scripts/render_runtime_manifest.py \
  --ingress-bin /absolute/path/to/scintilla-ingress \
  --ingress-root /absolute/path/to/runtime \
  --cloudflared-config .desktop/cloudflare/config.yml \
  --hostname dev.example.com \
  --out runtime.local.json
```

`runtime.local.json` is local desired state consumed by `scintilla-desktop-daemon`. It should not be committed when it contains machine-specific paths or hostnames.

## Normal runtime behavior

Once provisioned, normal daemon tunnel lifecycle should **not** run `cloudflared tunnel route dns` again. It should only supervise the equivalent of:

```sh
cloudflared tunnel --config .desktop/cloudflare/config.yml run scintilla-local
```

That keeps restart/recovery independent from Cloudflare account-level provisioning and lets the daemon operate with the minimum local credential scope needed by `cloudflared` itself.
