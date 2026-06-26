# 3D_Data

## Gotchas

- **Scaling a GLB:** The ArcGIS Maps SDK app that loads these models ignores top-level glTF node transforms. Setting a root-node `scale` has no visible effect. To actually resize a model, bake the factor directly into the mesh vertex positions (multiply each POSITION accessor) and reset node scale/translation to identity. See `scripts`-style approach using `@gltf-transform/core`.
- **Always register extensions when re-saving a GLB:** create the `NodeIO` with `.registerExtensions(ALL_EXTENSIONS)` (from `@gltf-transform/extensions`). An unregistered `NodeIO` silently **drops** material extensions like `KHR_materials_specular` on write, which changes how the model renders.
- **Sketchfab/FBX-derived models often bake their real scale into a deep node (e.g. a `*.fbx` node with `scale 0.01`).** Before resetting node transforms, bake the full hierarchy into the vertices (`flatten()` + `clearNodeTransform()`); naively zeroing node transforms can blow the model up ~100x.
- **`metallic = 1` materials render black** in viewers without environment reflection/IBL (e.g. the street lamp). This is a lighting/material trait, not a texture loss — the base-color texture only tints reflections on a full metal. Lower `metallicFactor` to reveal the painted base color.
- GitHub may serve the raw `.glb` through a CDN cache, so a hard refresh (or cache-busting query param) may be needed to pick up an updated file.
