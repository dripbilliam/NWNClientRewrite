'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const project=path.resolve(__dirname,'../../../..'),label=process.argv[2]??'normal-integration-c';if(!/^[a-z0-9-]{1,50}$/.test(label))throw Error('Fresh label required');
const directory=path.join(project,'.cache/native-render-gap/scene',label),candidate=path.join(directory,'project'),sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
if(fs.existsSync(directory))throw Error('Existing C stage is frozen');
async function main(){
 const bFile=path.join(project,'.cache/native-render-gap/scene/normal-integration-b/manifest.json'),b=JSON.parse(fs.readFileSync(bFile));
 const production=require(path.join(project,'tools/native-production-selection.cjs')),baseline=await production.readProductionSelection(b.baseline.file,b.baseline.sha256);
 const before=require(path.join(project,'tools/native-feature-manifest.cjs')).sourceIdentity(project).sha256;if(before!==b.baseline.sourceIdentity)throw Error('Main changed before C preparation');
 const fullFile=path.join(project,'.cache/native-render-gap/replays/hot-full-v7-b/selection.json'),full=JSON.parse(fs.readFileSync(fullFile));
 const buildFile=path.join(project,'.cache/native-render-gap/particles/hot-parameters-c/kernel-build/build-receipt.json'),build=JSON.parse(fs.readFileSync(buildFile));
 if(full.runtime.executableSha256!=='75bc654d66aa249787ec166980a813e69f3081d98c8453fe23aeff2b07779ca6'||build.success!==true||build.binarySha256!=='879e0a9ce618ec6c77f69a39cfde4f684a94f791a398fe08d432d857d9368d24')throw Error('Accepted full bundle pins differ');
 const receipts=[
  '.cache/native-render-gap/engine/build-1794142557441/receipt.json','.cache/native-render-gap/engine/build-1794142557441/source-manifest.json',
  '.cache/native-render-gap/replays/hot-full-v7-b/render-gap-hot-full-v7-b-a.result.json','.cache/native-render-gap/replays/hot-full-v7-b/render-gap-hot-full-v7-b-b.result.json',
  '.cache/native-render-gap/particles/hot-parameters-c/full-v6-1-a/receipt.json','.cache/native-render-gap/particles/setup-boundary-a/regressions-v4-1/receipt.json',
  '.cache/native-render-gap/particles/boundary-skin-v2-c/focused-v2-receipt.json','.cache/native-render-gap/scene/skeleton-force-acceptance-a.json','.cache/native-render-gap/scene/skeleton-force-gpu-a/acceptance.json',
  '.cache/native-render-gap/scene/light-segment-functional-a/acceptance.json','.cache/native-render-gap/scene/light-segment-focus-v7-a/acceptance.json',
  '.cache/native-render-gap/original/visibility-cache/fixture-b/acceptance.json','.cache/native-render-gap/original/visibility-cache/gpu-b/acceptance.json',
  '.cache/native-render-gap/original/bounds-repair/gpu-extension-b/acceptance.json',
  '.cache/native-render-gap/scene/normal-integration-b/checks-d/acceptance.json'
 ];
 const acceptedReceipts=receipts.map(relative=>{const file=path.join(project,relative),bytes=fs.readFileSync(file),value=JSON.parse(bytes);if('success'in value&&value.success!==true)throw Error('Rejected component receipt '+relative);return {relative,file,sha256:sha(bytes)};});
 const engine=full.engine,engineBytes=fs.statSync(engine).size;if(sha(fs.readFileSync(engine))!==full.runtime.executableSha256)throw Error('V7 engine bytes changed');
 const artifact={version:2,kind:'accepted-native-full-bundle-artifact',engineSha256:full.runtime.executableSha256,engineBytes,nativeKernelSha256:build.binarySha256,originalGameAssetsPacked:false,acceptedReceipts,fullFunctionalFlags:require('./patches.cjs').fullFlags,diagnosticDefaults:false,componentSelection:{file:fullFile,sha256:sha(fs.readFileSync(fullFile)),excludedDiagnosticFlags:['--frame-pacing-metrics=on','--particle-coarse-timing']},nativeBuild:{file:buildFile,sha256:sha(fs.readFileSync(buildFile))},scope:'Accepted component binaries, exact source/native dependencies and fullB private functional work. Normal diagnostics-OFF packaging/launcher/authority/FPS acceptance and installed promotion are separately receipted.'};
 const artifactBytes=Buffer.from(JSON.stringify(artifact,null,2)+'\n'),artifactSha256=sha(artifactBytes),proposal=require('./patches.cjs').prepare(project,artifactSha256,engineBytes,full,build);
 fs.mkdirSync(candidate,{recursive:true});const overlays=[];
 for(const [relative,bytes]of proposal.files){const file=path.join(directory,'overlay',relative);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,bytes,{flag:'wx'});const original=proposal.original.get(relative);overlays.push({relative,file,beforeSha256:original?sha(original):null,sha256:sha(bytes)});}
 const data=new Map(baseline.pins.map(pin=>{const bytes=fs.readFileSync(path.join(baseline.sourceProject,pin.relative));if(sha(bytes)!==pin.sha256)throw Error('Normal baseline source changed '+pin.relative);return [pin.relative,bytes];}));
 for(const [relative,bytes]of proposal.files)data.set(relative,bytes);
 // Actual check-only ensure needs the same API inputs as ordinary launch.
 for(const relative of ['.tools/extension-api/gdextension_interface.h','.tools/extension-api/extension_api.json'])data.set(relative,fs.readFileSync(path.join(project,relative)));
 const pins=[];for(const [relative,bytes]of data){const file=path.join(candidate,relative);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,bytes,{flag:'wx'});pins.push({relative,sha256:sha(bytes)});}
 const binaryLinks=[];for(const [relative,origin]of [
  ['.tools/native-core/Godot_native_core_v7_win64.exe',engine],
  ['.tools/Godot_v4.7.2-stable_win64.exe',path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe')],
  ['.tools/Godot_v4.7.2-stable_win64_console.exe',path.join(project,'.tools/Godot_v4.7.2-stable_win64_console.exe')]
 ]){const file=path.join(candidate,relative);fs.mkdirSync(path.dirname(file),{recursive:true});let storage='hardlink';try{fs.linkSync(origin,file);}catch{fs.copyFileSync(origin,file,fs.constants.COPYFILE_EXCL);storage='copy';}binaryLinks.push({relative,origin,file,bytes:fs.statSync(file).size,storage});}
 const proofRelative='.tools/native-core/accepted-core-v7.json';fs.writeFileSync(path.join(candidate,proofRelative),artifactBytes,{flag:'wx'});
 const flags=require(path.join(candidate,'tools/native-client-flags.cjs')),normal=flags.resolvePerformanceOptions([]),fallback=flags.resolvePerformanceOptions(['--performance-runtime=standard','--render-thread=safe','--light-input-registry=script','--detailed-profiling=off']);
 const runtime=await require(path.join(candidate,'tools/native-performance-runtime.cjs')).selectPerformanceRuntime(candidate,normal.runtime);
 const nativeBuild=JSON.parse(fs.readFileSync(path.join(candidate,'.cache/native-kernel/build-manifest.json')));
 const cacheInputs=['native/particle_kernel.cpp','native/particle_kernel.gdextension','tools/build-particle-kernel.ps1','.tools/extension-api/gdextension_interface.h','.tools/extension-api/extension_api.json',...pins.map(p=>p.relative).filter(name=>name.startsWith('native/')&&/\.(hpp|inc)$/.test(name))];
 for(const relative of cacheInputs)if(sha(fs.readFileSync(path.join(candidate,relative)))!==nativeBuild.sources[relative])throw Error('Ordinary ensure would rebuild the accepted DLL: '+relative);
 const selection={version:1,kind:'private-normal-integration-selection',production:false,experimental:true,sourceProject:candidate,originalProject:project,originalMainSourceIdentity:before,baseline:{file:b.baseline.file,sha256:b.baseline.sha256},runtime,performanceOptions:normal,renderCore:normal.renderCore,engineArguments:normal.engineArguments,nativeArguments:normal.nativeArguments,pins,preferences:baseline.preferences,scope:'New diagnostics-OFF normal bundle. Full private functional/normal graphical/local authority acceptance is required before installed promotion.'};
 const selectionFile=path.join(directory,'selection.json');fs.writeFileSync(selectionFile,JSON.stringify(selection,null,2)+'\n',{flag:'wx'});
 const result={version:2,createdAtUtc:new Date().toISOString(),directory,candidate,production:false,installed:false,engineStarts:0,baseline:b.baseline,selection:{file:selectionFile,sha256:sha(fs.readFileSync(selectionFile))},overlays,pins,binaryLinks,artifact:{relative:'.tools/native-core/Godot_native_core_v7_win64.exe',origin:engine,sha256:runtime.executableSha256,bytes:engineBytes,proofRelative,proofSha256:artifactSha256},nativeKernel:{file:path.join(candidate,'.cache/native-kernel/nwn-particle-kernel.dll'),sha256:build.binarySha256,sourceReceipt:{file:buildFile,sha256:sha(fs.readFileSync(buildFile))},cacheInputs,cacheReady:true},normal,fallback,acceptedReceipts,mainBefore:before,mainAfter:require(path.join(project,'tools/native-feature-manifest.cjs')).sourceIdentity(project).sha256,scope:'Private source/native/runtime preparation only. Main/B/evidence retained. No compilation, runtime, GPU/FPS, user-preference or credential changes.'};
 if(result.mainBefore!==result.mainAfter)throw Error('Main changed during C preparation');fs.writeFileSync(path.join(directory,'manifest.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({directory,overlays:overlays.length,pins:pins.length,engine:runtime.executableSha256,kernel:build.binarySha256,cacheReady:true,flags:normal.nativeArguments,production:false}));
}
main().catch(error=>{if(fs.existsSync(directory))fs.writeFileSync(path.join(directory,'preparation-failure.json'),JSON.stringify({success:false,error:error.stack},null,2),{flag:'wx'});console.error(error.stack);process.exitCode=1;});
