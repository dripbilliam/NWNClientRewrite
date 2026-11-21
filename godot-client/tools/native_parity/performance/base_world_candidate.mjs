// Stage only. No engine, process-control, network, rebuild or launch path.
// node base_world_candidate.mjs base-world-candidate-<fresh-label> stage
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {verifyClientLaunchEngine} from '../loading/client_launch_engine.mjs';
import {verifyClientLaunchDisplay} from '../loading/client_launch_proofs.mjs';

const file=fileURLToPath(import.meta.url);
const source=path.resolve(path.dirname(file),'../../..');
const cache=path.join(source,'.cache/native-presentation-parity');
const [label,action,...extra]=process.argv.slice(2);
if(extra.length||action!=='stage'||!/^base-world-candidate-[a-z0-9-]{1,65}$/.test(label??''))throw Error('Explicit fresh base-world-candidate label and stage required');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const requireValue=(ok,message)=>{if(!ok)throw Error(message);};
const read=p=>fs.readFileSync(p);
const within=(root,p)=>{const r=path.relative(root,p);return r===''||r!=='..'&&!r.startsWith('..'+path.sep)&&!path.isAbsolute(r);};
const checked=(p,hash)=>{requireValue(within(source,p),'Input outside project');const b=read(p);requireValue(sha(b)===hash,'Changed pinned input: '+p);return b;};
const cached=(p,hash)=>({file:path.join(cache,p),sha256:hash});
const basePin=cached('root/live-walk-candidate-v1/manifest.json','92c8c6591d252b480d8afa3297aedcc68fbec1c5d6d997cc5a4869df13a5a504');
const base=JSON.parse(checked(basePin.file,basePin.sha256));
requireValue(base.kind==='live-walk-diagnostic-stage'&&base.mode==='--highlight=whole-character'&&base.parkedWorkIncluded===false,'Unexpected base policy');
verifyClientLaunchEngine(base.engine);verifyClientLaunchDisplay(base.display);
requireValue(base.engine.sha256==='62f54a7f7ff4638987730a246833cea4054779e7cb2a333bb5921fd5b0aea6dc','Engine differs');
for(const p of base.proofPins)checked(p.file,p.sha256);

const proofs={
 template:cached('base-world-preparation-agent/capsule-first-placement-v1/authored40-v2/run.json','eb63bd63f0697df2f7b57bab911811581d7a4529dd87ef103923fed54cfd65cd'),
 templatePort:cached('base-world-preparation-agent/capsule-first-placement-v1/stage.json','96d30b1442bc8ba9325bd7a359e63599c653755141c1810230a5a372dc740787'),
 lane:cached('base-world-admission-agent/base-lane-v3/run-5.json','4beb19ce7e629ac7fe3fe0eac6090452ff8d7a1e23a72b175336947b7bad8859'),
 laneFreeze:cached('base-world-admission-agent/base-lane-v3/freeze.json','d818b5299ba78859c081bdc79f435f4bd0200f9600f8b474acad2d4d7340d924'),
 tables:cached('visibility-agent/object-appearance-table-elision-v3/run.json','c441e373b19fa4540fbbfc07f6bb287e11227c01fc10669ec0973ea83820cbaf'),
 tablePatch:cached('visibility-agent/object-appearance-table-elision-v3/patch-compatibility.json','2454fb48ad606f138e8a87ee75a9d896077f88a681f47544d02513a14a6fe055'),
 quiescent:cached('base-world-scheduler-review-agent/preterrain-review-v2/quiescent-contract-repair-v1/corrected-run-v2/run.json','86ece782315b4b36d01dc7e8016a2104d59ca952f3fdfdc4887d4af945e5a07d'),
};
const loaded=Object.fromEntries(Object.entries(proofs).map(([k,p])=>[k,JSON.parse(checked(p.file,p.sha256))]));
for(const [name,count]of [['template',40],['lane',120],['tables',71]]){
 const r=loaded[name];requireValue(r.success===true&&r.result?.success===true&&r.result.checks===count&&(r.status??r.exit)===0&&!r.error&&(r.errors??r.diagnostics).length===0,'Focused evidence differs: '+name);
}
requireValue(loaded.templatePort.template.reverseExact&&loaded.templatePort.template.placementBodyByteIdentical&&loaded.tablePatch.success,'Narrow port evidence differs');
requireValue(loaded.quiescent.strictPass===true&&loaded.quiescent.exitCode===0&&loaded.quiescent.startupDiagnostics.length===0&&loaded.quiescent.result?.passed===true&&loaded.quiescent.result.checks===29&&loaded.quiescent.result.old_contract_reproduced===true&&loaded.quiescent.engine.sha256===base.engine.sha256,'Inherited planner contract regression evidence differs');
const overlays=[
 ['systems/native_render/model_template.gd','base-world-preparation-agent/capsule-first-placement-v1/project/systems/native_render/model_template.gd','9d5568d27319e5dd6b074a5369bcb30984e1e50f045ac134979f1f577ab3f5b6'],
 ['systems/native_render/area_stream.gd','root/base-world-capsule-ports-v1/candidate/systems/native_render/area_stream.gd','eff0389af19c71d392619ed6dca76caed4bba185367992cba253ba1eb4ae4844'],
 ['systems/native_render/object_stream.gd','visibility-agent/object-appearance-table-elision-v3/lease-after/systems/native_render/object_stream.gd','4e8ec504c42f9eac7fdda8f27e57ba85b6104d0e404261358a89090ff5522f14'],
 ['systems/native_render/live_world.gd','base-world-admission-agent/base-lane-v3/applicability-frozen-lf/capsule/after/systems/native_render/live_world.gd','defef1bd928cf103270a555d201824bc14c261203ce848b0cc5b5305c447bf91'],
 ['systems/native_render/base_world_scenery.gd','base-world-admission-agent/base-lane-v3/candidate/systems/native_render/base_world_scenery.gd','848a0465c97eed5ea9d8e6ceade8f8b231640dcf3e43fe95d83f5b343197c071'],
 ['systems/native_render/live_world_quiescent_candidate.gd','root/base-world-quiescent-contract-v1/live_world_quiescent_candidate.fixed.gd','2a2e5f83b19ba0fd6e0bbf99a3c15016bbdecce2deb8adce906785671a6ff328'],
].map(([relative,p,sha256])=>({relative,...cached(p,sha256)}));
const byName=new Map(overlays.map(p=>[p.relative,p]));
const bytes=new Map(overlays.map(p=>[p.relative,checked(p.file,p.sha256)]));
const seen=new Set();
const originalBytes=new Map();
for(const p of base.pins){
 requireValue(typeof p.relative==='string'&&p.relative.split('/').every(s=>s&&s!=='.'&&s!=='..')&&!p.relative.includes('\\')&&!p.relative.includes(':'),'Unsafe source path');
 requireValue(!seen.has(p.relative.toLowerCase()),'Duplicate source path');seen.add(p.relative.toLowerCase());
 originalBytes.set(p.relative,checked(path.join(base.project,p.relative),p.sha256));
}
requireValue(base.pins.find(p=>p.relative==='.cache/native-kernel/nwn-particle-kernel.dll')?.sha256==='672bd24ae23f0be06bb209bc40ec5083fbe8ac14e92b2dd6b10f836255a840ea','Particle DLL differs');
const prefBefore=fs.statSync(base.settings.file),preferences=read(base.settings.file),prefAfter=fs.statSync(base.settings.file);
requireValue(prefBefore.size===prefAfter.size&&prefBefore.mtimeMs===prefAfter.mtimeMs,'Preferences changed during capture');
const directory=path.join(cache,'root',label),project=path.join(directory,'project');
requireValue(!fs.existsSync(directory),'Existing candidate preserved; use fresh label');
fs.mkdirSync(directory);fs.mkdirSync(project);
const write=(p,value)=>fs.writeFileSync(p,JSON.stringify(value,null,2)+'\n',{flag:'wx'});
try{
 const pins=[],changes=[];
 for(const p of base.pins){
  const overlay=byName.get(p.relative),b=overlay?bytes.get(p.relative):originalBytes.get(p.relative),target=path.join(project,p.relative);
  fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,b,{flag:'wx'});
  requireValue(sha(read(target))===(overlay?.sha256??p.sha256),'Copy differs');
  pins.push({...p,sha256:sha(b),bytes:b.length,overlay:Boolean(overlay)});
  if(overlay)changes.push({relative:p.relative,before:p.sha256,after:overlay.sha256,source:overlay.file});
 }
 for(const p of overlays.filter(p=>!originalBytes.has(p.relative))){
  fs.writeFileSync(path.join(project,p.relative),bytes.get(p.relative),{flag:'wx'});
  pins.push({relative:p.relative,sha256:p.sha256,bytes:bytes.get(p.relative).length,overlay:true});changes.push({relative:p.relative,before:null,after:p.sha256,source:p.file});
 }
 requireValue(changes.length===6&&changes.every(p=>byName.has(p.relative)),'Unexpected source changes');
 const preferencesFile=path.join(directory,'render-preferences.cfg');fs.writeFileSync(preferencesFile,preferences,{flag:'wx'});
 for(const p of base.pins)checked(path.join(base.project,p.relative),p.sha256);
 for(const p of overlays)checked(p.file,p.sha256);
 const manifest={version:1,kind:'base-world-entry-diagnostic-stage',label,created:new Date().toISOString(),project,base:basePin,pins,overlays:changes,engine:base.engine,display:base.display,mode:base.mode,settings:{...base.settings,file:preferencesFile,initialSha256:sha(preferences),provenance:{source:base.settings.file,observedSha256:sha(preferences),normalized:false}},proofs,builder:{file,sha256:sha(read(file))},validationState:'staged-not-validated',releaseReady:false,launchState:'unlaunched',pendingGates:['complete-client-dependency-check','real-assets-and-collision','visual-and-loading-comparison','cold-warm-loading-and-content-equivalence'],inheritedRuntimePolicyUnchanged:true,parkedWorkIncluded:false,engineStarts:0,nativeBuilds:0,serverConnections:0,performanceAccepted:false};
 write(path.join(directory,'manifest.json'),manifest);
 console.log(JSON.stringify({staged:true,launched:false,directory,manifestSha256:sha(read(path.join(directory,'manifest.json'))),changes:changes.map(p=>p.relative),pendingGates:manifest.pendingGates}));
}catch(error){write(path.join(directory,'stage-failed.json'),{success:false,error:String(error),launched:false,scope:'Partial staging retained; no overwrite or launch'});throw error;}
