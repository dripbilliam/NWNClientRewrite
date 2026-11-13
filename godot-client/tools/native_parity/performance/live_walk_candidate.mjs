// STAGE ONLY. This file has no engine/Electron/server/process-control path.
// Usage after review: node live_walk_candidate.mjs live-walk-candidate-v1 stage
// A staged source capsule is NOT permission or evidence to launch it.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {verifyClientLaunchEngine} from '../loading/client_launch_engine.mjs';
import {verifyClientLaunchDisplay} from '../loading/client_launch_proofs.mjs';

const builderFile=fileURLToPath(import.meta.url);
const source=path.resolve(path.dirname(builderFile),'../../..');
const cache=path.join(source,'.cache/native-presentation-parity');
const BASE_SHA='7a7059598b4f114bba55a44863d7938b6590542c5cfce97a778c3249a0a02c43';
const ENGINE_SHA='62f54a7f7ff4638987730a246833cea4054779e7cb2a333bb5921fd5b0aea6dc';
const PARTICLE_SHA='672bd24ae23f0be06bb209bc40ec5083fbe8ac14e92b2dd6b10f836255a840ea';
const BASE_LAUNCH_SHA='70c11d7aeaf8dfde1f81d59e93689026fd5dc65651df53a1f5a6d038c10c1ad4';
const [label,action,...extra]=process.argv.slice(2);
if(extra.length||action!=='stage'||!/^live-walk-candidate-[a-z0-9-]{1,70}$/.test(label??''))throw Error('Explicit fresh live-walk-candidate label and stage required; no launch action exists');

const sha=raw=>crypto.createHash('sha256').update(raw).digest('hex');
const equal=(a,b)=>JSON.stringify(a)===JSON.stringify(b);
const proofPins=new Map();
function requireValue(condition,message){if(!condition)throw Error(message);}
function within(root,file){const relative=path.relative(path.resolve(root),path.resolve(file));return relative===''||!relative.startsWith('..'+path.sep)&&relative!=='..'&&!path.isAbsolute(relative);}
function relativeFile(root,relative){
 requireValue(typeof relative==='string'&&relative.length>0&&!relative.includes('\\')&&!relative.includes(':')&&!relative.startsWith('/')&&relative.split('/').every(part=>part!==''&&part!=='.'&&part!=='..'),'Unsafe pinned relative path');
 const file=path.resolve(root,relative);requireValue(within(root,file),'Pinned file escaped its owner');return file;
}
function checked(pin,owner=cache){
 requireValue(pin&&typeof pin.file==='string'&&/^[a-f0-9]{64}$/.test(pin.sha256??'')&&within(owner,pin.file),'Invalid input pin');
 requireValue(fs.statSync(pin.file).isFile()&&within(fs.realpathSync(owner),fs.realpathSync(pin.file)),'Pinned input is not an owned regular file');
 const bytes=fs.readFileSync(pin.file);requireValue(sha(bytes)===pin.sha256,'Pinned input changed: '+pin.file);
 const previous=proofPins.get(path.resolve(pin.file));requireValue(!previous||previous.sha256===pin.sha256,'Conflicting input hashes');
 proofPins.set(path.resolve(pin.file),{file:path.resolve(pin.file),sha256:pin.sha256});return bytes;
}
function json(pin,owner=cache){return JSON.parse(checked(pin,owner));}
const cached=(relative,sha256)=>({file:relativeFile(cache,relative),sha256});

// Exactly eleven accepted source overlays. No discovery/fallback to the tree.
const motionRoot=path.join(cache,'loading-agent/motion-instrumentation-v1/candidate');
const overlays=[
 {relative:'native_session_world.gd',file:path.join(cache,'visibility-agent/raw-world-end-tail-spans-v1/candidate/native_session_world.gd'),sha256:'c8ee824464104e38f3db58387d8ed04800f3c10b104ae7f996b8ea3345fb9d24',role:'V3 receive-tail spans'},
 {relative:'systems/network_motion.gd',file:path.join(motionRoot,'systems/network_motion.gd'),sha256:'bc89a554a934c1a7950bcfdb08788e61878e5d559cb5fc1e95be4e289e39f63e',role:'Private motion spans'},
 {relative:'systems/native_render/live_world.gd',file:path.join(motionRoot,'systems/native_render/live_world.gd'),sha256:'c9701bdd49533284588a0919c2990bd3b16832449773dd01b391c54fc4f290f5',role:'Private world motion spans'},
 {relative:'systems/native_render/live_world_support.gd',file:path.join(motionRoot,'systems/native_render/live_world_support.gd'),sha256:'216cf972297421130634aedcf68fec8a87d7c30e898df8895d9b5e37ba93b229',role:'Private support spans'},
 {relative:'systems/native_render/native_client_support_scene_parts.gd',file:path.join(motionRoot,'systems/native_render/native_client_support_scene_parts.gd'),sha256:'4eed816233109347a72316af529bab9897622eb73c8de65b447f83485e407b25',role:'Private actual support census'},
 {relative:'systems/native_mouse_cursor.gd',file:path.join(source,'systems/native_mouse_cursor.gd'),sha256:'341ffdf125fff954e91e84308a50fa9a0d098cca6366b47f7ff87ea6fd302fda',role:'Accepted cursor CPU-image reuse'},
 {relative:'systems/native_render/selection_highlight.gd',file:path.join(source,'systems/native_render/selection_highlight.gd'),sha256:'95f94ca4ba89fc828752297876fa6bc2987ad03d4f6bbef514f4baa95f569f22',role:'Accepted selection spans'},
 {relative:'systems/native_render/frame_profile.gd',file:path.join(source,'systems/native_render/frame_profile.gd'),sha256:'42d7585cd745c944a6a907dc11516994d639764d638cf1d7f7b5b041a6bcc9d0',role:'Accepted profiler accounting'},
 {relative:'systems/native_client_menu_style.gd',file:path.join(source,'systems/native_client_menu_style.gd'),sha256:'4de80e1172923f2814f319258eeda96f40649b6bb5b87f22b16be75f70a78c16',role:'Accepted single initial Theme'},
 {relative:'systems/native_render/scene_geometry.gd',file:path.join(source,'systems/native_render/scene_geometry.gd'),sha256:'1d718dfd372236afbbe894aef0a853ce0bf556aaee176adfd62173811e1a3708',role:'Accepted native unmasked support'},
 {relative:'systems/native_data/native_support_triangle.gd',file:path.join(source,'systems/native_data/native_support_triangle.gd'),sha256:'4ade06896b9578dcdf0d80194b2c33c10bb4dcec4f2012ede19489a72d6a5faf',role:'Accepted native unmasked support'},
];
const overlayMap=new Map(overlays.map(row=>[row.relative,row]));
requireValue(overlays.length===11&&overlayMap.size===11,'Exact eleven-source allowlist required');

const proofs={
 session:cached('visibility-agent/raw-world-end-tail-spans-v1/stage.json','c08bc28344199553951e495a3bd3d269464e3b1457f1d23a05c76aad4c044964'),
 sessionSyntax:cached('visibility-agent/raw-world-end-tail-current-syntax-v2/syntax-run.json','aef8b72904c010e25baf9ba40949cff82c382c89d025f144903ab55e34ab6368'),
 motionSources:cached('loading-agent/motion-instrumentation-v1/source-pins.json','c2b45b79da2d1a9ede4da707229c85166829c61c4aef464c443825aa1ccc1429'),
 motionFreeze:cached('loading-agent/motion-instrumentation-v1/freeze.json','97cdce5bcc7f0bc8b20192d6376418abf57aae6bac9fcaafd4b252280cef9d25'),
 motion:cached('loading-agent/motion-instrumentation-v1/run.json','b49c66a1a4b1bf7c9cb224ecc3eebe46c0024c6985ccf82ba8d55410ba2066f8'),
 cursorIntegration:cached('root/cursor-source-integration-v1/integration.json','465c87eb2043e2ff986f5034477ca92e53e7019e819ecdf3e35d14a12c37a6f8'),
 cursor:cached('root/mouse-cursor-cpu-image-v1/run.json','bcea3043fbaefa6b37f94700e153c0baaf0bfa9edbd16f57d0245f3895518e45'),
 selectionIntegration:cached('root/selection-profile-integration-v1/integration.json','92e35cd23f1dbeae2da72c7922413ffcb99f4215b1ed08255a1f5ccc12ab876b'),
 selection:cached('root/selection-profile-candidate-v2/run.json','4ba9ad4fca1c31c5ca91e86d87c25bd9afe031e1a06a4267745a65677c73f481'),
 supportStyleIntegration:cached('root/support-style-integration-v1/integration.json','b53c8e94ce0ac7a980df04d9f81162e56a4ea2228e2dc1b0f158f2ca53caff16'),
 supportFreeze:cached('loading-agent/support-unmasked-native-v1/freeze.json','e2994a5df27e5d9730abb6121fff2c3617a4a877652daa0d14a4bc8fc0b5f9c6'),
 supportNative:cached('loading-agent/support-unmasked-native-v1/run-native.json','03748fff7c3c210f5070215943f13f8ddffe3fb3ffcb9a6b25191b74bf724cdd'),
 supportGd:cached('loading-agent/support-unmasked-native-v1/run-gd.json','9abd83d4856fa6807fd74d495a07ebe67196e57283a85810162bad5785f085fb'),
 supportMissing:cached('loading-agent/support-unmasked-native-v1/run-missing.json','356b89bc038bd69de5f8ae16ef1cc868e87d6593664fa47dcf665e3ea9aec069'),
 supportSetup:cached('loading-agent/support-unmasked-native-v1/run-setup.json','9ddc18ea9f4f66425dea3e4471c561d62b647afdfb13e3532fc2dc20d03c6519'),
 style:cached('visibility-agent/menu-style-theme-once-v2/run.json','059ed858a4dc680d1d2d59bebac0e559ad3495f25051f4e642c0fa82e82c89ed'),
};
const basePin=cached('root/whole-character-client-v3/manifest.json',BASE_SHA);
const base=json(basePin);
requireValue(base.version===1&&base.mode==='--highlight=whole-character'&&base.parkedWorkIncluded===false&&base.engine?.sha256===ENGINE_SHA,'Immutable V3 policy differs');
requireValue(base.project===path.join(cache,'root/whole-character-client-v3/project'),'Unexpected V3 project path');
verifyClientLaunchEngine(base.engine);verifyClientLaunchDisplay(base.display);
for(const pin of [...base.engine.proof.proofPins,...base.display.proofPins])checked(pin,source);
const baseLaunchPin=cached('root/whole-character-client-v3/launch.json',BASE_LAUNCH_SHA),baseLaunch=json(baseLaunchPin);
requireValue(baseLaunch.manifestSha===BASE_SHA&&baseLaunch.manifest===basePin.file,'V3 launch ancestry differs');
for(const pin of baseLaunch.wrapperPins)checked(pin);
// Keep the old visual/capacity evidence as BASE evidence, never new acceptance.
for(const pin of [base.visualProof,base.visualProof.stage,base.recoveryProof,...base.recoveryProof.cases])checked(pin);

const basePins=new Map();const caseNames=new Set();
for(const pin of base.pins){
 const file=relativeFile(base.project,pin.relative),folded=pin.relative.toLowerCase();
 requireValue(!caseNames.has(folded),'Duplicate/case-colliding V3 path');caseNames.add(folded);
 checked({file,sha256:pin.sha256},base.project);basePins.set(pin.relative,pin);
}
requireValue(basePins.get('.cache/native-kernel/nwn-particle-kernel.dll')?.sha256===PARTICLE_SHA,'V3 particle DLL differs');
for(const overlay of overlays)requireValue(basePins.has(overlay.relative),'Overlay is not a retained V3 file: '+overlay.relative);
const overlayBytes=new Map(overlays.map(row=>[row.relative,checked(row,source)]));
const loaded=Object.fromEntries(Object.entries(proofs).map(([name,pin])=>[name,json(pin)]));

function cleanSmallRun(name,checks){
 const run=loaded[name];requireValue(run.success===true&&run.exit===0&&!run.error&&Array.isArray(run.errors)&&run.errors.length===0&&run.result?.success===true&&run.result.checks===checks&&Array.isArray(run.sourceChanged)&&run.sourceChanged.length===0&&(!run.parentChanged||run.parentChanged.length===0),'Retained small check failed: '+name);
 if(run.stage)json(run.stage);return {receipt:proofs[name],checks,scope:run.result.scope};
}
const smallChecks={sessionSyntax:cleanSmallRun('sessionSyntax',6),cursor:cleanSmallRun('cursor',29),selection:cleanSmallRun('selection',22),style:cleanSmallRun('style',46)};
requireValue(loaded.session.base.sha256===BASE_SHA&&loaded.session.source.sha256===basePins.get('native_session_world.gd').sha256&&loaded.session.candidate.sha256===overlayMap.get('native_session_world.gd').sha256&&loaded.session.checks.reverseToOriginalExact===true&&loaded.session.checks.existingFunctionalCallOrderUnchanged===true,'Session timing proof differs');
requireValue(loaded.motionSources.manifest.sha256===BASE_SHA&&loaded.motionSources.files.length===4,'Motion source ancestry differs');
for(const row of loaded.motionSources.files)requireValue(basePins.get(row.relative)?.sha256===row.before&&overlayMap.get(row.relative)?.sha256===row.after,'Motion before/after guard differs');
requireValue(loaded.motion.status===0&&!loaded.motion.error&&loaded.motion.test?.checks===47&&loaded.motion.test.errors.length===0&&loaded.motion.engineErrors.length===0&&loaded.motion.sourcePinsSha256===proofs.motionSources.sha256,'Small Motion differential differs');
smallChecks.motion={receipt:proofs.motion,checks:47,scope:'Exact Motion differential only; other instrumented World/support dependency closure remains pending'};

function integrated(name,relative){
 const rows=loaded[name].files??loaded[name].sourceFiles??[],row=rows.find(item=>item.relative===relative);
 requireValue(row?.verified===true&&row.after===overlayMap.get(relative)?.sha256,'Accepted integration differs: '+relative);return row;
}
const cursor=integrated('cursorIntegration','systems/native_mouse_cursor.gd');
const selection=integrated('selectionIntegration','systems/native_render/selection_highlight.gd');
const profiler=integrated('selectionIntegration','systems/native_render/frame_profile.gd');
const earlierProfiler=loaded.cursorIntegration.sourceFiles.find(row=>row.relative==='systems/native_render/frame_profile.gd');
requireValue(cursor.before===basePins.get(cursor.relative).sha256&&selection.before===basePins.get(selection.relative).sha256&&earlierProfiler.before===basePins.get(profiler.relative).sha256&&profiler.before===earlierProfiler.after,'Cursor/selection/profiler integration chain differs');
for(const relative of ['systems/native_render/scene_geometry.gd','systems/native_data/native_support_triangle.gd','systems/native_client_menu_style.gd']){
 const row=integrated('supportStyleIntegration',relative);requireValue(row.before===basePins.get(relative).sha256,'Support/style V3 before guard differs');
}
for(const name of ['motionFreeze','supportFreeze']){
 const freezeRoot=path.dirname(proofs[name].file);
 for(const row of loaded[name].files)checked({file:relativeFile(freezeRoot,row.relative),sha256:row.sha256});
}
requireValue(loaded.supportFreeze.totalBehaviorChecks===216&&loaded.supportFreeze.receipts.length===4,'Support freeze scope differs');
let supportTotal=0;
for(const row of loaded.supportFreeze.receipts){
 const pin=cached('loading-agent/support-unmasked-native-v1/'+row.relative,row.sha256),run=json(pin);
 requireValue(run.passed===true&&run.status===0&&!run.error&&run.test?.checks===row.checks&&run.test.errors.length===0&&equal(run.diagnostics,row.diagnostics),'Support diagnostics/checks differ: '+row.relative);
 requireValue(row.expectedFault===false?run.diagnostics.length===0:row.relative==='run-missing.json'?run.expectedDependencyFailure===true:run.expectedSetupFailure===true,'Expected support fault classification differs');supportTotal+=row.checks;
}
requireValue(supportTotal===216,'Support check total differs');
smallChecks.support={receipt:proofs.supportFreeze,normalChecks:203,expectedFaultChecks:13,scope:'Four retained small CPU runs; expected missing-library/setup diagnostics remain explicit, not ordinary clean runs'};

// Capture exactly the CURRENT bytes from V3's mutable render preferences.
// No fallback, defaults, normalization, option parsing, or live mutation.
requireValue(base.settings?.file===path.join(cache,'root/whole-character-client-v3/render-preferences.cfg')&&base.settings.mutableAfterUserLaunch===true,'Mutable V3 settings provenance differs');
const preferencesStatBefore=fs.statSync(base.settings.file),preferences=fs.readFileSync(base.settings.file),preferencesStatAfter=fs.statSync(base.settings.file);
requireValue(preferencesStatBefore.size===preferencesStatAfter.size&&preferencesStatBefore.mtimeMs===preferencesStatAfter.mtimeMs&&preferences.length===preferencesStatAfter.size,'Render preferences changed during snapshot; preserve this attempt and retry with a fresh label');
const preferencesSha=sha(preferences),capturedAt=new Date().toISOString();

const directory=path.join(cache,'root',label),project=path.join(directory,'project');
requireValue(!fs.existsSync(directory),'Existing candidate preserved; use a fresh label');
const pendingGates=[
 {id:'full-client-dependency-typing',status:'pending',scope:'Full composed GDScript dependency parse/import; extracted/per-file checks do not cover it'},
 {id:'composed-correctness',status:'pending',scope:'World/Motion/support/native bridge integration, lifetimes, callbacks and startup diagnostics'},
 {id:'headed-menu-and-exit',status:'pending',scope:'Explicitly approved menu-only readiness and clean exit; no automatic server connection'},
 {id:'cursor-and-world-visuals',status:'pending',scope:'Approved actual Windows cursor, highlight/material/world visibility compatibility'},
 {id:'user-gameplay',status:'pending',scope:'User-controlled connection, area entry and walking; no automation is authorized by this stage'},
 {id:'login-and-walk-performance',status:'pending',scope:'Controlled login-tail/walking measurements at a user-approved checkpoint; no FPS or speedup acceptance'},
];
// Reserve the fresh capsule atomically; never reuse a concurrently created one.
fs.mkdirSync(directory);
try{
 fs.mkdirSync(project);
 const pins=[],diff=[];
 for(const original of base.pins){
  const overlay=overlayMap.get(original.relative),origin=overlay??{file:relativeFile(base.project,original.relative),sha256:original.sha256};
  const bytes=overlay?overlayBytes.get(original.relative):checked(origin,base.project),target=relativeFile(project,original.relative);
  fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,bytes,{flag:'wx'});
  const actual=sha(fs.readFileSync(target));requireValue(actual===origin.sha256,'Staged bytes differ: '+original.relative);
  pins.push({...original,sha256:actual,bytes:bytes.length,overlay:Boolean(overlay),origin:overlay?'reviewed-overlay':'immutable-v3',...(overlay?{source:overlay.file,baseSha256:original.sha256}:{})});
  if(actual!==original.sha256)diff.push({relative:original.relative,before:original.sha256,after:actual,source:origin.file,role:overlay.role});
 }
 requireValue(diff.length===11&&diff.every(row=>overlayMap.has(row.relative)),'Composed project differs beyond exact eleven-source allowlist');
 const settingsFile=path.join(directory,'render-preferences.cfg');fs.writeFileSync(settingsFile,preferences,{flag:'wx'});requireValue(sha(fs.readFileSync(settingsFile))===preferencesSha,'Settings snapshot bytes differ');
 // Recheck all immutable inputs after copying; mutable preferences are the
 // deliberately captured snapshot, not a claimed continuing source lock.
 for(const pin of [...proofPins.values()])checked(pin,source);
 const projectPin=pins.find(row=>row.relative==='project.godot');requireValue(projectPin.sha256===basePins.get('project.godot').sha256,'V3 project/render settings changed');
 requireValue(pins.find(row=>row.relative==='.cache/native-kernel/nwn-particle-kernel.dll').sha256===PARTICLE_SHA,'Staged particle DLL changed');
 const inheritedRuntimePolicy={engine:base.engine,display:base.display,mode:base.mode,projectConfig:{relative:'project.godot',sha256:projectPin.sha256},particleDll:{relative:'.cache/native-kernel/nwn-particle-kernel.dll',sha256:PARTICLE_SHA},launchPolicyReference:baseLaunchPin,launcherWrapperPins:baseLaunch.wrapperPins,renderFlags:'V3 policy retained by byte-identical project configuration and pinned existing launcher reference; no replacement runtime flags or launcher emitted'};
 const settings={file:settingsFile,initialSha256:preferencesSha,mutableAfterUserLaunch:base.settings.mutableAfterUserLaunch,provenance:{sourceFile:base.settings.file,parentInitialSha256:base.settings.initialSha256,observedSha256:preferencesSha,observedBytes:preferences.length,capturedAt,sourceMutableAfterUserLaunch:true,sourceMtimeMs:preferencesStatAfter.mtimeMs,sourceReadStable:true,normalized:false}};
 const manifest={version:1,kind:'live-walk-diagnostic-stage',label,created:new Date().toISOString(),project,base:basePin,validationState:'staged-not-validated',releaseReady:false,launchState:'unlaunched',engine:base.engine,display:base.display,mode:base.mode,pins,overlays:diff,settings,inheritedRuntimePolicy,inheritedBaseEvidence:{visualProof:base.visualProof,recoveryProof:base.recoveryProof,scope:'Evidence for the immutable V3 BASE only; not visual/gameplay/performance acceptance of the eleven-overlay composition'},overlayProofs:proofs,retainedSmallChecks:{...smallChecks,checksRerunDuringStaging:false,fullClientAccepted:false},pendingGates,proofPins:[...proofPins.values()],builder:{file:builderFile,sha256:sha(fs.readFileSync(builderFile))},parkedWorkIncluded:false,particleHeaderChanged:false,projectPolicyChanged:false,engineLaunched:false,electronLaunched:false,automaticConnections:0,serverConnections:0,nativeBuilds:0,compiled:false,launchWrappersEmitted:false,performanceAccepted:false};
 const write=(file,value)=>fs.writeFileSync(file,JSON.stringify(value,null,2)+'\n',{flag:'wx'});
 write(path.join(directory,'pending-gates.json'),{validationState:manifest.validationState,releaseReady:false,pendingGates});
 write(path.join(directory,'composition.json'),{base:basePin,sourcePins:pins.length,changed:diff,unexpected:[],settings,sourceOnly:true,validated:false,launched:false});
 const manifestFile=path.join(directory,'manifest.json');write(manifestFile,manifest);
 console.log(JSON.stringify({staged:true,validated:false,launched:false,manifest:{file:manifestFile,sha256:sha(fs.readFileSync(manifestFile))},sourcePins:pins.length,overlays:diff.map(row=>row.relative),preferencesSha256:preferencesSha,pendingGates:pendingGates.map(row=>row.id),launchFilesEmitted:false}));
}catch(error){
 const file=path.join(directory,'stage-failed.json');if(!fs.existsSync(file))fs.writeFileSync(file,JSON.stringify({validationState:'stage-failed',releaseReady:false,launched:false,error:String(error?.message??error),scope:'Partial files preserved; no launch or overwrite. Use a fresh reviewed label.'},null,2)+'\n',{flag:'wx'});throw error;
}
