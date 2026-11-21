// Memory-only installed mesh input for the original-code oracle. Never redirect
// this process's stdout to a workspace file; its parent consumes the pipe.
import fs from 'node:fs/promises';import {createHash} from 'node:crypto';import {openLocalModule} from './local-module.mjs';import {NativeGeometryResources} from '../src/area_geometry.js';import {rotateTilePoint,clippedTileSurfaceLine,noDeniedAreaTilePolygons} from '../src/tile_surface_mesh.js';
const bytes=await fs.readFile('backups/animations/creation-performance-exact-collision-replay-v1.json'),report=JSON.parse(bytes),capture=JSON.parse(await fs.readFile('backups/animations/creation-performance-path-acceptance-capture-v2.json')),resolver=await openLocalModule('../FullDecomp/NwnRootInstall','../FullDecomp/NwnRootInstall/data/nwm/Prelude.nwm'),resources=new NativeGeometryResources(resolver,error=>{throw error;}),mesh=await resources.mesh('tic01_e01_01'),tile={x:0,y:0,orientation:3,heightOffset:0,mesh},bits=v=>new Uint32Array(new Float32Array([v]).buffer)[0],cases=[];
for(const row of report.cases){const source=capture.contact.keyboard.previews.find(p=>p.at===row.at).trace.query;
 for(const [index,query]of row.queries.entries()){
  const from=rotateTilePoint(tile,query.from,true),to=rotateTilePoint(tile,query.to,true),clip=clippedTileSurfaceLine(mesh,0,0,from,to);cases.push({kind:'clip',at:row.at,index,tile:[0,0],from,to,expected:clip.status,expectedBits:[...clip.entry,...clip.exit,clip.minHeight,clip.maxHeight].map(bits)});
  const clipped=query.stages.find(s=>s.stage==='clip').result;if(clipped.status!==1)continue;
  const low=Math.fround(clipped.minHeight-Math.fround(.1)),high=Math.fround(clipped.maxHeight+Math.fround(source.height+Math.fround(.1))),start=rotateTilePoint(tile,clipped.entry,true),end=rotateTilePoint(tile,clipped.exit,true),expected=noDeniedAreaTilePolygons(tile,clipped.entry,clipped.exit,low,high,source.radius,0);
  cases.push({kind:'denied',at:row.at,index,from:start,to:end,low,high,radius:source.radius,flag:0,expected});
 }
}
process.stdout.write(JSON.stringify({sourceHash:createHash('sha256').update(bytes).digest('hex'),model:'tic01_e01_01',mesh,meshFloatBits:{vertices:mesh.vertices.map(v=>v.map(bits)),normals:mesh.normals.map(v=>v.map(bits)),constants:mesh.constants.map(bits),deniedVertices:mesh.denied.vertices.map(v=>v.map(bits))},cases}));
