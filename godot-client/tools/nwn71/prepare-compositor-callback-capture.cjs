'use strict';
// Prepare one original-asset diagnostic replay with the isolated Tracy engine.
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../..');
const cache = path.join(root, '.cache/nwn71');
const parentFile = path.join(cache, 'scene-cull-entry-d/preparation.json');
const parent = JSON.parse(fs.readFileSync(parentFile, 'utf8'));
const buildFile = path.join(cache, 'compositor-callback-a/build-receipt-v2.json');
const build = JSON.parse(fs.readFileSync(buildFile, 'utf8'));
const out = path.join(cache, 'compositor-callback-capture-v2');
const input = path.join(out, 'input');
const hash = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
assert.equal(hash(parentFile), '6a127d373afa46e5deb503232a6651812590b5da51c00b09c7634265a714a54b');
assert(build.success && build.exit === 0 && build.sourceUnchanged && build.parentUnchanged);
assert.equal(hash(build.binary.file), build.binary.sha256);
assert.equal(hash(parent.runtime.engine), parent.runtime.engineSha256);
assert(!fs.existsSync(out), 'Preserve prior capture input');
const disk = fs.statfsSync(root,{bigint:true});
const free = disk.bavail*disk.bsize;
assert(free > 10n*1024n*1024n*1024n, 'Disk free floor before 500 MiB input copy');
fs.mkdirSync(out, {recursive:true});
fs.cpSync(parent.input, input, {recursive:true,errorOnExist:true,force:false});
const engineRelative = path.relative(parent.input,parent.runtime.engine);
const engine = path.join(input,engineRelative);
const descriptorRelative = '.tools/native-tracy/runtime.json';
const descriptorFile = path.join(input,descriptorRelative);
const originalDescriptorFile = path.join(parent.input,descriptorRelative);
const originalDescriptor = JSON.parse(fs.readFileSync(originalDescriptorFile,'utf8'));
assert.equal(originalDescriptor.engineSha256,parent.runtime.engineSha256);
const descriptor = {...originalDescriptor, engineSha256:build.binary.sha256, engineBytes:build.binary.bytes,
  engineBuildProof:{isolatedCompositorBuild:{file:buildFile,sha256:hash(buildFile)},
    isolatedPlan:{file:path.join(cache,'compositor-callback-a/plan.json'),sha256:hash(path.join(cache,'compositor-callback-a/plan.json'))},
    priorDiagnostic:originalDescriptor.engineBuildProof,
    delta:'Private Tracy callback identity zones; no intended rendering behavior change. Private source includes unrelated shared-scratch changes relative to the previous diagnostic and is not performance-comparable.'}};
fs.writeFileSync(descriptorFile,JSON.stringify(descriptor,null,2)+'\n');
fs.copyFileSync(build.binary.file,engine);
const runtimeFile=path.join(input,'tools/native-performance-runtime.cjs');
let runtime=fs.readFileSync(runtimeFile,'utf8');
function once(before,after){assert.equal(runtime.split(before).length,2,before);runtime=runtime.replace(before,after);}
once('const sha256="'+originalDescriptor.engineSha256+'",bytes='+originalDescriptor.engineBytes+';',
  'const sha256="'+descriptor.engineSha256+'",bytes='+descriptor.engineBytes+';');
once('proofSha256="'+hash(originalDescriptorFile)+'"','proofSha256="'+hash(descriptorFile)+'"');
fs.writeFileSync(runtimeFile,runtime);
const helper=require(path.join(root,'tools/native-production-selection.cjs'));
(async()=>{
  const selection=await helper.stageProductionSelection({project:input,label:'compositor-callback-v2',
    argv:['--performance-runtime=verified-native','--render-profile=gameplay','--detailed-profiling=off'],
    preferenceSeeds:parent.preferences,env:{}});
  await helper.readProductionSelection(selection.file,selection.sha256);
  assert.equal(selection.selection.runtime.executableSha256,build.binary.sha256);
  assert.equal(selection.selection.renderCore.nativeKernelSha256,parent.runtime.dllSha256);
  const prep={schema:'nwn71-compositor-callback-capture-v1', parent:{file:parentFile,sha256:hash(parentFile)},
    build:{file:buildFile,sha256:hash(buildFile)},input,
    changedFromParent:[engineRelative,descriptorRelative,'tools/native-performance-runtime.cjs'],
    selection:{file:selection.file,sha256:selection.sha256},
    engine:{file:engine,sha256:hash(engine)},nativeDllSha256:parent.runtime.dllSha256,
    flags:selection.selection.flags,profiling:selection.selection.profiling,
    purpose:'One original-asset scene correctness capture to identify compositor callback. No FPS or comparative timing inference.'};
  const prepFile=path.join(out,'preparation.json');fs.writeFileSync(prepFile,JSON.stringify(prep,null,2)+'\n',{flag:'wx'});
  const parentProposal=JSON.parse(fs.readFileSync(path.join(cache,'scene-cull-entry-d/run-proposal.json'),'utf8'));
  const captureDir=path.join(cache,'capture-compositor-callback-v2');
  const proposal={...parentProposal,
    schema:'nwn71-compositor-callback-capture-proposal-v1',
    preparation:{file:prepFile,sha256:hash(prepFile)},selection:{file:selection.file,sha256:selection.sha256},
    replay:{...parentProposal.replay,driverSha256:hash(path.join(root,'tools/replay-native-loading.mjs')),arguments:parentProposal.replay.arguments.map(a=>
      a.startsWith('--production-selection=')?'--production-selection='+selection.file:
      a.startsWith('--production-selection-sha256=')?'--production-selection-sha256='+selection.sha256:
      a==='--run=nwn71-scene-cull-entry-d'?'--run=nwn71-compositor-callback-v2':a)},
    capture:{...parentProposal.capture,arguments:parentProposal.capture.arguments.map(a=>a.endsWith('capture-scene-cull-entry-d\\entry.tracy')?path.join(captureDir,'entry.tracy'):a)},
    engine:{sha256:build.binary.sha256,kind:'isolated-private-tracy'},
    scope:'Callback identity correctness only; no FPS, no comparative timing inference.'};
  const proposalFile=path.join(out,'run-proposal.json');fs.writeFileSync(proposalFile,JSON.stringify(proposal,null,2)+'\n',{flag:'wx'});
  console.log(JSON.stringify({prepFile,prepSha256:hash(prepFile),proposalFile,proposalSha256:hash(proposalFile),engineSha256:build.binary.sha256,launches:0}));
})().catch(e=>{console.error(e.stack);process.exitCode=1});
