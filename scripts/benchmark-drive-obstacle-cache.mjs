// Compare the sealed prior implementation with the current collision adapter.
// Synthetic CPU workload only: no game connections, assets or credentials.
import fs from 'node:fs/promises';import assert from 'node:assert/strict';import {createHash} from 'node:crypto';
import {NetworkDriveGeometry} from '../src/network_drive_geometry.js';
import {NativeAreaCollisionStore} from '../src/area_collision_store.js';
import {nativePlacementOrientation} from '../src/object_surface_mesh.js';
import {resolveDoorModel} from '../src/area.js';
const version=process.argv[2]??'v2';assert.match(version,/^v\d+$/);
const root=new URL('../',import.meta.url),prior=await fs.readFile(new URL('backups/animations/creation-performance-drive-cache-before-v1.js',root),'utf8'),start=prior.indexOf(' async obstacles(){'),end=prior.indexOf(' async query(actor){');assert.ok(start>=0&&end>start);
const previous=Function('NativeAreaCollisionStore','nativePlacementOrientation','resolveDoorModel','f','return ({'+prior.slice(start,end)+'}).obstacles')(NativeAreaCollisionStore,nativePlacementOrientation,resolveDoorModel,Math.fround);
const mesh={vertices:[[0,0,0],[1,0,0],[0,1,0],[0,0,1],[1,0,1],[0,1,1]],faces:[[0,1,2],[3,4,5],[0,3,4],[0,4,1]]};
function fixture(method){
 const objects=new Map(Array.from({length:300},(_,i)=>[i,{id:i,objectType:9,areaId:1,replicated:{appearance:0,position:[i%30*2,Math.floor(i/30)*2,0],orientation:[1,0,0],hitPoints:10,effects:Array.from({length:16},(_,j)=>({id:j,creator:i,remaining:20}))}}])),scene={area:{id:1,tiles:[]},world:{registry:{objects}},resolver:{},tables:{},report:()=>{}},geometry=new NetworkDriveGeometry(scene);let meshReads=0;
 geometry.resources.placeableMesh=async()=>{meshReads++;return{mesh};};geometry.obstacles=method.bind(geometry);return{geometry,objects,reads:()=>meshReads};
}
const old=fixture(previous),current=fixture(NetworkDriveGeometry.prototype.obstacles),report={scope:'Synthetic300-placeable CPU cache benchmark with unrelated replicated HP/effect updates, alternating sealed prior/current; not end-to-end FPS or a native game benchmark',httpAttempts:0,joins:0,priorSourceSha256:createHash('sha256').update(prior).digest('hex'),samples:{before:[],after:[]}};
const fingerprint=r=>({ids:[...r.store.objectIds],bounds:[...r.store.bounds],vertices:[...r.store.vertices],indices:[...r.store.indices]});
assert.deepEqual(fingerprint(await old.geometry.obstacles()),fingerprint(await current.geometry.obstacles()));
for(let i=0;i<100;i++){
 for(const [name,fixture]of(i%2?[['after',current],['before',old]]:[['before',old],['after',current]])){
  for(const object of fixture.objects.values()){object.replicated.hitPoints=i;object.replicated.effects[0].remaining=i;}
  const at=performance.now();await fixture.geometry.obstacles();report.samples[name].push(performance.now()-at);
 }
}
assert.equal(current.reads(),300);assert.equal(old.reads(),30300);
for(const fixture of[old,current])fixture.objects.get(0).replicated.position[0]++;
assert.deepEqual(fingerprint(await old.geometry.obstacles()),fingerprint(await current.geometry.obstacles()));assert.equal(current.reads(),600);
const summary=values=>{const sorted=values.slice(10).sort((a,b)=>a-b);return{measured:sorted.length,medianMs:sorted[Math.floor(sorted.length*.5)],p95Ms:sorted[Math.floor(sorted.length*.95)],worstMs:sorted.at(-1)};};
report.before=summary(report.samples.before);report.after=summary(report.samples.after);report.meshReads={before:old.reads(),after:current.reads()};report.equivalentFinalGeometry=true;report.currentSourceSha256=createHash('sha256').update(await fs.readFile(new URL('src/network_drive_geometry.js',root))).digest('hex');report.success=true;
await fs.writeFile(new URL('backups/animations/creation-performance-drive-cache-benchmark-'+version+'.json',root),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({...report,samples:undefined}));
