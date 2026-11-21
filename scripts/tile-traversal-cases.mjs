// Original assets are read only and passed to the oracle through an in-memory
// pipe. Reports persist observations and input points, never the installed mesh.
import {pathToFileURL} from 'node:url';
import {openLocalModule} from './local-module.mjs';
import {NativeGeometryResources} from '../src/area_geometry.js';
import {computeTileAdjacency,rotateTilePoint,tileTriangleNormal,clippedTileSurfaceLine} from '../src/tile_surface_mesh.js';
export function syntheticMesh(){
 const vertices=[[0,0,0],[10,0,3],[10,10,3],[0,10,0]],faces=[[0,1,2],[0,2,3]],normals=faces.map(([a,b,c])=>tileTriangleNormal(vertices[a],vertices[b],vertices[c]));
 return{vertices,faces,normals,constants:normals.map((n,i)=>-Math.fround(n.reduce((sum,v,j)=>Math.fround(sum+Math.fround(v*vertices[faces[i][0]][j])),0))),adjacency:computeTileAdjacency(vertices,faces)};
}
export async function traversalCases(install='../FullDecomp/NwnRootInstall',includeInstalled=true){
 const meshes=[syntheticMesh()],cases=[];
 for(const from of [[8,2],[2,8],[5,5],[0,0],[10,10],[-2,5],[12,5]])for(const to of [[2,8],[8,2],[0,10],[10,0],[5,5],[-20,4],[20,4]])cases.push({mesh:0,tile:[0,0],from,to});
 let seed=987531;const random=()=>((seed=(Math.imul(seed,1664525)+1013904223)>>>0)/4294967296);
 for(let n=0;n<160;n++)cases.push({mesh:0,tile:[0,0],from:[random()*14-2,random()*14-2],to:[random()*30-10,random()*30-10]});
 if(includeInstalled){
  const resolver=await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),resources=new NativeGeometryResources(resolver,(error)=>{throw error;});meshes.push(await resources.mesh('tic01_f14_01'));
  const tile={x:5,y:10,orientation:3},from=[60.57569122314453,104.85014343261719];
  for(const to of [[23.887226104736328,88.91413116455078],[51.4035758972168,100.86614227294922]])cases.push({mesh:1,tile:[5,10],from:rotateTilePoint(tile,from,true),to:rotateTilePoint(tile,to,true),world:{from,to,orientation:3}});
  for(let n=0;n<160;n++)cases.push({mesh:1,tile:[0,0],from:[random()*10,random()*10],to:[random()*30-10,random()*30-10]});
 }
 return{meshes,cases};
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){
 const data=await traversalCases(process.argv[2]);
 const bits=v=>new Uint32Array(new Float32Array([v]).buffer)[0];
 // JSON numbers discard signed zero. Preserve the actual mesh and observation
 // float bits across the in-memory transport to the independent native owner.
 data.meshFloatBits=data.meshes.map(m=>({vertices:m.vertices.map(r=>r.map(bits)),normals:m.normals.map(r=>r.map(bits)),constants:m.constants.map(bits)}));
 for(const c of data.cases){const warnings=[];c.javascript=clippedTileSurfaceLine(data.meshes[c.mesh],...c.tile,c.from,c.to,m=>warnings.push(m));c.javascriptWarnings=warnings.length;c.javascriptBits=[...(c.javascript.entry??[null,null]),...(c.javascript.exit??[null,null]),c.javascript.minHeight,c.javascript.maxHeight].map(v=>v===null?null:bits(v));}
 process.stdout.write(JSON.stringify(data));
}
