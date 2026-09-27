#!/usr/bin/env python3
import argparse, json
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument("--ingress-bin", required=True)
p.add_argument("--ingress-root", required=True)
p.add_argument("--cloudflared-config", required=True)
p.add_argument("--hostname", default="dev.example.com")
p.add_argument("--out", default="runtime.local.json")
a = p.parse_args()

root = Path(__file__).resolve().parents[1]
doc = json.loads((root / "runtime/desktop-manifest.example.json").read_text())
doc["ingress"]["argv"][0] = str(Path(a.ingress_bin).expanduser().resolve())
doc["ingress"]["working_dir"] = str(Path(a.ingress_root).expanduser().resolve())
doc["tunnel"]["config"] = str(Path(a.cloudflared_config).expanduser().resolve())
doc["tunnel"]["hostname"] = a.hostname
Path(a.out).write_text(json.dumps(doc, indent=2) + "\n")
print(a.out)
