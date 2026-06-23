# 3D-Data

3D assets for the digital-twin / construction sandbox, plus a pipeline that converts
IFC building models into glTF (`.glb`) for placement as 3D objects.

## Layout

```
original/    source assets — IFC building models (.ifc) and ready-to-place props (.glb)
processed/   generated .glb models, one per IFC
ifc2glb.sh   IFC → glTF (.glb) conversion pipeline
```

## What the pipeline produces

Each `original/*.ifc` becomes `processed/<name>.glb`. These are placed directly as 3D
objects in the digital twin — the same path as the prop models (stop sign, traffic
barrel): an `ObjectSymbol3DLayer` dropped at a clicked point, with free move and
rotation. Geometry is centred at the origin so the model sits on the chosen point.

The `.glb` files already in `original/` (tree, traffic barrel, stop sign) are finished
props used directly.

## Running the pipeline

Requirements: Linux x86-64 and an internet connection on the first run (to fetch the
IfcConvert binary).

```bash
./ifc2glb.sh                       # convert every original/*.ifc → processed/<name>.glb
./ifc2glb.sh original/SimpleWall.ifc   # convert a single file
```

First run downloads the IfcConvert binary into `.pipeline/` (gitignored); later runs
reuse it.

## How it works

```
IFC  ──IfcConvert (IfcOpenShell)──▶  processed/<name>.glb
```

[IfcConvert](https://ifcopenshell.org/) is a single prebuilt binary from IfcOpenShell
that reads IFC2x3 and IFC4 and writes glTF binary. `--center-model-geometry` centres the
mesh at the origin for clean placement.
