# Scintilla Desktop Infra

Single-host Scintilla appliance for developer-owned laptops and desktops.

This repo is intentionally separate from `scintilla-run/scintilla-infra`, which remains the production infrastructure authority.

## Topology

```text
Cloudflare edge -> cloudflared -> loopback BEAM ingress/control VM
                                      -> route/deployment supervisor
                                      -> native/container worker pools
```

`scintilla-desktop-daemon` is the machine lifecycle authority. `scintilla-cli`, Flutter, and Rust desktop apps are clients of its authenticated loopback API. There is no nginx/Caddy/HAProxy in the default path.

## Current promotion gate

The appliance contract is checked in now, but the current `scintilla-desktop-daemon` repository still contains only the API/security contract and not the executable daemon. The manifest therefore marks the appliance `ready = false`; bootstrap fails closed unless `SCINTILLA_ALLOW_INCOMPLETE=1` is explicitly set for development.

## Quick validation

```sh
./scripts/doctor.sh
```
