// Offline oracle only: original WOK text stays installed. The report contains
// hashes/counts and sampled scalar heights, never scene/geometry payloads.
import fs from 'node:fs/promises';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {openServerResourceContext} from '../../electron/server_resource_context.mjs';
import {parseAreaModule,parse2da} from '../../src/area.js';
import {parseTileSurfaceMesh,tileSurfaceHeight} from '../../src/tile_surface_mesh.js';
const arg=n=>process.argv.find(a=>a.startsWith('--'+n+'='))?.slice(n.length+3);
const install=path.resolve(arg('install')??'../FullDecomp/NwnRootInstall'),run=arg('run')??'native-surface-oracle-v1';
if(!/^[a-z0-9-]+$/.test(run))throw Error('Invalid surface oracle name');
const resolver=await openServerResourceContext({install,module:path.join(install,'data/nwm/Prelude.nwm')});
const table=Buffer.from(await resolver.getResource('surfacemat',2017)),surfaces=parse2da(table.toString('ascii'));
const area=await parseAreaModule('m0q1a',resolver),names=[...new Set(area.tiles.map(t=>t.model))];
// Include the remaining original Prelude tile models to exercise more than the
// initial room. Missing area data is recorded, never substituted.
const areas=['m0q1a'],areaErrors=[];
for(const key of resolver.module.entries.keys()){
 if(!key.endsWith(':2012')||key==='m0q1a:2012')continue;
 const name=key.slice(0,-5);
 try{const original=await parseAreaModule(name,resolver);areas.push(name);for(const tile of original.tiles)if(!names.includes(tile.model))names.push(tile.model);}
 catch(error){areaErrors.push({name,reason:error.message});}
}
const hash=b=>createHash('sha256').update(b).digest('hex');
function geometry(part){const values=[];for(let i=0;i<part.faces.length;i++)values.push(...part.faces[i].flatMap(v=>part.vertices[v]),...part.normals[i],part.constants[i],part.materials[i]);return hash(Buffer.from(Float32Array.from(values).buffer));}
const samples=[];
for(const name of names){
 const raw=Buffer.from(await resolver.getResource(name,2016)),mesh=parseTileSurfaceMesh(raw,surfaces),queries=[];
 for(let x=0;x<=10;x+=0.5)for(let y=0;y<=10;y+=0.5)queries.push({point:[x,y],height:tileSurfaceHeight(mesh,[x,y,12345])});
 samples.push({name,sha256:hash(raw),walkable:mesh.faces.length,denied:mesh.denied.faces.length,walkableGeometrySha256:geometry(mesh),deniedGeometrySha256:geometry(mesh.denied),queries});
}
const sources={};for(const file of ['src/tile_surface_mesh.js','src/area.js','src/native_math.js'])sources[file]=hash(await fs.readFile(file));
const report={scope:'Offline independent existing JS/native-method WOK oracle. Original text remains installed; sampled heights and geometry hashes only. Native runtime does not import this tool.',install,areas,areaErrors,tableSha256:hash(table),sources,samples};
await fs.writeFile('godot-client/reports/'+run+'.json',JSON.stringify(report,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({samples:samples.length,areas,areaErrors,queries:samples.reduce((n,s)=>n+s.queries.length,0)}));
