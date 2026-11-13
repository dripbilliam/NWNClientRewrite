// Fresh immutable common-source family; preserves all earlier test capsules.
import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import assert from 'node:assert/strict';import {fileURLToPath} from 'node:url';
import {baseWorldExperimentFlags} from './replay_client_capsule.mjs';
const self=fileURLToPath(import.meta.url),project=path.resolve(path.dirname(self),'../../..'),parity=path.join(project,'.cache/native-presentation-parity');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex'),hash=f=>sha(fs.readFileSync(f));
const checked=(f,h)=>{const b=fs.readFileSync(f);assert.equal(sha(b),h,'Changed proof '+f);return b;};
const parentFile=path.join(parity,'root/pipeline-family-v2-a/static/manifest.json'),parentHash='6e2979fd503f79219537e9cedc2749e73d546a704f27a57871f840da2aedc676';
const parent=JSON.parse(checked(parentFile,parentHash)),portFile=path.join(parity,'static-scenery-agent/base-draw-leaf-v1/capsule-port-v2.json'),port=JSON.parse(fs.readFileSync(portFile));
assert.equal(port.version,2);assert.equal(path.resolve(port.original),path.resolve(parent.project));
const label=process.argv[2];assert.match(label??'',/^pipeline-family-v3-[a-z0-9-]+$/);const folder=path.join(parity,'root',label),target=path.join(folder,'project');assert.ok(!fs.existsSync(folder));
const overlays=new Map();
for(const row of port.files){
 if(row.capsule_before_sha256)assert.equal(row.reverse_exact,true);
 overlays.set(row.relative,{relative:row.relative,file:path.join(port.overlay,row.relative),sha256:row.capsule_after_sha256,before:row.capsule_before_sha256??null,proof:portFile});
}
const rootBackup=JSON.parse(fs.readFileSync(path.join(parity,'root/native-draw-hooks-v1/before.json')));
for(const relative of ['systems/native_data/asset_service.gd','systems/native_render/resource_pool.gd','systems/native_render/model_instance.gd']){
 const before=rootBackup.files.find(row=>row.relative===relative);assert.ok(before);
 overlays.set(relative,{relative,file:path.join(project,relative),sha256:hash(path.join(project,relative)),before:before.sha256,proof:'Exact root hook backup; prior dirty changes retained'});
}
for(const relative of ['systems/native_data/prepared_resource_store.gd','systems/native_render/native_mesh_resource_cache.gd','systems/native_render/native_draw_bundle_cache.gd','systems/native_render/native_draw_cache_runtime.gd','systems/native_render/native_draw_cache_drain.gd']){
 assert.ok(!overlays.has(relative));overlays.set(relative,{relative,file:path.join(project,relative),sha256:hash(path.join(project,relative)),before:null,proof:'New optional native draw cache dependency'});
}
fs.mkdirSync(target,{recursive:true});const pending=new Map(overlays),pins=[],changes=[];
for(const old of parent.pins){
 const original=checked(path.join(parent.project,old.relative),old.sha256),row=pending.get(old.relative);if(row)assert.equal(row.before,old.sha256);
 const raw=row?checked(row.file,row.sha256):original,file=path.join(target,old.relative);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,raw,{flag:'wx'});
 pins.push({...old,sha256:sha(raw),bytes:raw.length,overlay:Boolean(row)||old.overlay});if(row){changes.push(row);pending.delete(old.relative);}
}
for(const row of pending.values()){
 assert.equal(row.before,null);const raw=checked(row.file,row.sha256),file=path.join(target,row.relative);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,raw,{flag:'wx'});
 pins.push({relative:row.relative,sha256:row.sha256,bytes:raw.length,overlay:true});changes.push(row);
}
const base={...parent.experiments,baseDraw:'individual',nativeDrawCache:'none'};
const modes=[['terrain',base],['scenery',{...base,baseDraw:'merged'}],['cache',{...base,baseDraw:'merged',nativeDrawCache:'prepared'}]];
const variants=[],preferences=fs.readFileSync(parent.settings.file);
for(const [name,experiments]of modes){
 const dir=path.join(folder,name);fs.mkdirSync(dir);const settings=path.join(dir,'render-preferences.cfg');fs.writeFileSync(settings,preferences,{flag:'wx'});
 const m={...parent,label:label+'-'+name,created:new Date().toISOString(),project:target,pins,base:{file:parentFile,sha256:parentHash},settings:{...parent.settings,file:settings,initialSha256:sha(preferences)},experiments,pipelineChanges:changes,pipelineProofs:{baseDrawPort:{file:portFile,sha256:hash(portFile)},runtimeIntegration:path.join(parity,'root/native-draw-runtime-integration-c/run.json')},builder:{file:self,sha256:hash(self)},releaseReady:false,performanceAccepted:false,launchState:'unlaunched'};
 const file=path.join(dir,'manifest.json');fs.writeFileSync(file,JSON.stringify(m,null,2)+'\n',{flag:'wx'});variants.push({name,file,sha256:hash(file),flags:baseWorldExperimentFlags(experiments)});
}
for(const p of parent.pins)checked(path.join(parent.project,p.relative),p.sha256);for(const row of overlays.values())checked(row.file,row.sha256);
const composition={version:3,kind:'native-performance-pipeline-common-source-family',folder,project:target,pins:pins.length,changes,variants,launched:false,nativeBuilds:0,publicConnections:0};
fs.writeFileSync(path.join(folder,'composition.json'),JSON.stringify(composition,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({folder,pins:pins.length,variants},null,2));
