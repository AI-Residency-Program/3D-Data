#!/usr/bin/env bash
#
# ifc2glb.sh — convert IFC building models to glTF binary (.glb).
#
# The .glb files are placed directly as 3D objects in the digital twin (same path as the
# prop models like the stop sign / traffic barrel — an ObjectSymbol3DLayer at a clicked
# point, with free move + rotation). No scene-layer packaging.
#
# Uses IfcConvert (IfcOpenShell) — a single prebuilt binary that reads IFC2x3 and IFC4
# and writes glTF. Geometry is centred at the origin so the model sits on the clicked
# point.
#
# Usage:
#   ./ifc2glb.sh                       convert every original/*.ifc → processed/<name>.glb
#   ./ifc2glb.sh original/SimpleWall.ifc   convert a single file
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
ORIG="$ROOT/original"
PROC="$ROOT/processed"
PIPE="$ROOT/.pipeline"                 # tool cache — gitignored
IFCCONVERT="$PIPE/IfcConvert"
IFCCONVERT_URL="https://github.com/IfcOpenShell/IfcOpenShell/releases/download/ifcconvert-0.8.5/ifcconvert-0.8.5-linux64.zip"

mkdir -p "$PROC" "$PIPE"

# ---- IfcConvert (prebuilt Linux64 binary, downloaded once) -----------------
if [ ! -x "$IFCCONVERT" ]; then
  echo ">> downloading IfcConvert — first run only…"
  curl -sL -o "$PIPE/ifcconvert.zip" "$IFCCONVERT_URL"
  unzip -o "$PIPE/ifcconvert.zip" -d "$PIPE" >/dev/null
  chmod +x "$IFCCONVERT"
fi

convert_one() {
  local ifc="$1"
  local name; name="$(basename "${ifc%.ifc}")"
  echo "[$name] IFC → glb…"
  if "$IFCCONVERT" -y --center-model-geometry "$ifc" "$PROC/$name.glb" >/dev/null 2>&1; then
    echo "  ✓ processed/$name.glb"
  else
    echo "  ✗ failed: $name"
    return 1
  fi
}

if [ $# -ge 1 ] && [ -f "$1" ]; then
  convert_one "$1"
else
  shopt -s nullglob
  found=0
  for f in "$ORIG"/*.ifc; do
    found=1
    convert_one "$f" || true
  done
  [ "$found" = 0 ] && { echo "No IFC files found in $ORIG"; exit 1; }
fi
echo "Done. GLBs in: $PROC"
