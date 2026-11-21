// Offline parser/geometry reference. Write hashes/poses only, no original art.
import fs from 'node:fs/promises';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {SceneCaptureArchive} from '../../electron/scene_capture_archive.mjs';
import {SceneCaptureSupplement} from '../../electron/scene_capture_supplement.mjs';
import {parseModel} from '../../src/model_parser.js';
import {buildModelGeometry} from '../../src/prepared_model_geometry.js';
import {decodeModelOrientation} from '../../src/mdl_format.js';
const capture=path.resolve(process.argv.find(a=>a.startsWith('--capture='))?.slice(10)??''),supplement=path.resolve(process.argv.find(a=>a.startsWith('--supplement='))?.slice(13)??'');
if(!process.argv.some(a=>a.startsWith('--capture='))||!process.argv.some(a=>a.startsWith('--supplement=')))throw Error('Explicit sealed capture/supplement required');
const parent=await SceneCaptureArchive.open(capture),extra=await SceneCaptureSupplement.open(supplement,parent),resolver=SceneCaptureSupplement.combine(parent,[extra]).resolver('context-1');
const sha=b=>createHash('sha256').update(b).digest('hex'),samples=[];
for(const name of ['twc03_a01_03','twc03_a01_02']){
 const bytes=await resolver.getResource(name,2002),model=parseModel(bytes);
 if(model.format!=='ASCII MDL')throw Error('Expected original ASCII MDL');
 const nodes=model.nodes.map(n=>{const geometry=n.type==='trimesh'?buildModelGeometry(n):null;const groups=geometry?geometry.groups.map(g=>{const start=g.start,end=start+g.count,attr=geometry.attributes;return {vertices:g.count,material:g.materialIndex,positionSha256:sha(Buffer.from(attr.position.array.slice(start*3,end*3).buffer)),uvSha256:sha(Buffer.from(attr.uv.array.slice(start*2,end*2).buffer)),normalQuantizedSha256:sha(Buffer.from(Int32Array.from(attr.normal.array.slice(start*3,end*3),v=>Math.round(v*10000)).buffer))};}):[];geometry?.dispose();return {name:n.name,parent:n.parent,position:n.position,quaternion:decodeModelOrientation(n.orientation,n.orientationFormat),scale:n.scale,groups};});
 samples.push({name,sha256:sha(Buffer.from(bytes)),nodes});
}
const fixture={capture,supplement,scope:'Read-only original ASCII MDL: pose/count/geometry hashes only',samples};
await fs.writeFile('godot-client/reports/native-ascii-oracle-v1.json',JSON.stringify(fixture,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(samples.map(s=>({name:s.name,nodes:s.nodes.length,meshes:s.nodes.filter(n=>n.groups.length).length}))));
