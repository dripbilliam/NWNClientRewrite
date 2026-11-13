// Compose a private common-source experiment family. No launch/build/network.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
import {baseWorldExperimentFlags} from './replay_client_capsule.mjs';

const self=fileURLToPath(import.meta.url),project=path.resolve(path.dirname(self),'../../..');
const parity=path.join(project,'.cache/native-presentation-parity');
const [label,action,...extra]=process.argv.slice(2);
assert.ok(action==='stage'&&!extra.length&&/^base-world-residency-[a-z0-9-]+$/.test(label??''),'Fresh residency family label and stage required');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const read=(file,expected)=>{const bytes=fs.readFileSync(file);assert.equal(sha(bytes),expected,'Changed pinned input: '+file);return bytes;};
const pin=(relative,sha256)=>({file:path.join(parity,relative),sha256});
const parent=pin('root/base-world-candidate-quiescent-v2/manifest.json','ffb1e4dd8c3c7525532918418581f104796c5539ecfde67448e23404031028e6');
const base=JSON.parse(read(parent.file,parent.sha256));
const stages={
 owner:pin('base-world-preparation-agent/base-owner-b1-v1/source-stage-v3.json','f15f483985a7efa5ea80a0816ea9d4ea17d7563dd6df8e559828b0fb452704e5'),
 templates:pin('base-world-preparation-agent/base-template-b2-v1/source-stage-v5.json','3989db39b4922bdb0ff6d419076e92622eb74076d6a9d2a37ff2b25f68ab4bc8'),
 recorded:pin('base-world-preparation-agent/base-template-b2-v1/recorded-scope-v6/source-stage-v6.json','8a68e33d0c018443595557e5d9a7488f4d4ed13260ecf42334277cbe8716b1af'),
 diagnostics:pin('base-world-preparation-agent/base-template-b2-v1/source-stage-v7.json','9c40a28e3d752b4da742fb37efda7c216429294e6ab23756ec01b0b07439d010'),
};
const source=Object.fromEntries(Object.entries(stages).map(([name,p])=>[name,JSON.parse(read(p.file,p.sha256))]));
const world=source.owner.files.find(row=>row.profile==='capsule'&&row.kind==='world');
const progressFolder=path.join(parity,'base-world-scheduler-review-agent/preterrain-review-v2/base-progress-boundaries-v1/b1-port-v1');
const progressStageFile=path.join(progressFolder,'stage.json'),progressStageBytes=fs.readFileSync(progressStageFile),progressStage=JSON.parse(progressStageBytes);
assert.equal(progressStage.beforeSha256,world.after);assert.equal(progressStage.afterSha256,'514d7f31cbf086e26afda9ba046b8399369e6de9421cb022d12d000f8aba8cc1');
assert.equal(progressStage.patchReplayed,true);assert.equal(progressStage.outsideReviewedSeamsByteIdentical,true);
const progressRunPin={file:path.join(progressFolder,'fixture-v1/run.json'),sha256:'8fa26d4fa5797c4af94110b34793562f8e3646d8d983b7b3b84a9617f0d48977'};
const progressRun=JSON.parse(read(progressRunPin.file,progressRunPin.sha256));
assert.equal(progressRun.strictPass,true);assert.equal(progressRun.exitCode,0);assert.equal(progressRun.result.checks,199);
const diagnosticRunPin=pin('base-world-preparation-agent/base-template-b2-v1/completion-diagnostics-v7/fixture-v3-run-20261107-a/run.json','340aaedcaaec0cfb46207e5aa77dcfee602e4584f1748dc4a4a5364fcd637e4e');
const diagnosticRun=JSON.parse(read(diagnosticRunPin.file,diagnosticRunPin.sha256));
assert.equal(diagnosticRun.success,true);assert.equal(diagnosticRun.status,0);assert.equal(diagnosticRun.result.checks,277);assert.equal(diagnosticRun.diagnostics.length,0);
const object=source.diagnostics.files.find(row=>row.profile==='capsule');
const record=source.recorded.files.find(row=>row.relative==='systems/native_data/recorded_catalog.gd');
const directory=source.recorded.files.find(row=>row.relative==='systems/native_render/base_template_directory.gd');
assert.ok(world&&object&&record&&directory,'Missing reviewed source profile');
const progressedWorld={...world,candidate:path.join(progressFolder,'after.gd'),after:progressStage.afterSha256};
const overlays=[progressedWorld,object,record,directory].map(row=>({relative:row.relative,file:row.candidate,sha256:row.after}));
const changes=new Map(overlays.map(row=>[row.relative,{...row,bytes:read(row.file,row.sha256)}]));
assert.equal(changes.size,4);
const originals=new Map();
for(const row of base.pins){
 assert.ok(row.relative.split('/').every(part=>part&&part!=='.'&&part!=='..')&&!row.relative.includes('\\')&&!row.relative.includes(':'));
 assert.ok(!originals.has(row.relative));originals.set(row.relative,read(path.join(base.project,row.relative),row.sha256));
}
assert.equal(sha(originals.get(world.relative)),world.before,'B1 world parent differs');
assert.equal(sha(originals.get(record.relative)),record.before,'Recorded provider parent differs');
assert.equal(originals.has(directory.relative),false,'Existing helper must not be overwritten');
assert.equal(base.pins.find(row=>row.relative==='systems/native_render/live_world_quiescent_candidate.gd')?.sha256,'2a2e5f83b19ba0fd6e0bbf99a3c15016bbdecce2deb8adce906785671a6ff328','Inherited three-lane repair missing');
assert.ok(changes.get(object.relative).bytes.toString().includes('grant_particle_pose_lease'),'Capsule particle lease hook lost');

const folder=path.join(parity,'root',label),target=path.join(folder,'project');
assert.ok(!fs.existsSync(folder),'Existing family retained; use fresh label');
fs.mkdirSync(target,{recursive:true});
const builderCopy=path.join(folder,'builder.mjs');fs.writeFileSync(builderCopy,fs.readFileSync(self),{flag:'wx'});
const pins=[];
for(const [relative,bytes] of new Map([...originals,...overlays.filter(row=>!originals.has(row.relative)).map(row=>[row.relative,changes.get(row.relative).bytes])])){
 const overlay=changes.get(relative),value=overlay?.bytes??bytes,file=path.join(target,relative);
 fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,value,{flag:'wx'});
 assert.equal(sha(fs.readFileSync(file)),sha(value));
 pins.push({...base.pins.find(row=>row.relative===relative),relative,sha256:sha(value),bytes:value.length,overlay:Boolean(overlay)||Boolean(base.pins.find(row=>row.relative===relative)?.overlay)});
}
const variants=[
 ['control',{baseOwner:'original',baseTemplates:'original'}],
 ['owner',{baseOwner:'retained',baseTemplates:'original'}],
 ['templates',{baseOwner:'retained',baseTemplates:'retained'}],
];
const preferenceBytes=fs.readFileSync(base.settings.file),results=[];
for(const [name,experiments] of variants){
 const variant=path.join(folder,name);fs.mkdirSync(variant);
 const preferences=path.join(variant,'render-preferences.cfg');fs.writeFileSync(preferences,preferenceBytes,{flag:'wx'});
 const manifest={...base,label:label+'-'+name,created:new Date().toISOString(),project:target,pins,base:parent,
  settings:{...base.settings,file:preferences,initialSha256:sha(preferenceBytes)},experiments,
  cacheExperiment:{family:label,variant:name,commonSources:true,stagePins:stages,changes:overlays,
   scope:'Only reviewed owner/template/recorded-source cache experiments; unrelated deferred renderer experiments remain excluded',
   attribution:'Compare original corrected client separately, then common-source control vs retained owner vs retained owner/template. Account once-at-mount provider sealing in all common-source variants.'},
  boundaryProgressProof:{stage:{file:progressStageFile,sha256:sha(progressStageBytes)},run:progressRunPin},completionDiagnosticProof:diagnosticRunPin,
  builder:{file:builderCopy,origin:self,sha256:sha(fs.readFileSync(builderCopy))},validationState:'staged-not-validated',releaseReady:false,performanceAccepted:false,launchState:'unlaunched',engineStarts:0,nativeBuilds:0,serverConnections:0,
  pendingGates:['complete-client-dependency-check','actual-renderer-disclosure','full-room-content-lifetime-and-visual-check','matched-cold-warm-loading-memory-and-frame-comparison']};
 const file=path.join(variant,'manifest.json');fs.writeFileSync(file,JSON.stringify(manifest,null,2)+'\n',{flag:'wx'});
 results.push({name,file,sha256:sha(fs.readFileSync(file)),flags:baseWorldExperimentFlags(experiments)});
}
for(const row of base.pins)read(path.join(base.project,row.relative),row.sha256);
for(const row of overlays)read(row.file,row.sha256);
for(const row of Object.values(stages))read(row.file,row.sha256);
assert.equal(sha(fs.readFileSync(base.settings.file)),sha(preferenceBytes));
fs.writeFileSync(path.join(folder,'composition.json'),JSON.stringify({version:1,staged:true,launched:false,commonSourceProject:target,pins:pins.length,overlays,variants:results,unreviewedSourcesIncluded:false,engineStarts:0,nativeBuilds:0,serverConnections:0},null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({staged:true,launched:false,folder,variants:results}));
