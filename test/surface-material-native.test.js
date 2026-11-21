import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {tileSurfaceMaterial} from '../src/tile_surface_mesh.js';
import {NativeAreaGeometry} from '../src/area_geometry.js';
import {parse2da} from '../src/area.js';
test('surface material, tile/area wrappers and active Walk lookup match 1,080 native executions',async()=>{
 const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-surface-material-observations.json',import.meta.url)));assert.equal(data.rows.length,1080);
 for(const row of data.rows){
  const c=row.case,mesh={vertices:[[0,0,0],[10,0,1],[10,10,2],[0,10,3]],faces:c.faces,materials:c.materials},
   table=parse2da(`2DA V2.0\nDEFAULT: ${c.default}\n\nWalk\n${Object.entries(c.walk).map(([k,v])=>`${k} ${v}`).join('\n')}\n`),
   geometry=new NativeAreaGeometry({width:c.width,height:c.height},{surfaceTable:async()=>table});
  geometry.tile=async(x,y)=>x>=0&&x<c.width&&y>=0&&y<c.height?{x,y,orientation:c.orientation,mesh}:null;
  const result=c.operation==='surface'?tileSurfaceMaterial(mesh,c.point):c.operation==='area'?await geometry.surfaceMaterial(c.point):await geometry.positionWalkable(c.point);
  assert.equal(result>>>0,row.result,JSON.stringify(c));
 }
});
