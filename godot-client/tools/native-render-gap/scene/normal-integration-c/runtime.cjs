// Exact accepted engine/native bundle selection; no scene/assets/credentials or subprocesses.
const fs=require('node:fs/promises'),{createReadStream}=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const relative='.tools/native-core/Godot_native_core_v7_win64.exe';
const sha256='75bc654d66aa249787ec166980a813e69f3081d98c8453fe23aeff2b07779ca6',bytes=__ENGINE_BYTES__;
const proofRelative='.tools/native-core/accepted-core-v7.json',proofSha256='__ARTIFACT_PROOF_SHA__';
const nativeSha256='879e0a9ce618ec6c77f69a39cfde4f684a94f791a398fe08d432d857d9368d24';
function resolveRenderThread(requested='default'){
 if(!['default','safe','separate'].includes(requested))throw Error('Invalid native render thread selection');
 return {requested,arguments:requested==='default'?[]:['--render-thread',requested],scope:'Engine argument only; actual rendering thread IDs are verified separately.'};
}
function acceptedRenderCore(lightInput='builtin',enabled=true){
 const flags=enabled?['--particle-scene-boundary=native','--particle-scene-direct=pod','--particle-setup-boundary=bound','--particle-hot-parameters=bound','--visibility-chain-cache=epochs']:[];
 const typed=enabled&&lightInput==='builtin';if(typed)flags.push('--light-input-read=typed','--light-input-proof=segments');
 if(enabled)flags.push('--light-pair-layer-repair=exact','--light-pair-filter=consumers','--pair-record-reuse=exact','--rig-skin-publisher=native','--skeleton-force-pass=once');
 return {version:2,enabled,typed,flags,engineSha256:enabled?sha256:null,nativeKernelSha256:nativeSha256,policy:enabled?'accepted-v7-normal-gameplay':'conservative-or-isolated',diagnosticTimers:false,scope:'Exact accepted fullB functional routes. No pacing/coarse/sparse diagnostics, motion, childless, skeleton-upload or bone-only pair defaults. Explicit standard retains conservative branches in the accepted native DLL.'};
}
async function selectPerformanceRuntime(project,requested='standard'){
 if(!['standard','verified-native'].includes(requested))throw Error('Invalid native performance runtime');
 if(requested==='standard')return null;
 if(typeof project!=='string'||!project.trim())throw Error('Performance runtime requires a project path');
 const resolved=path.resolve(project),executable=path.join(resolved,relative),stat=await fs.stat(executable);
 if(!stat.isFile()||stat.size!==bytes)throw Error('Verified native executable size changed');
 const digest=crypto.createHash('sha256');for await(const chunk of createReadStream(executable))digest.update(chunk);
 const actual=digest.digest('hex');if(actual!==sha256)throw Error('Verified native executable SHA256 changed');
 const proof=await fs.readFile(path.join(resolved,proofRelative));
 if(crypto.createHash('sha256').update(proof).digest('hex')!==proofSha256)throw Error('Accepted native bundle proof changed');
 const artifact=JSON.parse(proof);if(artifact.engineSha256!==sha256||artifact.engineBytes!==bytes||artifact.nativeKernelSha256!==nativeSha256||artifact.originalGameAssetsPacked!==false)throw Error('Accepted native bundle proof differs');
 const nativeBytes=await fs.readFile(path.join(resolved,'.cache/native-kernel/nwn-particle-kernel.dll'));
 if(crypto.createHash('sha256').update(nativeBytes).digest('hex')!==nativeSha256)throw Error('Accepted native bundle DLL changed');
 const requiredProjectFiles=[];
 for(const name of ['project.godot','.godot/global_script_class_cache.cfg']){
  let data;try{data=await fs.readFile(path.join(resolved,name));}catch{throw Error('Verified native runtime requires current project file: '+name);}
  requiredProjectFiles.push({relative:name,bytes:data.length,sha256:crypto.createHash('sha256').update(data).digest('hex')});
 }
 return {kind:'verified-native',executable,directory:path.dirname(resolved),executableSha256:actual,requiresProjectPath:true,requiredProjectFiles,
  expectedCapabilities:[
   {class:'NwnBuiltinLightInputRegistry',parent:'RefCounted',instantiable:true,methods:[{name:'dispatch',arguments:2,returns:'Dictionary'}],operations:[0,1,2,3,4,6,8,9]},
   {class:'NwnParticleSceneSnapshot',parent:'RefCounted',methods:[{name:'snapshot_nodes',arguments:2,static:true},{name:'abi_version',arguments:0,static:true}],abiVersions:{abi_version:1}},
   {class:'NwnParticleSceneBoundary',parent:'RefCounted',methods:[{name:'abi_version',arguments:0,static:true},{name:'eligibility_flags',arguments:1,static:true},{name:'global_transform',arguments:1,static:true},{name:'pose_status',arguments:0,static:true},{name:'direct_abi_version',arguments:0,static:true}],abiVersions:{abi_version:1,direct_abi_version:1}},
   {class:'NwnRigSkinPublisher',parent:'RefCounted',instantiable:true,methods:[{name:'abi_version',arguments:0,static:true},{name:'configure',arguments:1},{name:'publish',arguments:0},{name:'take_continuation',arguments:0,returns:'Dictionary'},{name:'inspect',arguments:0,returns:'Dictionary'}],abiVersions:{abi_version:2}},
   {class:'NwnFrameProbe',parent:'RefCounted',methods:[{name:'feature_totals',arguments:0,static:true,returns:'Dictionary'}]},
   {class:'NwnFramePacing',parent:'RefCounted',methods:[{name:'snapshot',arguments:1,static:true,returns:'Dictionary'}]}
  ],
  selectionEvidence:{revision:'verified-native-normal-bundle-v3',verification:'Exact engine/native SHA256, engine byte count and accepted component proof',executableBytes:bytes,sourceCommit:'ed1daf0bf001b61586d9930840f2f1394092c079',engineVersion:{major:4,minor:7,patch:2,status:'stable',build:'custom_build',hash:'unknown'},pathOverridesEnabled:true,sourcePolicy:'Caller current project supplied with --path and --script; normal-preset validation remains distinct from installed promotion',particleExtensionPolicy:'Exact accepted HotC DLL plus corresponding native sources; conservative flag-absent branches retained',referenceEngineDescriptor:{relative:proofRelative,sha256:proofSha256}}
 };
}
module.exports={selectPerformanceRuntime,resolveRenderThread,acceptedRenderCore};
