// Sample installed head UVs in memory; never extract game textures.
import assert from 'node:assert/strict';
import { openLocalModule } from './local-module.mjs';
import { RESOURCE_TYPE } from '../src/resource_archive.js';
import { parseModel } from '../src/model_parser.js';
import { decodeBioWarePlt, PLT_PALETTE_NAMES } from '../src/bioware_plt.js';

const [install, modulePath] = process.argv.slice(2);
if (!install || !modulePath) throw new Error('Usage: node scripts/smoke-plt.mjs <install> <module>');
const resolver = await openLocalModule(install, modulePath);
// Encode layer IDs as colors to test orientation independently of tint choices.
const palettes = new Map(PLT_PALETTE_NAMES.map((name, layer) => {
  const data = new Uint8Array(256 * 4);
  for (let x = 0; x < 256; x++) data.set([layer, 0, 0, 255], x * 4);
  return [name, { width: 256, height: 1, data }];
}));
const model = parseModel(await resolver.getResource('pme0_head001', RESOURCE_TYPE.MDL));
const texture = decodeBioWarePlt(await resolver.getResource('pme0_head001', RESOURCE_TYPE.PLT), palettes);
const heights = [[], []];
for (const node of model.nodes.filter(n => n.type === 'trimesh')) {
  for (const face of node.faces) for (let corner = 0; corner < 3; corner++) {
    const uv = node.tverts[face[4 + corner]], vertex = node.verts[face[corner]];
    const x = Math.max(0, Math.min(texture.width - 1, Math.floor(uv[0] * texture.width)));
    const y = Math.max(0, Math.min(texture.height - 1, Math.floor((texture.flipY ? 1 - uv[1] : uv[1]) * texture.height)));
    const layer = texture.data[(y * texture.width + x) * 4];
    if (heights[layer]) heights[layer].push(vertex[2]);
  }
}
assert.ok(heights.every(h => h.length > 0), 'Head must contain skin and hair samples');
const [skin, hair] = heights.map(h => h.reduce((sum, z) => sum + z, 0) / h.length);
assert.ok(hair > skin + 0.04, 'Head texture reversed: hair maps below the face');
console.log(JSON.stringify({ model: model.modelName, flipY: texture.flipY, skinMeanZ: skin, hairMeanZ: hair }));
