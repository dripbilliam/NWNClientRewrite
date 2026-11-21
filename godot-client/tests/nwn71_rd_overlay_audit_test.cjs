'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const root=path.resolve(__dirname,'..');
const before=path.join(root,'.cache/native-tracy/engine-msvc-a/source');
const after=path.join(root,'.cache/nwn71/rd-inner-proposal-b/after');
const receipt=JSON.parse(fs.readFileSync(path.join(root,'.cache/nwn71/rd-inner-proposal-b/receipt.json'),'utf8'));
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const names=[];
for(const record of receipt.files){
  const original=fs.readFileSync(path.join(before,record.relative));
  const proposed=fs.readFileSync(path.join(after,record.relative));
  assert.equal(sha(original),record.sourceSha256,`${record.relative} source pin`);
  assert.equal(sha(proposed),record.proposalSha256,`${record.relative} proposal pin`);
  const content=proposed.toString('utf8');
  const zones=[...content.matchAll(/ZoneNamedN\([^,]+, "(NWN71\/RD\/[^"]+)", true\);/g)].map(m=>m[1]);
  names.push(...zones);
  const stripped=content.replace(/#if defined\(GODOT_USE_TRACY\)\r?\n\s*ZoneNamedN\([^,]+, "NWN71\/RD\/[^"]+", true\);\r?\n#endif\r?\n/g,'')
    .replace('#include "core/profiling/profiling.h"\n','');
  assert.ok(stripped===original.toString('utf8'),`${record.relative} non-zone source`);
}
assert.equal(names.length,10);
assert.equal(new Set(names).size,10);
assert.deepEqual(names.slice().sort(),[
  'NWN71/RD/compositor_effects','NWN71/RD/dirty_pipelines','NWN71/RD/draw_list',
  'NWN71/RD/environment','NWN71/RD/fill_render_list','NWN71/RD/lightmaps',
  'NWN71/RD/pre_opaque','NWN71/RD/render_scene','NWN71/RD/scene_body','NWN71/RD/tonemap_post'
].sort());
console.log('nwn71 RD overlay audit: source pins, ten distinct Tracy-only zones, original behavior bytes passed');
