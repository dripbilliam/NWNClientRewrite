// Exact accepted engine/native bundle selection; no scene/assets/credentials or subprocesses.
const fs=require('node:fs/promises'),{createReadStream}=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const relative=".tools/native-core/Godot_native_core_d_win64.exe";
const sha256="10b24711d277f745ad72cc504b6a3e573c12bb1ce1be7fd8545faabab82b9f13",bytes=90973184;
const proofRelative=".tools/native-core/accepted-core-d.json",proofSha256="5b76f260b5c65f18fcaa332ce806f2843325e08ec218f751652dd545689c579e";
const nativeSha256="485741af15f0581a3c60c0f9a8ae738888eba08716c7a5c2c2d1bd550828963d";
function resolveRenderThread(requested='default'){
 if(!['default','safe','separate'].includes(requested))throw Error('Invalid native render thread selection');
 return {requested,arguments:requested==='default'?[]:['--render-thread',requested],scope:'Engine argument only; actual rendering thread IDs are verified separately.'};
}
function acceptedRenderCore(lightInput="builtin",enabled=true){
 const typed=enabled&&lightInput==="builtin",typedFlags=new Set(["--light-input-read=typed","--light-input-proof=segments","--light-dictionary-read=single","--light-input-lifetime=guarded","--light-member-read=indices"]);
 const flags=enabled?["--particle-scene-boundary=native","--particle-scene-direct=pod","--particle-setup-boundary=bound","--particle-hot-parameters=bound","--visibility-chain-cache=epochs","--light-input-read=typed","--light-input-proof=segments","--light-pair-layer-repair=exact","--light-pair-filter=consumers","--pair-record-reuse=exact","--rig-skin-publisher=native","--skeleton-force-pass=once","--particle-resident-text=borrow","--particle-empty-clips=skip","--light-dictionary-read=single","--light-input-lifetime=guarded"].filter(flag=>typed||!typedFlags.has(flag)):[];
 return {version:3,enabled,typed,flags,engineSha256:enabled?sha256:null,nativeKernelSha256:nativeSha256,policy:enabled?"accepted-normal-combined-d":"conservative-or-isolated",diagnosticTimers:false,scope:"Exact selected component bundle. Diagnostic timers OFF; explicit conservative and script-light choices retain their existing branches."};
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
  selectionEvidence:{sourceClosure:artifact.engineBuildProof,revision:'verified-native-normal-bundle-d',verification:'Exact engine/native SHA256, engine byte count and accepted component proof',executableBytes:bytes,sourceCommit:'ed1daf0bf001b61586d9930840f2f1394092c079',engineVersion:{major:4,minor:7,patch:2,status:'stable',build:'custom_build',hash:'unknown'},pathOverridesEnabled:true,sourcePolicy:'Caller current project supplied with --path and --script; normal-preset validation remains distinct from installed promotion',particleExtensionPolicy:'Exact accepted combined-b DLL plus corresponding native sources; conservative flag-absent branches retained',referenceEngineDescriptor:{relative:proofRelative,sha256:proofSha256}}
 };
}
module.exports={selectPerformanceRuntime,resolveRenderThread,acceptedRenderCore};
