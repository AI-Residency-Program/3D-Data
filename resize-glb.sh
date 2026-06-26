#!/usr/bin/env bash
#
# resize-glb.sh — uniformly resize a .glb model by a scale factor.
#
# Reads from original/ and writes the resized model to processed/. Only the
# mesh vertex positions are scaled; materials, textures, normals, UVs and the
# node hierarchy are preserved exactly, so the model looks identical — just a
# different size. (See scale-glb.mjs for why we scale vertices, not a node
# transform: the ArcGIS Maps SDK ignores node transforms.)
#
# Backed by scale-glb.mjs (pure Node, no dependencies): it edits only the
# POSITION bytes in the GLB's binary buffer and leaves the rest of the file
# byte-for-byte identical, so the model looks exactly the same at a new size.
#
# Usage:
#   ./resize-glb.sh free_traffic_barrier_barrel.glb 1.3   # 30% larger
#   ./resize-glb.sh stop_sign.glb 0.5                     # half size
#   ./resize-glb.sh original/street_lamp.glb 2            # explicit path also ok
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
ORIG="$ROOT/original"
PROC="$ROOT/processed"

if [ $# -lt 2 ]; then
  echo "Usage: $(basename "$0") <model.glb> <factor>"
  echo "  e.g. $(basename "$0") free_traffic_barrier_barrel.glb 1.3"
  exit 1
fi

INPUT="$1"
FACTOR="$2"

# Resolve input: accept a bare filename (looked up in original/) or a path.
if [ -f "$INPUT" ]; then
  SRC="$INPUT"
elif [ -f "$ORIG/$INPUT" ]; then
  SRC="$ORIG/$INPUT"
else
  echo "✗ not found: $INPUT (also tried $ORIG/$INPUT)"
  exit 1
fi

NAME="$(basename "$SRC")"
mkdir -p "$PROC"

echo "[$NAME] scaling by ${FACTOR}x…"
node "$ROOT/scale-glb.mjs" "$SRC" "$PROC/$NAME" "$FACTOR"
echo "  ✓ processed/$NAME"
