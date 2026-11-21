'use strict';
// Install a separately named, byte-verified light-module build. Core D stays intact.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const project=path.resolve(__dirname,'../../../..'),hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const read=r=>JSON.parse(fs.readFileSync(path.join(project,r),'utf8'));
const pin=r=>{const b=fs.readFileSync(path.join(project,r));return {relative:r,sha256:hash(b),bytes:b.length};};
const save=(r,o)=>fs.writeFileSync(path.join(project,r),JSON.stringify(o,null,2)+'\n',{flag:'wx'});
const buildRelative='.cache/native-render-gap/scene/nwn66-engine-c/receipt.json',build=read(buildRelative);
assert(build.success&&build.originalInputsUnchanged&&!build.sharedOutputsChanged);
assert.equal(build.acceptedDControl.sha256,'10b24711d277f745ad72cc504b6a3e573c12bb1ce1be7fd8545faabab82b9f13');
assert.equal(build.control.sha256,build.controlAfter.sha256);
const engineRelative='.tools/native-core/Godot_native_core_e_win64.exe',proofRelative='.tools/native-core/accepted-core-e.json';
const candidate=fs.readFileSync(build.candidate.file);assert.equal(hash(candidate),'753b3e188068efaf865bda3abd6322ebe44e3a98ef2f5d199c8af1a78624c98b');assert.equal(candidate.length,build.candidate.bytes);
const testNames=['baseline-c1','optimized-c1','optimized-c2','baseline-c2','world-reference-a','world-optimized-c','guarded-c-ordinary','guarded-c-indices','guarded-c-reference'];
const tests=testNames.map(name=>{const relative='.cache/nwn66-light-input/'+name+'.json',t=read(relative);assert(t.success);return {name,...pin(relative),checks:Array.isArray(t.checks)?t.checks.length:t.checks,benchmark:t.benchmark,fastRows:t.fast_rows};});
const observations=name=>read('.cache/nwn66-light-input/'+name+'.json').observations;
for(const name of testNames.slice(1,4))assert.deepEqual(observations(name),observations('baseline-c1'));
assert.deepEqual(observations('world-optimized-c'),observations('world-reference-a'));
const componentRelative='.cache/nwn66-light-input/component-acceptance.json';
const sources=['light_input_registry.cpp','light_input_registry.h'].map(name=>{
 const r='tools/native-render-gap/scene/light-unchanged-input/'+name,p=pin(r),frozen=build.sourceEvidence.files.find(row=>path.basename(row.file)===name);assert.equal(p.sha256,frozen.sha256);return p;
});
save(componentRelative,{version:1,issue:'NWN-66',success:true,build:pin(buildRelative),tests,sources,
 scope:'Normal uninstrumented engine component A-B-B-A and actual Focus/Point/history/state equivalence; guarded lifetime regressions. No whole-client FPS, live Arelith or loading-latency claim.',
 stationary:{lights:600,oldMedianUs:[241,240],newMedianUs:[111,111],oldP95Us:[289,293],newP95Us:[134,140]},
 animated:{oldMedianUs:[244,243],newMedianUs:[114,114]},
 behavior:'Still validates live transforms, properties, metadata, camera and lifetime. Reuses unchanged input rows without repeated staging/commit or member/key lookup. Unknown or changed inputs take the existing guarded path.'});
const old=read('.tools/native-core/accepted-core-d.json');
assert.equal(pin('.tools/native-core/Godot_native_core_d_win64.exe').sha256,old.engineSha256);
assert.equal(pin('.cache/native-kernel/nwn-particle-kernel.dll').sha256,old.nativeKernelSha256);
const rollbackRelative='.tools/native-core/native-performance-runtime-core-d.cjs';
fs.copyFileSync(path.join(project,'tools/native-performance-runtime.cjs'),path.join(project,rollbackRelative),fs.constants.COPYFILE_EXCL);
fs.writeFileSync(path.join(project,engineRelative),candidate,{flag:'wx'});
save(proofRelative,{...old,engineSha256:build.candidate.sha256,engineBytes:build.candidate.bytes,
 acceptedReceipts:[...old.acceptedReceipts,pin(componentRelative)],
 production:false,scope:'Core D bundle with NWN-66 unchanged-light-input optimization; locally accepted component behavior and performance. Whole-client Arelith/FPS acceptance remains separate.',
 predecessor:{...pin('.tools/native-core/accepted-core-d.json'),engine:pin('.tools/native-core/Godot_native_core_d_win64.exe'),runtimeSelector:pin(rollbackRelative)},
 engineBuildProof:{kind:'private-manual-light-module-engine',receipt:pin(buildRelative),sources,sourceEvidence:build.sourceEvidence,scope:'Exact controlled two-translation-unit replacement. Original and Core D byte-identical reconstruction controls passed; no full SCons build claim.'}});
const proof=pin(proofRelative),runtimeFile=path.join(project,'tools/native-performance-runtime.cjs');
let source=fs.readFileSync(runtimeFile,'utf8');
function one(before,after){assert.equal(source.split(before).length-1,1);source=source.replace(before,after);}
one('const relative=".tools/native-core/Godot_native_core_d_win64.exe";','const relative='+JSON.stringify(engineRelative)+';');
one('const sha256="'+old.engineSha256+'",bytes='+old.engineBytes+';','const sha256="'+build.candidate.sha256+'",bytes='+build.candidate.bytes+';');
one('const proofRelative=".tools/native-core/accepted-core-d.json",proofSha256="'+pin('.tools/native-core/accepted-core-d.json').sha256+'";','const proofRelative='+JSON.stringify(proofRelative)+',proofSha256="'+proof.sha256+'";');
one('accepted-normal-combined-d','accepted-normal-combined-e');one('verified-native-normal-bundle-d','verified-native-normal-bundle-e');
fs.writeFileSync(runtimeFile,source);
save('.cache/nwn66-light-input/selection.json',{version:1,issue:'NWN-66',engine:pin(engineRelative),descriptor:proof,component:pin(componentRelative),runtimeSelector:pin('tools/native-performance-runtime.cjs'),rollbackSelector:pin(rollbackRelative),functionalFlags:old.fullFunctionalFlags,scope:'Normal launcher selects Core E; Core D and CPU particle kernel preserved. Startup acceptance recorded separately.'});
console.log(JSON.stringify({success:true,engine:pin(engineRelative),descriptor:proof,checks:tests.map(t=>({name:t.name,checks:t.checks})),rollback:rollbackRelative}));
