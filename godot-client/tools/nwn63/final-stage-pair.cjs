'use strict';
// Coordinator-only NWN-63 final source pair. Never launches a client.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const hash=file=>sha(fs.readFileSync(file));
const fixed={
 options:['--performance-runtime=verified-native','--render-profile=gameplay','--detailed-profiling=off'],
 engineSha256:'753b3e188068efaf865bda3abd6322ebe44e3a98ef2f5d199c8af1a78624c98b',
 kernelSha256:'485741af15f0581a3c60c0f9a8ae738888eba08716c7a5c2c2d1bd550828963d',
 preferences:{relative:'.cache/nwn63/frame-input-live-graphics-e/preference-seeds.json',sha256:'52c42287993dd0fe13d699fe252bf1b86549ff5da1dc7dfc5bd17c79609d99a4'},
 driverRelative:'tools/replay-native-loading.mjs',
 capture:'C:/Users/Niflheim/AppData/Roaming/nwn-model-viewer-research/native-loading-recordings/capture-YaH3xf',
 recordingSha256:'1913892cd42db0f68dfa1b0edbdd37be4c380bdda50c95c178dc4ca2ba38a463',
 timelineSha256:'6ce44bfe52a7bd8c3b08e936206360847cd3bb1ec1713bd1d21c7304882d3920'
};
const rel=name=>typeof name==='string'&&name.length>0&&!path.isAbsolute(name)&&!name.split(/[\\/]/).some(part=>!part||part==='.'||part==='..');
const pinned=(file,want)=>{assert.match(want,/^[a-f0-9]{64}$/);assert.equal(hash(file),want,'Pin changed: '+file);};
function manifest(file,checkCurrent=true){
 const bytes=fs.readFileSync(file),m=JSON.parse(bytes);assert.equal(m.version,1);assert.equal(m.complete,true,'Frozen manifest is incomplete');
 assert.match(m.label,/^[a-z0-9][a-z0-9-]{0,50}$/);for(const key of ['candidateSourceIdentitySha256','candidateWorldSha256','candidateKeyboardSha256','driverSha256'])assert.match(m[key],/^[a-f0-9]{64}$/);
 assert(Array.isArray(m.collisionReversals)&&m.collisionReversals.length>0&&m.collisionReversals.length<=8,'Exact collision reversals required');
 const seen=new Set();for(const row of m.collisionReversals){
  assert(rel(row.relative)&&row.relative.startsWith('systems/native_render/')&&row.relative.endsWith('.gd'),'Collision source path required');
  assert(!seen.has(row.relative),'Duplicate collision path');seen.add(row.relative);
  assert(path.isAbsolute(row.controlFile),'Frozen collision control path required');
  pinned(row.controlFile,row.controlSha256);if(checkCurrent)pinned(path.join(root,row.relative),row.candidateSha256);
  assert.notEqual(row.controlSha256,row.candidateSha256,'Collision reversal must change bytes');
 }
 const identity=checkCurrent?require(path.join(root,'tools/native-feature-manifest.cjs')).sourceIdentity(root):null;
 if(checkCurrent){
  assert.equal(identity.sha256,m.candidateSourceIdentitySha256,'Candidate source changed after freeze');
  pinned(path.join(root,'native_live_world.gd'),m.candidateWorldSha256);
  pinned(path.join(root,'systems/native_keyboard.gd'),m.candidateKeyboardSha256);
  const world=fs.readFileSync(path.join(root,'native_live_world.gd'),'utf8');
  const seam='bool(ProjectSettings.get_setting("nwn/private/keyboard_frame_admission",true))';
  assert.equal(world.split(seam).length-1,2,'Expected exactly two coordinator default-on sites');
 }
 pinned(path.join(root,'.tools/native-core/Godot_native_core_e_win64.exe'),fixed.engineSha256);
 pinned(path.join(root,'.cache/native-kernel/nwn-particle-kernel.dll'),fixed.kernelSha256);
 pinned(path.join(root,fixed.preferences.relative),fixed.preferences.sha256);
 pinned(path.join(root,fixed.driverRelative),m.driverSha256);
 const seeds=JSON.parse(fs.readFileSync(path.join(root,fixed.preferences.relative)));
 assert.deepEqual(seeds.expected,{gamma:1.2,particles:true,fovDegrees:45,compactScenery:true});
 const helper=require(path.join(root,'tools/native-production-selection.cjs'));helper.preferenceSeeds(seeds);
 const recording=path.join(fixed.capture,'recording.json'),timeline=path.join(fixed.capture,'timeline.jsonl');
 pinned(recording,fixed.recordingSha256);pinned(timeline,fixed.timelineSha256);
 const scene=JSON.parse(fs.readFileSync(recording));
 assert.equal(scene.complete,true);assert.equal(scene.timelineSha256,fixed.timelineSha256);
 return {m,manifestSha256:sha(bytes),identity,seeds,scene:{capture:fixed.capture,recordingSha256:fixed.recordingSha256,timelineSha256:fixed.timelineSha256,events:scene.events,generation:2}};
}
function linkTree(from,to){
 for(const entry of fs.readdirSync(from,{withFileTypes:true})){
  assert(!entry.isSymbolicLink(),'Source symlink disallowed');const source=path.join(from,entry.name),target=path.join(to,entry.name);
  if(entry.isDirectory()){fs.mkdirSync(target,{recursive:true});linkTree(source,target);}
  else{assert(entry.isFile());fs.linkSync(source,target);}
 }
}
function replaceFile(file,bytes){fs.unlinkSync(file);fs.writeFileSync(file,bytes,{flag:'wx'});}
function entries(directory){
 const result=new Map();function walk(base,relative=''){
  for(const entry of fs.readdirSync(base,{withFileTypes:true})){
   assert(!entry.isSymbolicLink());const name=relative?relative+'/'+entry.name:entry.name,source=path.join(base,entry.name);
   if(entry.isDirectory())walk(source,name);else result.set(name,hash(source));
  }
 }walk(directory);return result;
}
function compare(control,candidate,wanted){
 const a=entries(control),b=entries(candidate);assert.deepEqual([...a.keys()].sort(),[...b.keys()].sort(),'Source closure differs');
 const differences=[...a.keys()].filter(name=>a.get(name)!==b.get(name)).sort();assert.deepEqual(differences,[...wanted].sort(),'Unreviewed source difference');return differences;
}
async function verifyStage(receiptFile){
 const receipt=JSON.parse(fs.readFileSync(receiptFile));assert.equal(receipt.version,1);assert.equal(receipt.issue,'NWN-63');
 pinned(receipt.manifestFile,receipt.manifestSha256);
 const prior=manifest(receipt.manifestFile,false);assert.equal(prior.m.candidateSourceIdentitySha256,receipt.candidateSourceIdentitySha256);
 assert.equal(path.resolve(receipt.driver.file),path.join(root,fixed.driverRelative),'Final replay driver changed');
 assert.equal(receipt.driver.sha256,prior.m.driverSha256,'Final replay driver pin changed');
 const helper=require(path.join(root,'tools/native-production-selection.cjs'));
 const selections={};for(const leg of ['control','candidate']){
  const row=receipt.selections[leg];pinned(row.file,row.sha256);selections[leg]=await helper.readProductionSelection(row.file,row.sha256);
  assert.equal(selections[leg].runtime.executableSha256,fixed.engineSha256);
  assert.equal(selections[leg].preferences.render.sha256,prior.seeds.render.sha256);
  assert.equal(selections[leg].preferences.layout.sha256,prior.seeds.layout.sha256);
  assert.deepEqual(selections[leg].options,fixed.options);
 }
 assert.deepEqual(selections.control.flags,selections.candidate.flags);
 assert.equal(selections.control.runtime.executableSha256,selections.candidate.runtime.executableSha256);
 const control=selections.control.pins.map(x=>[x.relative,x.sha256]),candidate=new Map(selections.candidate.pins.map(x=>[x.relative,x.sha256]));
 const differences=control.filter(([name,sum])=>sum!==candidate.get(name)).map(([name])=>name).sort();
 assert.deepEqual(differences,receipt.differentSources);
 assert.deepEqual(differences,['native_live_world.gd',...prior.m.collisionReversals.map(x=>x.relative)].sort());
 assert.equal(selections.candidate.mainSourceIdentity.sha256,prior.m.candidateSourceIdentitySha256);
 pinned(path.join(selections.candidate.sourceProject,'native_live_world.gd'),prior.m.candidateWorldSha256);
 const candidateWorld=fs.readFileSync(path.join(selections.candidate.sourceProject,'native_live_world.gd'),'utf8');
 const seam='bool(ProjectSettings.get_setting("nwn/private/keyboard_frame_admission",true))';
 assert.equal(candidateWorld.split(seam).length-1,2);
 assert.equal(fs.readFileSync(path.join(selections.control.sourceProject,'native_live_world.gd'),'utf8'),candidateWorld.replaceAll(seam,'bool(ProjectSettings.get_setting("nwn/private/keyboard_frame_admission",false))'));
 for(const row of prior.m.collisionReversals){
  pinned(path.join(selections.candidate.sourceProject,row.relative),row.candidateSha256);
  pinned(path.join(selections.control.sourceProject,row.relative),row.controlSha256);
 }
 assert.equal(hash(path.join(selections.candidate.sourceProject,'systems/native_keyboard.gd')),prior.m.candidateKeyboardSha256);
 assert.equal(hash(path.join(selections.control.sourceProject,'systems/native_keyboard.gd')),prior.m.candidateKeyboardSha256);
 return {status:'verified',noClientStarts:true,receipt:receiptFile,sourceDifferences:differences,engineSha256:fixed.engineSha256,scene:prior.scene};
}
async function stage(file){
 assert.equal(process.env.NWN63_FINAL_FROZEN,'coordinator','Coordinator frozen-source gate missing');
 const pre=manifest(file),m=pre.m,scope=path.join(root,'.cache/nwn63/final-'+m.label);
 assert(!fs.existsSync(scope),'Fresh final stage label required');
 for(const label of [`nwn63-final-${m.label}-control-a`,`nwn63-final-${m.label}-candidate-a`,`nwn63-final-${m.label}-candidate-b`,`nwn63-final-${m.label}-control-b`])assert(!fs.existsSync(path.join(root,'reports',label+'.json')),'Fresh report labels required');
 const helper=require(path.join(root,'tools/native-production-selection.cjs'));
 const seed=await helper.stageProductionSelection({project:root,label:`nwn63-final-${m.label}-seed`,argv:fixed.options,preferenceSeeds:pre.seeds,env:{}});
 assert.equal(seed.selection.mainSourceIdentity.sha256,m.candidateSourceIdentitySha256);
 fs.mkdirSync(scope,{recursive:true});const inputs={};
 for(const leg of ['candidate','control']){
  inputs[leg]=path.join(scope,leg+'-input');fs.mkdirSync(inputs[leg]);
  linkTree(seed.selection.sourceProject,inputs[leg]);
  for(const relative of ['.tools/native-core/Godot_native_core_e_win64.exe','.tools/native-core/accepted-core-e.json']){
   const target=path.join(inputs[leg],relative);fs.mkdirSync(path.dirname(target),{recursive:true});fs.linkSync(path.join(root,relative),target);
  }
 }
 const controlWorld=path.join(inputs.control,'native_live_world.gd');
 const original=fs.readFileSync(controlWorld,'utf8'),seam='bool(ProjectSettings.get_setting("nwn/private/keyboard_frame_admission",true))';
 assert.equal(original.split(seam).length-1,2);replaceFile(controlWorld,Buffer.from(original.replaceAll(seam,'bool(ProjectSettings.get_setting("nwn/private/keyboard_frame_admission",false))')));
 for(const row of m.collisionReversals)replaceFile(path.join(inputs.control,row.relative),fs.readFileSync(row.controlFile));
 const wanted=['native_live_world.gd',...m.collisionReversals.map(x=>x.relative)].sort();
 assert.deepEqual(compare(inputs.control,inputs.candidate,wanted),wanted);
 const selections={};for(const leg of ['control','candidate']){
  const result=await helper.stageProductionSelection({project:inputs[leg],label:`nwn63-final-${m.label}-${leg}`,argv:fixed.options,preferenceSeeds:pre.seeds,env:{}});
  selections[leg]={file:result.file,sha256:result.sha256};
 }
 assert.equal(require(path.join(root,'tools/native-feature-manifest.cjs')).sourceIdentity(root).sha256,m.candidateSourceIdentitySha256,'Production source changed during staging');
 const receipt={version:1,issue:'NWN-63',label:m.label,manifestFile:path.resolve(file),manifestSha256:pre.manifestSha256,candidateSourceIdentitySha256:m.candidateSourceIdentitySha256,seed:{file:seed.file,sha256:seed.sha256},inputs,selections,differentSources:wanted,scene:pre.scene,driver:{file:path.join(root,fixed.driverRelative),sha256:m.driverSha256},preferences:{file:path.join(root,fixed.preferences.relative),sha256:fixed.preferences.sha256},noClientStarts:true};
 const receiptFile=path.join(scope,'pair.json');fs.writeFileSync(receiptFile,JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});
 return await verifyStage(receiptFile);
}
async function main(){
 const [mode,...args]=process.argv.slice(2),arg=name=>args.find(x=>x.startsWith('--'+name+'='))?.slice(name.length+3);
 assert(args.every(x=>x.startsWith('--manifest=')||x.startsWith('--receipt=')||x.startsWith('--label=')),'Unexpected argument');
 if(mode==='draft'){
  const label=arg('label');assert.match(label,/^[a-z0-9][a-z0-9-]{0,50}$/);
  const relative='systems/native_render/drive_collision_indexed.gd';
  const controlFile=path.join(root,'.cache/nwn63/collision-group-index-a/control.gd');
  const draft={version:1,complete:false,label,candidateSourceIdentitySha256:require(path.join(root,'tools/native-feature-manifest.cjs')).sourceIdentity(root).sha256,candidateWorldSha256:hash(path.join(root,'native_live_world.gd')),candidateKeyboardSha256:hash(path.join(root,'systems/native_keyboard.gd')),driverSha256:hash(path.join(root,fixed.driverRelative)),collisionReversals:[{relative,candidateSha256:hash(path.join(root,relative)),controlFile,controlSha256:hash(controlFile)}]};
  console.log(JSON.stringify(draft,null,2));return;
 }
 if(mode==='verify-only'&&arg('manifest')){const pre=manifest(path.resolve(arg('manifest')));console.log(JSON.stringify({status:'ready-to-stage',noClientStarts:true,label:pre.m.label,sourceIdentity:pre.identity.sha256,scene:pre.scene}));return;}
 if(mode==='verify-only'&&arg('receipt')){console.log(JSON.stringify(await verifyStage(path.resolve(arg('receipt')))));return;}
 if(mode==='stage'&&arg('manifest')){console.log(JSON.stringify(await stage(path.resolve(arg('manifest')))));return;}
 throw Error('Use verify-only --manifest=FILE, stage --manifest=FILE, or verify-only --receipt=FILE');
}
module.exports={verifyStage};
if(require.main===module)main().catch(error=>{console.error(error.stack);process.exitCode=1;});
