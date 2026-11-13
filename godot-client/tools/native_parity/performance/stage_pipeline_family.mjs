// Immutable common-source comparison; no process start, network or native build.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
import {baseWorldExperimentFlags} from './replay_client_capsule.mjs';

const self=fileURLToPath(import.meta.url),project=path.resolve(path.dirname(self),'../../..');
const parity=path.join(project,'.cache/native-presentation-parity');
const label=process.argv[2];assert.match(label??'',/^pipeline-family-[a-z0-9-]+$/);
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const checked=(file,hash)=>{const raw=fs.readFileSync(file);assert.equal(sha(raw),hash,'Changed source '+file);return raw;};
const parentFile=path.join(parity,'base-world-preparation-agent/base-template-b2-v1/scheduling-family-v1/combined/manifest.json');
const parentHash='5fd0472500d3deaa699592beec5ce3f17241ccf48b46db60f7fb33b1940f1367';
const parent=JSON.parse(checked(parentFile,parentHash));
const streamFile=path.join(parity,'continuous-streaming-agent/refill-v1/capsule-port-v2.json');
const stream=JSON.parse(fs.readFileSync(streamFile));
const staticFile=path.join(parity,'static-scenery-agent/terrain-instancing-v1/capsule-port.json');
const statics=JSON.parse(checked(staticFile,'743bc43f8cfa2d435901d505bce1a30770febf7365a921565f894c31fc63e508'));
const animationFile=path.join(parity,'shared-animation-agent/immutable-preparation-v1/completion.json');
const animation=JSON.parse(checked(animationFile,'999238c9fcf291bf1f773d8181779212109ec213afcda01aafc34cf15d3f0975'));
assert.equal(statics.reverseProof,true);assert.equal(animation.tests.success,true);assert.equal(animation.tests.checks,73);
const overlays=stream.rows.map(row=>({relative:row.relative,file:row.file,sha256:row.capsuleAfter,before:row.capsuleBefore??null}));
for(const row of statics.files)overlays.push({relative:row.relative,file:row.source,sha256:row.sha256,before:row.relative.endsWith('/area_stream.gd')?statics.capsuleBeforeSha256:null});
for(const row of animation.files.filter(row=>row.relative.startsWith('systems/')))overlays.push({relative:row.relative,file:path.join(project,row.relative),sha256:row.sha256,before:row.relative.endsWith('/asset_service.gd')?animation.before.files.find(row=>row.relative.endsWith('/asset_service.gd')).sha256:null});
assert.equal(overlays.length,7);assert.equal(new Set(overlays.map(row=>row.relative)).size,7);
const folder=path.join(parity,'root',label),target=path.join(folder,'project');assert.ok(!fs.existsSync(folder),'Fresh family required');
fs.mkdirSync(target,{recursive:true});
const pending=new Map(overlays.map(row=>[row.relative,row]));const pins=[],changes=[];
for(const old of parent.pins){
 const original=checked(path.join(parent.project,old.relative),old.sha256);const overlay=pending.get(old.relative);
 if(overlay)assert.equal(overlay.before,old.sha256,'Overlay base differs '+old.relative);
 const bytes=overlay?checked(overlay.file,overlay.sha256):original;
 const file=path.join(target,old.relative);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,bytes,{flag:'wx'});
 pins.push({...old,sha256:sha(bytes),bytes:bytes.length,overlay:Boolean(overlay)||old.overlay});
 if(overlay){changes.push(overlay);pending.delete(old.relative);}
}
for(const row of pending.values()){
 assert.equal(row.before,null);const bytes=checked(row.file,row.sha256),file=path.join(target,row.relative);
 fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,bytes,{flag:'wx'});pins.push({relative:row.relative,sha256:row.sha256,bytes:bytes.length,overlay:true});changes.push(row);
}
assert.equal(changes.length,7);
const base={baseOwner:'retained',baseTemplates:'retained',baseReadyProbe:'ready',baseAdmission:'timed',sharedAnimations:'ordinary',baseStreaming:'waves',staticScenery:'individual'};
const modes=[['control',base],['animations',{...base,sharedAnimations:'shared'}],['streaming',{...base,sharedAnimations:'shared',baseStreaming:'continuous'}],['static',{...base,sharedAnimations:'shared',baseStreaming:'continuous',staticScenery:'batched'}]];
const preferences=fs.readFileSync(parent.settings.file),variants=[];
for(const [name,experiments] of modes){
 const dir=path.join(folder,name);fs.mkdirSync(dir);const settings=path.join(dir,'render-preferences.cfg');fs.writeFileSync(settings,preferences,{flag:'wx'});
 const manifest={...parent,label:label+'-'+name,created:new Date().toISOString(),project:target,pins,base:{file:parentFile,sha256:parentHash},experiments,
  settings:{...parent.settings,file:settings,initialSha256:sha(preferences)},
  pipelineProofs:{stream:{file:streamFile,sha256:sha(fs.readFileSync(streamFile))},statics:{file:staticFile,sha256:sha(fs.readFileSync(staticFile))},animation:{file:animationFile,sha256:sha(fs.readFileSync(animationFile))}},
  pipelineChanges:changes,builder:{file:self,sha256:sha(fs.readFileSync(self))},releaseReady:false,performanceAccepted:false,launchState:'unlaunched'};
 const file=path.join(dir,'manifest.json');fs.writeFileSync(file,JSON.stringify(manifest,null,2)+'\n',{flag:'wx'});variants.push({name,file,sha256:sha(fs.readFileSync(file)),flags:baseWorldExperimentFlags(experiments)});
}
for(const row of parent.pins)checked(path.join(parent.project,row.relative),row.sha256);
for(const row of overlays)checked(row.file,row.sha256);
const composition={version:1,kind:'native-performance-pipeline-common-source-family',folder,project:target,changes,pins:pins.length,variants,launched:false,nativeBuilds:0,publicConnections:0};
fs.writeFileSync(path.join(folder,'composition.json'),JSON.stringify(composition,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(composition));
