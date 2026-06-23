#!/usr/bin/env bash
#
# ifc2slpk.sh — IFC → I3S Scene Layer Package (.slpk) preprocessing pipeline.
#
# Turns IFC building models into georeferenced I3S Scene Layer Packages that load in
# the ArcGIS Maps SDK for JavaScript as selectable, attribute-rich SceneLayers — i.e.
# click any element and read its BIM properties. 100% open source, no ArcGIS Pro.
#
# Pipeline:
#   IFC --(py3dtilers ifc-tiler, --with_BTH)--> 3D Tiles (b3dm + BIM batch table)
#       --(loaders.gl tile-converter, --slpk --no-draco)--> I3S SLPK
#       --(gzip-normalize)--> processed/<name>.slpk
#
# Usage:
#   ./ifc2slpk.sh                       convert every original/*.ifc at the default location
#   ./ifc2slpk.sh -98.4936 29.426 198   convert all at lon lat [groundZ-meters]
#   ./ifc2slpk.sh original/SimpleWall.ifc   convert a single file (default location)
#
# Notes / hard-won gotchas baked in here:
#   * py3dtilers requires Python < 3.13 and the py3dtiles==9.0.0 API (newer py3dtiles
#     breaks it); we build a pinned venv.
#   * tile-converter's Draco worker is unreliable; --no-draco avoids empty geometry.
#   * tile-converter writes .gz entries *uncompressed*; we re-gzip every .gz entry or
#     ArcGIS / the I3S spec reject them.
#   * Georeference (lon/lat/Z) is baked at conversion time via a UTM offset.
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
ORIG="$ROOT/original"
PROC="$ROOT/processed"
PIPE="$ROOT/.pipeline"          # tool cache — gitignored
VENV="$PIPE/venv"
TCVT="$PIPE/tcvt"

# ---- args: optional "lon lat [z]" and/or a single .ifc path ----------------
LON="-98.4936"; LAT="29.426"; GZ="198"     # default: downtown San Antonio, ground ~198 m
SINGLE=""
nums=()
for a in "$@"; do
  if [[ "$a" == *.ifc ]]; then SINGLE="$a"; else nums+=("$a"); fi
done
[ "${nums[0]:-}" != "" ] && LON="${nums[0]}"
[ "${nums[1]:-}" != "" ] && LAT="${nums[1]}"
[ "${nums[2]:-}" != "" ] && GZ="${nums[2]}"

mkdir -p "$PROC" "$PIPE"

# ---- 1. Python venv with the pinned, mutually-compatible stack -------------
PY="$(command -v python3.11 || command -v python3.12 || true)"
[ -z "$PY" ] && { echo "ERROR: need Python 3.11 or 3.12 (py3dtilers requires <3.13)"; exit 1; }
if [ ! -x "$VENV/bin/ifc-tiler" ]; then
  echo ">> building python venv ($PY) — first run only…"
  "$PY" -m venv "$VENV"
  "$VENV/bin/pip" -q install --upgrade pip
  # py3dtilers pins py3dtiles@gitlab-main, whose current API it is no longer compatible
  # with. Install py3dtilers (+ its deps) first, then force py3dtiles back to the 9.0.0
  # release whose GltfPrimitive API py3dtilers actually expects.
  "$VENV/bin/pip" -q install ifcopenshell "git+https://github.com/VCityTeam/py3dtilers"
  # Swap py3dtiles to the 9.0.0 release (with its own deps, e.g. earcut). A separate
  # resolve avoids the py3dtilers@gitlab-main pin conflict; a benign warning is expected.
  "$VENV/bin/pip" -q install "py3dtiles==9.0.0" || true
fi

# ---- 2. loaders.gl tile-converter (npm) ------------------------------------
if [ ! -d "$TCVT/node_modules/@loaders.gl" ]; then
  echo ">> installing tile-converter — first run only…"
  mkdir -p "$TCVT"
  ( cd "$TCVT" && printf '{"name":"tcvt","private":true}\n' > package.json && npm install --silent @loaders.gl/tile-converter )
  ( cd "$TCVT" && npx tile-converter --install-dependencies >/dev/null 2>&1 || true )
fi

# ---- 3. georeference offset: target lon/lat -> UTM easting/northing --------
read -r EPSG E N <<EOF
$("$VENV/bin/python" - "$LON" "$LAT" <<'PY'
import sys
from pyproj import Transformer
lon, lat = float(sys.argv[1]), float(sys.argv[2])
zone = int((lon + 180) // 6) + 1
epsg = (32600 if lat >= 0 else 32700) + zone
e, n = Transformer.from_crs("EPSG:4326", f"EPSG:{epsg}", always_xy=True).transform(lon, lat)
print(epsg, e, n)
PY
)
EOF
echo ">> georeference: lon=$LON lat=$LAT z=$GZ  (UTM EPSG:$EPSG  E=$E N=$N)"

# ---- convert one IFC -------------------------------------------------------
convert_one() {
  local ifc="$1"
  local name; name="$(basename "${ifc%.ifc}")"
  local work="$PIPE/tmp_$name"
  local tiles="$work/tiles" i3s="$work/i3s"
  rm -rf "$work"; mkdir -p "$tiles"

  echo "[$name] IFC → 3D Tiles…"
  if ! "$VENV/bin/ifc-tiler" --paths "$ifc" --output_dir "$tiles" --with_BTH \
        --crs_in "EPSG:$EPSG" --crs_out EPSG:4978 --offset "$E" "$N" "$GZ" >/dev/null 2>&1; then
    echo "  ✗ ifc-tiler failed for $name"; return 1
  fi

  echo "[$name] 3D Tiles → I3S SLPK…"
  if ! ( cd "$TCVT" && npx tile-converter --input-type 3DTILES \
          --tileset "$tiles/tileset.json" --output "$i3s" --name "$name" \
          --slpk --no-draco --quiet >/dev/null 2>&1 ); then
    echo "  ✗ tile-converter failed for $name"; return 1
  fi

  echo "[$name] gzip-normalize → processed/$name.slpk"
  "$VENV/bin/python" "$ROOT/pipeline/normalize_slpk.py" "$i3s/$name.slpk" "$PROC/$name.slpk" || { echo "  ✗ normalize failed"; return 1; }
  rm -rf "$work"
  echo "  ✓ processed/$name.slpk"
}

# ---- run -------------------------------------------------------------------
if [ -n "$SINGLE" ]; then
  convert_one "$SINGLE"
else
  shopt -s nullglob
  found=0
  for f in "$ORIG"/*.ifc; do
    found=1
    convert_one "$f" || true
  done
  [ "$found" = 0 ] && { echo "No IFC files found in $ORIG"; exit 1; }
fi
echo "Done. SLPKs in: $PROC"
