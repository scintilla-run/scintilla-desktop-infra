# Windows user service

Install `scintilla-desktop-daemon.exe` as a per-user or least-privilege Windows service using the deployment mechanism chosen by the installer.

Required environment:

```text
SCINTILLA_DESKTOP_MANIFEST=C:\path\to\scintilla-desktop-infra\manifests\local-runtime.json
```

The daemon remains bound to loopback by default. Do not create a firewall exception for its HTTP port. Mobile agents use the remote Scintilla control plane and do not connect to this service.
