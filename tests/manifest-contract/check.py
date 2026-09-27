#!/usr/bin/env python3
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
example = json.loads((ROOT / "manifests/local-runtime.example.json").read_text())
control = json.loads((ROOT / "manifests/control-plane.example.json").read_text())
lock = json.loads((ROOT / "components.lock.json").read_text())
appliance = json.loads((ROOT / "appliance.json").read_text())
runtime_template = json.loads((ROOT / "runtime/desktop-manifest.example.json").read_text())

errors = []

if example.get("schema") != "scintilla.desktop-runtime/v1":
    errors.append("local runtime schema id must be scintilla.desktop-runtime/v1")
if example.get("runtime_kind") != "scintilla-single-beam":
    errors.append("runtime_kind must be scintilla-single-beam")
if runtime_template.get("schema") != "scintilla.desktop-runtime/v1":
    errors.append("renderable runtime template must use scintilla.desktop-runtime/v1")
if runtime_template.get("runtime_kind") != "scintilla-single-beam":
    errors.append("renderable runtime template must use scintilla-single-beam")
if runtime_template.get("ingress", {}).get("command", {}).get("program") is None:
    errors.append("renderable runtime template must use daemon ingress.command shape")
if appliance.get("host", {}).get("daemon_listen") != "127.0.0.1:8765":
    errors.append("appliance daemon_listen must be 127.0.0.1:8765")
if appliance.get("host", {}).get("public_origin") != "http://127.0.0.1:8091":
    errors.append("appliance public_origin must match ingress 127.0.0.1:8091")

ingress = example.get("ingress", {})
program = ingress.get("command", {}).get("program")
if not isinstance(program, str) or not program.strip():
    errors.append("ingress.command.program must be a non-empty argv program")

ids = set()
valid_id = re.compile(r"^[A-Za-z0-9._-]{1,128}$")
for worker in example.get("workers", []):
    worker_id = worker.get("id", "")
    if not valid_id.fullmatch(worker_id):
        errors.append(f"invalid worker id: {worker_id!r}")
    if worker_id in ids:
        errors.append(f"duplicate worker id: {worker_id!r}")
    ids.add(worker_id)
    if worker.get("mode") not in {"host", "container"}:
        errors.append(f"unsupported worker mode for {worker_id!r}")
    if worker.get("mode") == "host" and not worker.get("command", {}).get("program"):
        errors.append(f"host worker {worker_id!r} requires command.program")
    if worker.get("mode") == "container" and not worker.get("image"):
        errors.append(f"container worker {worker_id!r} requires image")

if control.get("protocol") != "scintilla.local-control/v1":
    errors.append("control-plane protocol must be scintilla.local-control/v1")
kinds = {entry.get("kind") for entry in control.get("clients", [])}
for required in {"cli", "rust_desktop", "flutter_desktop", "flutter_mobile", "infra"}:
    if required not in kinds:
        errors.append(f"control-plane example is missing {required}")

if lock.get("schema") != "scintilla.desktop-components-lock/v1":
    errors.append("components lock schema mismatch")

serialized = json.dumps(example).lower()
for forbidden in ["api_token", "access_token", "private_key", "password"]:
    if forbidden in serialized:
        errors.append(f"example manifest must not contain secret field {forbidden!r}")

if errors:
    for error in errors:
        print(f"FAIL: {error}", file=sys.stderr)
    raise SystemExit(1)

print("PASS: desktop manifest/control-plane contract")
