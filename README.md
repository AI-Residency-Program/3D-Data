# 3D-Data

3D assets for the digital-twin / construction sandbox, plus an open-source pipeline
that converts IFC building models into selectable, attribute-rich BIM scene layers.

## Layout

```
original/    source assets — IFC building models (.ifc) and ready-to-place props (.glb)
processed/   generated I3S Scene Layer Packages (.slpk) — one per IFC
ifc2slpk.sh  IFC → I3S SLPK preprocessing pipeline
pipeline/    helper scripts used by the pipeline
```

## What the pipeline produces

Each `original/*.ifc` becomes `processed/<name>.slpk`: a georeferenced I3S Scene Layer
Package that loads in the ArcGIS Maps SDK for JavaScript as a `SceneLayer`. Every
building element is individually selectable and carries its full IFC property set
(type/`classe`, GUID, name, and the complete `IfcPropertySet` data) — so clicking an
element shows its attribute table.

The `.glb` files in `original/` are finished props (tree, traffic barrel, stop sign)
placed directly as `ObjectSymbol3DLayer` objects; they don't need processing.

## Running the pipeline

Requirements: Python 3.11/3.12 (py3dtilers requires < 3.13), Node.js, and an internet
connection for the first-run dependency install.

```bash
./ifc2slpk.sh                          # convert every original/*.ifc at the default location
./ifc2slpk.sh -98.4936 29.426 198      # convert all at a given lon lat [groundZ-meters]
./ifc2slpk.sh original/SimpleWall.ifc  # convert a single file
```

First run builds a pinned Python venv and installs `tile-converter` under `.pipeline/`
(gitignored); later runs reuse them.

## How it works

```
IFC  ──ifc-tiler (py3dtilers, --with_BTH)──▶  3D Tiles  (b3dm + BIM batch table)
     ──tile-converter (loaders.gl, --slpk --no-draco)──▶  I3S SLPK
     ──gzip-normalize──▶  processed/<name>.slpk
```

- **py3dtilers `ifc-tiler`** reads the IFC with IfcOpenShell and emits 3D Tiles,
  embedding each element's IFC attributes in the batch table (`--with_BTH`).
- **loaders.gl `tile-converter`** converts those 3D Tiles to an I3S Scene Layer
  Package, mapping the batch-table attributes onto I3S feature fields.
- **`pipeline/normalize_slpk.py`** re-gzips the package's `.gz` resources, which
  tile-converter writes uncompressed, so the result is spec-compliant.

Georeference (longitude / latitude / ground elevation) is baked at conversion time
as a UTM offset; re-run with different coordinates to relocate a model.

## Toolchain

- [py3dtilers](https://github.com/VCityTeam/py3dtilers) / [py3dtiles](https://gitlab.com/py3dtiles/py3dtiles) — IFC → 3D Tiles
- [IfcOpenShell](https://ifcopenshell.org/) — IFC geometry + property engine
- [loaders.gl tile-converter](https://loaders.gl/docs/modules/tile-converter) — 3D Tiles ↔ I3S
