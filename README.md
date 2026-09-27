# Scintilla Desktop Infra

Single-host infrastructure for running Scintilla on a developer-owned laptop or desktop.

This repository is intentionally separate from `scintilla-run/scintilla-infra`, which remains the production infrastructure authority.

The desktop appliance target is one trusted host with one long-lived BEAM ingress/control VM, local worker processes or containers, an optional Cloudflare Tunnel, and `scintilla-desktop-daemon` as the machine lifecycle authority.

Implementation is developed through pull requests from this bootstrap commit.
