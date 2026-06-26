# 3D_Data

## Resizing a model (do this — same as the traffic barrel)

To resize a `.glb`, run the repo tool. It reads from `original/` and writes to `processed/`:

```bash
./resize-glb.sh <model.glb> <factor>     # factor > 1 bigger, < 1 smaller
./resize-glb.sh free_traffic_barrier_barrel.glb 1.3   # 30% bigger
./resize-glb.sh street_lamp.glb 0.05                  # 1/20th size
```

This is the **only** approved way to resize. Do exactly this — do not improvise a different method.

**How it works (and why):** `resize-glb.sh` calls `scale-glb.mjs`, a dependency-free Node
script that parses the GLB chunks and multiplies **only the POSITION float values** in the
binary buffer (updating each accessor's min/max). Everything else — node hierarchy,
materials, textures, normals, tangents, UVs, extensions, buffer layout, generator tag — is
written back **byte-for-byte identical**. The model looks exactly the same, just a different
size. Confirm with: JSON diff shows only min/max changed; texture bytes unchanged.

**Do NOT:**
- **Do NOT use a glTF library (`@gltf-transform`, gltf-pipeline, etc.) to resize.** Their save
  re-serializes the whole asset — interleaving vertex attributes and reorganizing buffer
  views — and that structural rewrite makes the ArcGIS app render the model **dark/colorless**
  even though materials and textures are unchanged. The surgical byte edit avoids this.
- **Do NOT `flatten()` / reset node transforms.** Collapsing the Sketchfab/FBX node hierarchy
  changes which transforms ArcGIS applies vs. ignores, breaking orientation/lighting.
- **Do NOT touch the material** (emissive, metallicFactor, etc.) when the task is to resize.
  The goal is "same look, new size." Only change a material if explicitly asked to fix rendering.

## Other gotchas

- **ArcGIS ignores top-level glTF node transforms,** so setting a root-node `scale` has no
  visible effect — that's why resizing must bake into the POSITION values (done by the tool above).
- **`metallic = 1` materials render dark** in viewers without environment reflection/IBL (e.g.
  the street lamp). This is a lighting/material trait, not a texture loss — the base-color
  texture only tints reflections on a full metal. This is independent of size; resizing does
  not change it. To reveal the painted color, lower `metallicFactor`, or drive the emissive
  channel from the base-color texture — but only do this if asked to change appearance.
- **GitHub serves the raw `.glb` through a CDN cache,** so after pushing, a hard refresh (or a
  cache-busting query param) may be needed before the app picks up the updated file. A "still
  looks wrong" report immediately after a push is often just the stale cached file.
