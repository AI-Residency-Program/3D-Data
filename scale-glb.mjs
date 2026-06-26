// scale-glb.mjs — uniformly resize a .glb by scaling ONLY the mesh vertex
// positions, editing the binary buffer in place.
//
// This does NOT use a glTF library to re-serialize the file. Libraries like
// gltf-transform rebuild the whole asset (interleaving vertex attributes,
// reorganizing buffer views, rewriting the JSON) — and that structural rewrite
// makes the ArcGIS Maps SDK render the model wrong (dark / no color), even
// though the materials and textures are unchanged.
//
// Instead we parse the GLB chunks ourselves, multiply the float values of each
// POSITION accessor by the factor, update that accessor's min/max, and write
// everything else back untouched. The result differs from the original ONLY in
// the position numbers — node hierarchy, materials, textures, normals,
// tangents, UVs, extensions and buffer layout are all preserved exactly. The
// model looks identical, just a different size.
//
// Why scale vertices instead of a node transform: the ArcGIS Maps SDK ignores
// the root node transform, so a node `scale` has no visible effect (CLAUDE.md).
//
// Usage: node scale-glb.mjs <in.glb> <out.glb> <factor>
import { readFileSync, writeFileSync } from 'node:fs';

const [, , inPath, outPath, factorArg] = process.argv;
const factor = parseFloat(factorArg);
if (!inPath || !outPath || !Number.isFinite(factor) || factor <= 0) {
  console.error('Usage: node scale-glb.mjs <in.glb> <out.glb> <factor>');
  process.exit(1);
}

const GLB_MAGIC = 0x46546c67; // 'glTF'
const JSON_TYPE = 0x4e4f534a; // 'JSON'
const BIN_TYPE = 0x004e4942;  // 'BIN\0'
const FLOAT = 5126;

const buf = readFileSync(inPath);
if (buf.readUInt32LE(0) !== GLB_MAGIC) throw new Error('not a GLB file');

// --- parse chunks ----------------------------------------------------------
let json, bin, off = 12;
while (off < buf.length) {
  const len = buf.readUInt32LE(off);
  const type = buf.readUInt32LE(off + 4);
  const data = buf.subarray(off + 8, off + 8 + len);
  if (type === JSON_TYPE) json = JSON.parse(data.toString('utf8'));
  else if (type === BIN_TYPE) bin = Buffer.from(data); // mutable copy
  off += 8 + len;
}
if (!json || !bin) throw new Error('GLB missing JSON or BIN chunk');

// --- scale every unique POSITION accessor in place -------------------------
const posAccessors = new Set();
for (const mesh of json.meshes ?? [])
  for (const prim of mesh.primitives ?? [])
    if (prim.attributes?.POSITION !== undefined) posAccessors.add(prim.attributes.POSITION);

for (const ai of posAccessors) {
  const acc = json.accessors[ai];
  if (acc.componentType !== FLOAT || acc.type !== 'VEC3')
    throw new Error(`POSITION accessor ${ai} is not float VEC3`);
  const bv = json.bufferViews[acc.bufferView];
  const base = (bv.byteOffset ?? 0) + (acc.byteOffset ?? 0);
  const stride = bv.byteStride ?? 12; // 3 floats
  const min = [Infinity, Infinity, Infinity];
  const max = [-Infinity, -Infinity, -Infinity];
  for (let v = 0; v < acc.count; v++) {
    for (let c = 0; c < 3; c++) {
      const p = base + v * stride + c * 4;
      const val = bin.readFloatLE(p) * factor;
      bin.writeFloatLE(val, p);
      if (val < min[c]) min[c] = val;
      if (val > max[c]) max[c] = val;
    }
  }
  acc.min = min;
  acc.max = max;
}

// --- re-serialize GLB (BIN unchanged, JSON only differs in min/max) ---------
const pad = (b, fill) => {
  const r = b.length % 4;
  return r === 0 ? b : Buffer.concat([b, Buffer.alloc(4 - r, fill)]);
};
const jsonChunk = pad(Buffer.from(JSON.stringify(json), 'utf8'), 0x20); // space pad
const binChunk = pad(bin, 0x00);

const total = 12 + 8 + jsonChunk.length + 8 + binChunk.length;
const out = Buffer.alloc(total);
let w = 0;
out.writeUInt32LE(GLB_MAGIC, w); w += 4;
out.writeUInt32LE(2, w); w += 4;            // version
out.writeUInt32LE(total, w); w += 4;        // total length
out.writeUInt32LE(jsonChunk.length, w); w += 4;
out.writeUInt32LE(JSON_TYPE, w); w += 4;
jsonChunk.copy(out, w); w += jsonChunk.length;
out.writeUInt32LE(binChunk.length, w); w += 4;
out.writeUInt32LE(BIN_TYPE, w); w += 4;
binChunk.copy(out, w);

writeFileSync(outPath, out);
console.log(`Scaled ${posAccessors.size} POSITION accessor(s) by ${factor}x (in-place) -> ${outPath}`);
