const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const project=path.resolve(__dirname,'../../../..'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const label=process.argv[2]??'normal-integration-a';if(!/^[a-z0-9-]{1,45}$/.test(label))throw Error('Fresh short label required');
const directory=path.join(project,'.cache/native-render-gap/scene',label),candidate=path.join(directory,'project');if(fs.existsSync(directory))throw Error('Existing private integration frozen');
async function main(){
 const priorFile=path.join(project,'.cache/native-presentation-parity/production-replay/fps-max-v1-ordinary-workers-b/production-selection.json'),prior=JSON.parse(fs.readFileSync(priorFile)),preferenceSeeds={version:1,expected:prior.preferences.expected,description:prior.preferences.description};
 for(const name of ['render','layout'])preferenceSeeds[name]={file:path.join(path.dirname(priorFile),prior.preferences[name].relative),sha256:prior.preferences[name].sha256};
 // Reuse a verified genuine-main baseline when revising only the private
 // integration. This avoids another whole source capsule for each correction.
 const production=require(path.join(project,'tools/native-production-selection.cjs'));let baseline;
 if(process.argv[3]){
  const priorIntegration=JSON.parse(fs.readFileSync(path.resolve(process.argv[3]))),pin=priorIntegration.baseline;
  const selection=await production.readProductionSelection(pin.file,pin.sha256),identity=require(path.join(project,'tools/native-feature-manifest.cjs')).sourceIdentity(project);
  if(identity.sha256!==selection.mainSourceIdentity.sha256)throw Error('Reused normal baseline no longer matches current main source');
  baseline={file:pin.file,sha256:pin.sha256,selection};
 }else baseline=await production.stageProductionSelection({project,label:'render-gap-'+label+'-baseline',argv:['--render-profile=gameplay','--loading-pipeline=ordinary','--detailed-profiling=off'],preferenceSeeds});
 fs.mkdirSync(candidate,{recursive:true});
 const receipts=[
 '.cache/native-render-gap/engine/build-1794133858985/receipt.json',
 '.cache/native-render-gap/engine/build-1794133858985/source-manifest.json',
 '.cache/native-render-gap/original/bounds-repair/gpu-extension-b/acceptance.json',
 '.cache/native-render-gap/scene/light-live-functional-c/acceptance.json',
 '.cache/native-render-gap/scene/light-live-focus-b/acceptance.json',
 'reports/render-gap-fixed-control-v4-a-b.json','reports/render-gap-fixed-control-v4-a-c.json',
 'reports/render-gap-render-light-v4-a-b.json','reports/render-gap-render-light-v4-a-c.json'
 ];
 const acceptedReceipts=receipts.map(relative=>{const file=path.join(project,relative),bytes=fs.readFileSync(file),value=JSON.parse(bytes);if('success'in value&&value.success!==true)throw Error('Accepted receipt rejects '+relative);return {relative,file,sha256:sha(bytes),success:value.success??null};});
 const artifact={version:1,kind:'accepted-native-render-core-artifact',engineSha256:'5713d014f2d1a0c7d479720176fbe8081e9e6254c693b9b5b244676f3afafb0d',engineBytes:90911744,originalGameAssetsPacked:false,acceptedReceipts,scope:'Accepted private V4 engine/components/matched replay evidence. This proof does not claim the new private normal-launch integration is production or has passed its own normal-path tests.'};
 const artifactBytes=Buffer.from(JSON.stringify(artifact,null,2)+'\n'),artifactSha256=sha(artifactBytes),patches=require('./patches.cjs').prepare(project,artifactSha256),overlays=[];
 for(const [relative,bytes]of patches.files){const target=path.join(directory,'overlay',relative);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,bytes,{flag:'wx'});overlays.push({relative,file:target,beforeSha256:sha(patches.original.get(relative)),sha256:sha(bytes)});}
 const pins=[];
 for(const pin of baseline.selection.pins){const before=fs.readFileSync(path.join(baseline.selection.sourceProject,pin.relative));if(sha(before)!==pin.sha256)throw Error('Frozen baseline changed');const bytes=patches.files.get(pin.relative)??before,target=path.join(candidate,pin.relative);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,bytes,{flag:'wx'});pins.push({relative:pin.relative,sha256:sha(bytes)});}
 const engine=path.join(project,'.cache/native-render-gap/engine/build-1794133858985/godot.windows.template_release.x86_64.exe'),artifactRelative='.tools/native-core/Godot_native_core_v4_1_win64.exe',artifactPath=path.join(candidate,artifactRelative);fs.mkdirSync(path.dirname(artifactPath),{recursive:true});let binaryStorage='hardlink';try{fs.linkSync(engine,artifactPath);}catch{fs.copyFileSync(engine,artifactPath);binaryStorage='copy';}
 fs.writeFileSync(path.join(candidate,'.tools/native-core/accepted-core-v4_1.json'),artifactBytes,{flag:'wx'});
 const config=require(path.join(candidate,'tools/native-client-flags.cjs')).resolvePerformanceOptions([]),runtime=await require(path.join(candidate,'tools/native-performance-runtime.cjs')).selectPerformanceRuntime(candidate,config.runtime);
 const fallback=require(path.join(candidate,'tools/native-client-flags.cjs')).resolvePerformanceOptions(['--performance-runtime=standard','--render-thread=safe','--light-input-registry=script','--detailed-profiling=off']);
 // Private candidate provenance deliberately differs from production selection.
 const selection={version:1,kind:'private-normal-integration-selection',production:false,experimental:true,sourceProject:candidate,originalProject:project,originalMainSourceIdentity:baseline.selection.mainSourceIdentity.sha256,baseline:{file:baseline.file,sha256:baseline.sha256},runtime,performanceOptions:config,renderCore:config.renderCore,engineArguments:config.engineArguments,nativeArguments:config.nativeArguments,pins,preferences:baseline.selection.preferences,flagsSource:'Actual patched normal resolver, no render-gap injected flags or particle/native source overlay',scope:'Private normal policy candidate, not accepted production. Unit/native owner and actual normal-path tests remain required.'};
 const selectionFile=path.join(directory,'selection.json');fs.writeFileSync(selectionFile,JSON.stringify(selection,null,2),{flag:'wx'});
 const result={version:1,createdAtUtc:new Date().toISOString(),directory,candidate,production:false,installed:false,engineStarts:0,benchmarks:0,baseline:{file:baseline.file,sha256:baseline.sha256,runtime:baseline.selection.runtime.kind,engineSha256:baseline.selection.runtime.executableSha256,engineArguments:baseline.selection.engineArguments,flags:baseline.selection.flags,sourceIdentity:baseline.selection.mainSourceIdentity.sha256},selection:{file:selectionFile,sha256:sha(fs.readFileSync(selectionFile))},overlays,pins,artifact:{relative:artifactRelative,origin:engine,sha256:runtime.executableSha256,bytes:90911744,storage:binaryStorage,proofRelative:'.tools/native-core/accepted-core-v4_1.json',proofSha256:artifactSha256},normal:config,fallback,acceptedReceipts,scope:'One genuine current-main normal baseline capsule plus private nine-file accepted-V4 integration overlay/project. No main edits, game-asset copies, runtime, FPS, GPU, compilation, settings or credential changes. Full launcher/broker support-root scaffolding and normal-path tests still required before any production claim.'};
 fs.writeFileSync(path.join(directory,'manifest.json'),JSON.stringify(result,null,2),{flag:'wx'});console.log(JSON.stringify({directory,files:pins.length,overlays:overlays.length,baseline:result.baseline,normal:{runtime:config.runtime,thread:config.renderThread,nativeArguments:config.nativeArguments},fallback:{runtime:fallback.runtime,thread:fallback.renderThread,nativeArguments:fallback.nativeArguments},binaryStorage,production:false}));
}
main().catch(e=>{console.error(e.stack);process.exitCode=1;});
