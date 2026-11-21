'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),stage=path.join(root,'.cache/nwn71/gamma-entry-a');
const project=path.join(root,'.cache/nwn71/gamma-original-pixels-a/project');
const parentFile=path.join(root,'.cache/nwn71/scene-cull-entry-d/preparation.json');
const parent=JSON.parse(fs.readFileSync(parentFile,'utf8'));
const baseProposal=JSON.parse(fs.readFileSync(path.join(root,'.cache/nwn71/scene-cull-entry-d/run-proposal.json'),'utf8'));
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const gamma='systems/native_render/native_gamma_effect.gd';
assert.equal(sha(parentFile),'6a127d373afa46e5deb503232a6651812590b5da51c00b09c7634265a714a54b');
assert.equal(sha(path.join(project,gamma)),sha(path.join(root,gamma)));
assert.equal(sha(path.join(project,'.tools/native-tracy/Godot_native_d_tracy_win64.exe')),parent.runtime.engineSha256);
assert(!fs.existsSync(stage),'Preserve prior entry check');fs.mkdirSync(stage,{recursive:true});
const helper=require(path.join(root,'tools/native-production-selection.cjs'));
(async()=>{
 const runs=[];
 for(const mode of ['off','on']){
  const label=`nwn71-gamma-entry-${mode}`;
  const selected=await helper.stageProductionSelection({project,label,argv:['--performance-runtime=verified-native','--render-profile=gameplay','--detailed-profiling=off'],preferenceSeeds:parent.preferences,env:{}});
  await helper.readProductionSelection(selected.file,selected.sha256);
  assert.equal(selected.selection.runtime.executableSha256,parent.runtime.engineSha256);
  assert.equal(selected.selection.renderCore.nativeKernelSha256,parent.runtime.dllSha256);
  const output=path.join(stage,mode),trace=path.join(output,'entry.tracy');
  const args=baseProposal.replay.arguments.map(a=>a.startsWith('--production-selection=')?'--production-selection='+selected.file:
    a.startsWith('--production-selection-sha256=')?'--production-selection-sha256='+selected.sha256:
    a.startsWith('--duration-ms=')?'--duration-ms=5000':a.startsWith('--run=')?'--run='+label:a);
  const captureArgs=baseProposal.capture.arguments.map(a=>a.endsWith('capture-scene-cull-entry-d\\entry.tracy')?trace:a);
  runs.push({mode,label,output,selection:{file:selected.file,sha256:selected.sha256},replay:{executable:baseProposal.replay.executable,arguments:args},capture:{executable:baseProposal.capture.executable,arguments:captureArgs}});
 }
 const plan={schema:'nwn71-gamma-entry-correctness-v1',project,gamma:{file:path.join(project,gamma),sha256:sha(path.join(project,gamma))},
  priorGammaSha256:sha(path.join(root,'.cache/nwn71/scene-cull-entry-d/input',gamma)),
  engine:{file:path.join(project,'.tools/native-tracy/Godot_native_d_tracy_win64.exe'),sha256:parent.runtime.engineSha256},
  nativeKernelSha256:parent.runtime.dllSha256,driver:{file:path.join(root,'tools/replay-native-loading.mjs'),sha256:sha(path.join(root,'tools/replay-native-loading.mjs'))},
  captureCliSha256:baseProposal.capture.sha256,runs,
  scope:'Two original-entry correctness/Tracy startup observations, prewarm opt-in off/on. Do not compute FPS or claim matched performance.'};
 const file=path.join(stage,'plan.json');fs.writeFileSync(file,JSON.stringify(plan,null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({plan:file,sha256:sha(file),gammaSha256:plan.gamma.sha256,engineSha256:plan.engine.sha256,runs:runs.map(r=>({mode:r.mode,selection:r.selection.sha256}))}));
})().catch(e=>{console.error(e.stack);process.exitCode=1});
