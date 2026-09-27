#!/usr/bin/env sh
set -eu
root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
manifest="$root/manifests/local-runtime.json"
example="$root/manifests/local-runtime.example.json"
if [ ! -f "$manifest" ]; then
  cp "$example" "$manifest"
  printf '%s\n' "Created $manifest from the example."
  printf '%s\n' "Edit machine-local executable paths before starting Scintilla."
fi
python3 "$root/tests/manifest-contract/check.py"
printf '%s\n' "Desktop infra bootstrap contract is valid."
