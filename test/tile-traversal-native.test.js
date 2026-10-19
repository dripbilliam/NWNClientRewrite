import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {syntheticMesh} from '../scripts/tile-traversal-cases.mjs';
import {clippedTileSurfaceLine} from '../src/tile_surface_mesh.js';
import {NativeAreaGeometry} from '../src/area_geometry.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-tile-traversal-observations.json',import.meta.url))),bits=v=>new Uint32Array(new Float32Array([v]).buffer)[0];
test('tile traversal matches original status, exact clip/height float bits and limit behavior on synthetic cases',()=>{
 assert.equal(data.rows.length,371);let tested=0;
 for(const row of data.rows.filter(r=>r.case.mesh===0)){const c=row.case,warnings=[],r=clippedTileSurfaceLine(syntheticMesh(),...c.tile,c.from,c.to,m=>warnings.push(m));assert.equal(r.status,row.result,JSON.stringify(c));assert.equal(warnings.length,Number(row.limited));
  const values=[...(r.entry??[null,null]),...(r.exit??[null,null]),r.minHeight,r.maxHeight];for(let i=0;i<values.length;i++)if(values[i]!==null)assert.equal(bits(values[i]),row.bits[i],JSON.stringify({c,i}));tested++;
 }assert.equal(tested,209);
});
test('native 512-step blocked query stays blocked and retains detailed warning without becoming a fatal session error',()=>{
 const mesh=syntheticMesh();mesh.adjacency[0][2]=0;const before=runtimeDiagnostics.records.length,area={resRef:'synthetic'},geometry=new NativeAreaGeometry(area,{report:()=>assert.fail('Expected native query rejection is not a session exception')}),tile={x:0,y:0,orientation:0,heightOffset:0,model:'synthetic',mesh};
 const from=[8,2],to=[2,8],result=geometry.providers().clippedWalkable(tile,from,to),records=runtimeDiagnostics.records.slice(before);assert.equal(result.status,0);assert.equal(records.length,1);assert.equal(records[0].code,'geometry.tile-traversal-limit');assert.equal(records[0].severity,'warning');assert.deepEqual(records[0].context.from,from);assert.deepEqual(records[0].context.to,to);assert.equal(records[0].context.tileX,0);
});
