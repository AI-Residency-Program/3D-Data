// scale-glb.mjs — uniformly resize a .glb by scaling ONLY the mesh vertex
// positions. Everything that determines appearance (materials, textures,
// normals, tangents, UVs, node hierarchy, winding) is left byte-identical,
// so the model renders exactly the same — just a different size.
//
// Why scale vertices instead of a node transform: the ArcGIS Maps SDK that
// loads these models ignores the root node transform, so a node `scale` has
// no visible effect (see CLAUDE.md). Baking the factor into POSITION is the
// only resize that actually shows up. We deliberately do NOT flatten/reset
// the node hierarchy — that changes which transforms ArcGIS applies vs.
// ignores and alters orientation/lighting.
//
// Usage: node scale-glb.mjs <in.glb> <out.glb> <factor>
import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';

const [, , inPath, outPath, factorArg] = process.argv;
const factor = parseFloat(factorArg);
if (!inPath || !outPath || !Number.isFinite(factor) || factor <= 0) {
  console.error('Usage: node scale-glb.mjs <in.glb> <out.glb> <factor>');
  process.exit(1);
}

// registerExtensions(ALL_EXTENSIONS) is required, or an unregistered NodeIO
// silently drops material extensions (e.g. KHR_materials_specular) on write.
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);
const doc = await io.read(inPath);

const seen = new Set();
for (const mesh of doc.getRoot().listMeshes())
  for (const prim of mesh.listPrimitives()) {
    const pos = prim.getAttribute('POSITION');
    if (!pos || seen.has(pos)) continue; // accessors can be shared between prims
    seen.add(pos);
    const arr = pos.getArray().slice();
    for (let i = 0; i < arr.length; i++) arr[i] *= factor;
    pos.setArray(arr); // accessor min/max are recomputed automatically on write
  }

await io.write(outPath, doc);
console.log(`Scaled ${seen.size} POSITION accessor(s) by ${factor}x -> ${outPath}`);
