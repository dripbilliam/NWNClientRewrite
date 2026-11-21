// Evidence only. Does not start a renderer or connect to any server.
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
const project=new URL('../',import.meta.url),read=name=>fs.readFile(path.isAbsolute(name)?pathToFileURL(name):new URL(name,project)),sha=bytes=>createHash('sha256').update(bytes).digest('hex');
const names=['native-particle-baseline-goal-v5','native-particle-borrowed-crowd-v1','native-particle-float-crowd-v1'],runs=[];
for(const name of names){
 const bytes=await read('reports/'+name+'.json'),r=JSON.parse(bytes);
 for(const key of ['success','sourceUnchanged'])assert.equal(r[key],true,name+' '+key);
 assert.equal(r.publicConnections,0);assert.equal(r.nativeException,false);assert.equal(r.nativeExit,0);assert.equal(r.endpoint,'127.0.0.1:5125');
 assert.equal(r.actions.checks.length,81);assert.ok(r.actions.checks.every(c=>c.passed));assert.equal(r.native.world.effects.pending,0);assert.equal(r.native.world.effects.stats.started,166);
 assert.equal(r.native.world.native_particles.failed,14);assert.deepEqual(r.native.world.native_particles.reason_counts,{'Native scene wind sampling is pending':14});
 const captures=r.actions.checks.filter(c=>c.details.metrics).map(c=>({label:c.label,...c.details}));assert.equal(captures.length,15);
 for(const c of captures){assert.ok(c.frame_count>0);const frames=await read(c.raw_frames.replace('res://',''));assert.equal(JSON.parse(frames).length,c.frame_count);const full=JSON.parse(await read(c.detailed_evidence.replace('res://','')));assert.equal(full.first_frames.length,12);assert.equal(full.worst_frames.length,12);}
 runs.push({name,sha256:sha(bytes),source:r.sourceSha256,captures});
}
const changes=Object.keys(runs[0].source).filter(key=>runs[0].source[key]!==runs[2].source[key]);
assert.deepEqual(changes.sort(),['.cache/native-kernel/build-manifest.json','.cache/native-kernel/nwn-particle-kernel.dll','native/particle_resident.hpp'].sort());
for(const [name,digest]of Object.entries(runs[2].source))assert.equal(sha(await read(name)),digest,'Current measured source '+name);
const checks=[];
for(const [name,count]of [['native-effect-dependency-goal-v1',11],['native-particle-borrowed-records-v1',16338],['native-particle-borrowed-scene-v1',903],['native-particle-float-storage-v1',16338],['native-particle-float-scene-v1',903]]){
 const r=JSON.parse(await read('reports/'+name+'.json')),d=JSON.parse(await read('reports/'+name+'.debugger.json'));assert.equal(r.success,true);assert.equal(r.checks,count);assert.equal(d.success,true);assert.equal(d.sourceUnchanged,true);assert.equal(d.engineOrLifetimeError,false);checks.push({name,count});
}
const fields=['wall_ms','callback_particles','native_particle_channels_pose','native_particle_simulation','native_particle_vertices','native_particle_upload','render_cpu_ms','render_gpu_ms'];
const effects=JSON.parse(await read('reports/native-particle-storage-effects-v1.json'));
for(const key of ['success','sourceUnchanged'])assert.equal(effects[key],true);
assert.equal(effects.publicConnections,0);assert.equal(effects.nativeException,false);assert.equal(effects.actions.checks.length,39);assert.ok(effects.actions.checks.every(c=>c.passed));assert.equal(effects.native.world.effects.pending,0);
const comparisons=runs[0].captures.map((base,index)=>{
 const candidates=runs.slice(1).map(run=>run.captures[index]);
 for(const c of candidates){assert.equal(c.label,base.label);for(const key of ['particles','collision','native_scene','direct_scene'])assert.equal(c[key],base[key]);}
 return {label:base.label,variants:runs.map(run=>{const c=run.captures[index];return {run:run.name,frames:c.frame_count,peaks:c.peaks,metrics:Object.fromEntries(fields.map(f=>[f,{mean:c.metrics[f]?.mean??0,p95:c.metrics[f]?.p95??0,max:c.metrics[f]?.max??0}]))};})};
});
const out={success:true,createdAt:new Date().toISOString(),scope:'Instrumented 1280x800 authored original-server crowd: 12 visible NPCs, braziers and genuine small/great Heal. Static camera, same scene and settings. CPU child spans overlap; GPU counters are asynchronous. These are diagnostic timings, not clean FPS or matched-original-binary acceptance.',changes,runs:runs.map(({name,sha256})=>({name,sha256})),checks,effectsRegression:{run:'native-particle-storage-effects-v1',checks:39,publicConnections:0,nativeException:false},comparisons,knownMissingEmitters:14,completeParticleParity:false,completeGoal:false,remaining:'Ambient/noise wind and original frame/RNG ordering; wind scenery absent in all compared runs; chunk emitter transfer/setup cost; matched original runtime and cold/warm crowded-impact acceptance; remaining radial DM/edge/mirror parity.'};
const destination=new URL('reports/native-particle-goal-comparison-v2.json',project);
let previous;try{previous=JSON.parse(await fs.readFile(destination));}catch(error){if(error.code!=='ENOENT')throw error;}
if(previous)assert.deepEqual({...previous,createdAt:null},{...out,createdAt:null},'Existing evidence differs; preserve it and choose a new report version');
else await fs.writeFile(destination,JSON.stringify(out,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({success:true,localRuns:runs.length,checks:checks.reduce((n,r)=>n+r.count,0),completeParticleParity:false,completeGoal:false}));
