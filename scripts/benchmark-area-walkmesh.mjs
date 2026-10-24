// Read-only installed area benchmark; outputs hashes/counts, never game assets.
import fs from 'node:fs/promises';import assert from 'node:assert/strict';import {createHash} from 'node:crypto';
import {openLocalModule} from './local-module.mjs';import {loadAreaWalkmesh,parse2da,parseTileset} from '../src/area.js';import {decodeResourceText,RESOURCE_TYPE} from '../src/resource_archive.js';import {parseGff} from '../src/gff.js';import {parseTileSurfaceMesh,rotateTilePoint} from '../src/tile_surface_mesh.js';import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const source=await fs.readFile(new URL('../backups/animations/creation-performance-baseline-area-v15.js',import.meta.url),'utf8'),body=source.slice(source.indexOf('export async function loadAreaWalkmesh'),source.indexOf('export async function parseAreaModule')).replace('export ','');
const baseline=Function('parse2da','decodeResourceText','RESOURCE_TYPE','parseTileSurfaceMesh','rotateTilePoint','runtimeDiagnostics',body+';return loadAreaWalkmesh;')(parse2da,decodeResourceText,RESOURCE_TYPE,parseTileSurfaceMesh,rotateTilePoint,runtimeDiagnostics);
const install=process.argv[2],output=process.argv[3],resolver=await openLocalModule(install,install+'/data/nwm/Prelude.nwm'),report={scope:'Installed Prelude WOK preparation, identical physical/camera geometry',areas:[]};
for(const resRef of ['m0q1a','m0q1b','m0q1d']){
 const raw=parseGff(await resolver.getResource(resRef,RESOURCE_TYPE.ARE),'ARE ').root,set=parseTileset(decodeResourceText(await resolver.getResource(raw.Tileset,RESOURCE_TYPE.SET))),area={resRef,width:raw.Width,tileHeight:set.transition,tiles:raw.Tile_List.map(t=>({model:set.tiles[t.Tile_ID].model,orientation:t.Tile_Orientation,height:t.Tile_Height}))};
 const row={resRef,tiles:area.tiles.length,uniqueModels:new Set(area.tiles.map(t=>t.model.toLowerCase())).size,runs:[]};
 for(const mode of ['baseline','current','current','baseline']){
  let reads=0;const start=performance.now(),result=await(mode==='baseline'?baseline:loadAreaWalkmesh)(area,{getResource:(name,type)=>{if(type===RESOURCE_TYPE.WOK)reads++;return resolver.getResource(name,type);}}),hash=createHash('sha256').update(JSON.stringify(result)).digest('hex');assert.deepEqual(result.missing,[]);
  row.runs.push({mode,ms:performance.now()-start,reads,triangles:result.triangles.length,cameraTriangles:result.cameraTriangles.length,hash});
 }
 assert.equal(new Set(row.runs.map(r=>r.hash)).size,1);for(const run of row.runs)assert.equal(run.reads,run.mode==='baseline'?row.tiles:row.uniqueModels);report.areas.push(row);
}
await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));
