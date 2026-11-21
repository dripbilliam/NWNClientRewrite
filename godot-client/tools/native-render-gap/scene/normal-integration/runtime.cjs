// Exact accepted render-core executable selection; current project remains live.
// No scene preparation, game assets, credentials, subprocess or package loading.
const fs=require('node:fs/promises'),{createReadStream}=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const relative='.tools/native-core/Godot_native_core_v4_1_win64.exe';
const sha256='5713d014f2d1a0c7d479720176fbe8081e9e6254c693b9b5b244676f3afafb0d',bytes=90911744;
const proofRelative='.tools/native-core/accepted-core-v4_1.json',proofSha256='__ARTIFACT_PROOF_SHA__';
function resolveRenderThread(requested='default'){
 if(!['default','safe','separate'].includes(requested))throw Error('Invalid native render thread selection');
 return {requested,arguments:requested==='default'?[]:['--render-thread',requested],scope:'Engine argument only; actual rendering thread IDs are verified separately.'};
}
function acceptedRenderCore(lightInput='builtin',enabled=true){
 const flags=enabled?['--light-pair-layer-repair=exact','--light-pair-filter=consumers','--pair-record-reuse=exact']:[];
 const typed=enabled&&lightInput==='builtin';if(typed)flags.push('--light-input-read=typed');
 return {version:1,enabled,typed,flags,engineSha256:enabled?sha256:null,policy:enabled?'accepted-v4-normal-gameplay':'conservative-or-isolated',scope:'Accepted V4 runtime bundle only; excludes particle, motion, rig, skeleton and segmented-reader experiments.'};
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
 if(crypto.createHash('sha256').update(proof).digest('hex')!==proofSha256)throw Error('Accepted native core artifact proof changed');
 const artifact=JSON.parse(proof);if(artifact.engineSha256!==sha256||artifact.engineBytes!==bytes||artifact.originalGameAssetsPacked!==false)throw Error('Accepted native core artifact proof differs');
 const requiredProjectFiles=[];
 for(const name of ['project.godot','.godot/global_script_class_cache.cfg']){
  let data;try{data=await fs.readFile(path.join(resolved,name));}catch{throw Error('Verified native runtime requires current project file: '+name);}
  requiredProjectFiles.push({relative:name,bytes:data.length,sha256:crypto.createHash('sha256').update(data).digest('hex')});
 }
 return {kind:'verified-native',executable,directory:path.dirname(resolved),executableSha256:actual,requiresProjectPath:true,requiredProjectFiles,
  expectedCapabilities:[
   {class:'NwnBuiltinLightInputRegistry',parent:'RefCounted',instantiable:true,methods:[{name:'dispatch',arguments:2,returns:'Dictionary'}],operations:[0,1,2,3,4,6,8,9],origin:'accepted built-in light registry'},
   {class:'NwnParticleSceneSnapshot',parent:'RefCounted',methods:[{name:'snapshot_nodes',arguments:2,static:true},{name:'abi_version',arguments:0,static:true}],origin:'existing built-in scene snapshot'},
   {class:'NwnFrameProbe',parent:'RefCounted',methods:[{name:'feature_totals',arguments:0,static:true,returns:'Dictionary'}],origin:'cold actual-use evidence; detailed profiling stays off'}
  ],
  selectionEvidence:{revision:'verified-native-render-core-v2',verification:'Exact executable byte count/SHA256 and accepted artifact proof',executableBytes:bytes,sourceCommit:'ed1daf0bf001b61586d9930840f2f1394092c079',engineVersion:{major:4,minor:7,patch:2,status:'stable',build:'custom_build',hash:'unknown'},pathOverridesEnabled:true,sourcePolicy:'Current project supplied with --path and --script; no private replay project or packaged game assets',particleExtensionPolicy:'Current unchanged project particle DLL, no particle microcandidate',referenceEngineDescriptor:{relative:proofRelative,sha256:proofSha256}}
 };
}
module.exports={selectPerformanceRuntime,resolveRenderThread,acceptedRenderCore};
