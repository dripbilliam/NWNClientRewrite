'use strict';
// Source preparation only. Explicitly private until normal FPS/local acceptance.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),{pathToFileURL}=require('node:url');
const project=path.resolve(__dirname,'../../../..'),[label,route,integrationLabel="normal-integration-d-c-a",...unsupported]=process.argv.slice(2);
if(unsupported.length||!/^[a-z0-9-]+$/.test(label??'')||!['control','candidate'].includes(route))throw Error('Fresh label and baseline/candidate route required');
if(process.env.NWN_GODOT_RUNTIME)throw Error('Default normal-policy benchmark requires NWN_GODOT_RUNTIME unset; an explicit environment runtime must retain its conservative selection');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const directory=path.join(project,'.cache/native-render-gap/replays',label),destination=path.join(directory,'project');
if(fs.existsSync(directory))throw Error('Existing normal replay stage is frozen');
let manifestFile=path.join(project,'.cache/native-render-gap/scene',integrationLabel,'manifest.json'),m=JSON.parse(fs.readFileSync(manifestFile));
let acceptanceFile=path.join(path.dirname(manifestFile),'functional-acceptance.json'),accepted=JSON.parse(fs.readFileSync(acceptanceFile));
if(!accepted.success||accepted.production!==false||accepted.installed!==false||accepted.manifestSha256!==sha(fs.readFileSync(manifestFile))||accepted.sourcePinsUnchanged!==true)throw Error('Sealed final D functional acceptance required');
const coldHooks=require('./cold-window-hooks.cjs');
function write(relative,bytes){const file=path.join(destination,relative);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,bytes,{flag:'wx'});}
async function main(){
 const production=require(path.join(project,'tools/native-production-selection.cjs'));
 const baseline=await production.readProductionSelection(m.baseline.file,m.baseline.sha256);
 const identity=require(path.join(project,'tools/native-feature-manifest.cjs')).sourceIdentity,before=identity(project).sha256;
 if(before!==m.baseline.sourceIdentity)throw Error('Installed main differs from the normal baseline');
 const candidate=route==='candidate';
 if(!candidate){
  const controlDir=path.join(directory,'control-binding');fs.mkdirSync(controlDir,{recursive:true});const runtime=baseline.runtime,descriptor=runtime.selectionEvidence.referenceEngineDescriptor,proofOrigin=path.join(project,descriptor.relative),proofBytes=fs.readFileSync(proofOrigin);if(sha(proofBytes)!==descriptor.sha256)throw Error('Installed C artifact proof changed');const proofFile=path.join(controlDir,'artifact.json');fs.writeFileSync(proofFile,proofBytes,{flag:'wx'});
  const normal=require(path.join(project,'tools/native-client-flags.cjs')).resolvePerformanceOptions([],{env:{}}),relative=path.relative(project,runtime.executable).replaceAll('\\','/');
  m={version:1,production:false,installed:false,candidate:baseline.sourceProject,baseline:m.baseline,pins:[...baseline.pins,{relative:descriptor.relative,sha256:descriptor.sha256}],overlays:[],artifact:{relative,origin:runtime.executable,sha256:runtime.executableSha256,bytes:fs.statSync(runtime.executable).size,proofRelative:descriptor.relative,proofSha256:descriptor.sha256,proofFile,buildKind:'installed-control'},nativeKernel:{sha256:baseline.pins.find(row=>row.relative==='.cache/native-kernel/nwn-particle-kernel.dll').sha256},normal};
  manifestFile=path.join(controlDir,'manifest.json');fs.writeFileSync(manifestFile,JSON.stringify(m,null,2)+'\n',{flag:'wx'});accepted={version:1,kind:'existing-installed-C-control-binding',success:true,production:false,installed:false,manifestSha256:sha(fs.readFileSync(manifestFile)),sourcePinsUnchanged:true,scope:'Byte-bound existing accepted C baseline; no new functional-test claim. Matched graphical all-selected-use proof remains required.'};acceptanceFile=path.join(controlDir,'acceptance.json');fs.writeFileSync(acceptanceFile,JSON.stringify(accepted,null,2)+'\n',{flag:'wx'});
 }
 const origin=m.candidate,metadataOverrides=[];let pins=[];
 for(const p of m.pins){let bytes=fs.readFileSync(p.relative===m.artifact.proofRelative&&m.artifact.proofFile?m.artifact.proofFile:path.join(origin,p.relative));if(sha(bytes)!==p.sha256)throw Error('Normal source input changed '+p.relative);if(['native_session_world.gd','native_live_world.gd'].includes(p.relative)){bytes=Buffer.from(coldHooks.projectSource(p.relative,bytes.toString()));const file=path.join(directory,'benchmark-inputs',p.relative);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,bytes,{flag:'wx'});metadataOverrides.push({relative:p.relative,file,beforeSha256:p.sha256,sha256:sha(bytes),scope:'Exact shared cold steady counters only; no policy/quality flags or per-frame work'});}write(p.relative,bytes);pins.push({relative:p.relative,sha256:sha(bytes)});}metadataOverrides.sort((a,b)=>['native_session_world.gd','native_live_world.gd'].indexOf(a.relative)-['native_session_world.gd','native_live_world.gd'].indexOf(b.relative));
 {
  const source=m.artifact.origin??path.join(origin,m.artifact.relative),target=path.join(destination,m.artifact.relative);fs.mkdirSync(path.dirname(target),{recursive:true});
  if(sha(fs.readFileSync(source))!==m.artifact.sha256)throw Error('Normal engine input changed');
  try{fs.linkSync(source,target);}catch{fs.copyFileSync(source,target,fs.constants.COPYFILE_EXCL);}
  const proof=fs.readFileSync(m.artifact.proofFile??path.join(origin,m.artifact.proofRelative));if(sha(proof)!==m.artifact.proofSha256)throw Error('Normal artifact input changed');if(!fs.existsSync(path.join(destination,m.artifact.proofRelative)))write(m.artifact.proofRelative,proof);
 }
 fs.mkdirSync(path.join(directory,'preference-seeds'));
 for(const name of ['render','layout'])fs.copyFileSync(path.join(path.dirname(m.baseline.file),baseline.preferences[name].relative),path.join(directory,baseline.preferences[name].relative),fs.constants.COPYFILE_EXCL);
 // These are the genuine normal-baseline selectors, not private feature flags.
 // Explicit profiling OFF is required for comparable replay evidence; effective
 // normal defaults and all quality values remain the ordinary launcher policy.
 const options=["--detailed-profiling=off"],helper=require(path.join(destination,'tools/native-production-selection.cjs')),c=helper.configuration(destination,options,{env:{}});
 const selector=require(path.join(destination,'tools/native-performance-runtime.cjs'));
 const runtime=await selector.selectPerformanceRuntime(destination,c.performance.runtime)??{...await require(path.join(destination,'tools/native-engine-runtime.cjs')).selectNativeRuntime(project,c.performance.nativeRuntime?.value??'editor'),requiresProjectPath:true};
 const selection={version:3,kind:'private-normal-full-bundle-replay',production:false,experimental:true,complete:true,created:new Date().toISOString(),originalProject:project,sourceProject:destination,mainSourceIdentity:identity(destination),options,runtime,engine:runtime.executable,engineArguments:c.performance.engineArguments,renderThread:c.performance.renderThread,flags:c.flags,environment:{...c.render.environment,NWN_PARTICLE_KERNEL:'compiled'},featureSelection:c.performance.requested,performanceOptions:c.performance,renderConfiguration:c.render.summary,loadingPipeline:c.loading.summary,profiling:c.profiling,pins,preferences:baseline.preferences,cameraPolicy:baseline.cameraPolicy,originalAssetsCopied:false,nativeBuilds:0,
  normalIntegration:{route,metadataOverrides,manifest:{file:manifestFile,sha256:sha(fs.readFileSync(manifestFile))},acceptance:{file:acceptanceFile,sha256:sha(fs.readFileSync(acceptanceFile))},base:{file:m.baseline.file,sha256:m.baseline.sha256}},
  particleLoop:{module:{file:path.join(destination,'.cache/native-kernel/nwn-particle-kernel.dll'),sha256:pins.find(p=>p.relative==='.cache/native-kernel/nwn-particle-kernel.dll').sha256}},scope:'Private replay of exact normal resolver/runtime/quality defaults. Exact implicit normal policy plus shared cold benchmark metadata source overrides; no headless TLS support; broker/network/local authority and production promotion remain separate.'};
 const file=path.join(directory,'selection.json');fs.writeFileSync(file,JSON.stringify(selection,null,2)+'\n',{flag:'wx'});
 const adapter=path.join(__dirname,'replay-adapter.cjs'),driverBase=path.join(project,'tools/replay-native-loading.mjs');let code=coldHooks.driverSource(fs.readFileSync(driverBase,'utf8'));
 const once=(from,to)=>{if(code.split(from).length!==2)throw Error('Normal replay seam changed '+from.slice(0,90));code=code.replace(from,to);};
 code=code.replace(/from '(\.\/[^']+)'/g,(_,name)=>'from '+JSON.stringify(pathToFileURL(path.resolve(path.dirname(driverBase),name)).href));
 once('createRequire(import.meta.url)','createRequire('+JSON.stringify(pathToFileURL(driverBase).href)+')');
 once("const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');",'const project='+JSON.stringify(project)+';');
 once("const require=createRequire("+JSON.stringify(pathToFileURL(driverBase).href)+"),featureManifest=require('./native-feature-manifest.cjs');","const require=createRequire("+JSON.stringify(pathToFileURL(driverBase).href)+");let featureManifest;");
 once("const productionSelection=await readReplayProductionSelection(arg('production-selection'),arg('production-selection-sha256'),project);",'const gapAdapter=require('+JSON.stringify(adapter)+");\nconst productionSelection=await gapAdapter.readSelection(arg('production-selection'),arg('production-selection-sha256'));\nfeatureManifest=require(path.join(productionSelection.sourceProject,'tools/native-feature-manifest.cjs'));");
 once("await readReplayProductionSelection(arg('production-selection'),arg('production-selection-sha256'),project)","await gapAdapter.readSelection(arg('production-selection'),arg('production-selection-sha256'))");
 once('Object.assign(runtimeFiles,sceneEngineFiles);','Object.assign(runtimeFiles,sceneEngineFiles,gapAdapter.runtimeFiles(productionSelection));');
 once(" await fs.writeFile(reportPath,JSON.stringify(report,null,2)+'\\n',{flag:'wx'});"," report.renderGapVerification=gapAdapter.verifyNative(productionSelection,report.native,report);\n if(report.renderGapVerification.status!=='observed'){report.success=false;report.failure??='Private normal source/engine/actual-use rejected';}\n await fs.writeFile(reportPath,JSON.stringify(report,null,2)+'\\n',{flag:'wx'});");
 if(code.includes('await readReplayProductionSelection('))throw Error('Normal replay final selector replacement incomplete');
 const driver=path.join(directory,'driver.mjs');fs.writeFileSync(driver,code,{flag:'wx'});
 const observer=path.join(__dirname,'watch-module-v4.ps1');
 const tooling=Object.fromEntries(['audit-policy.cjs','audit-case.cjs','run-replay.cjs','cold-window-hooks.cjs'].map(name=>{const file=path.join(__dirname,name);return [name,{file,sha256:sha(fs.readFileSync(file))}];}));
 const result={root:directory,variant:'normal-'+route,profile:false,production:false,adapter:{file:adapter,sha256:sha(fs.readFileSync(adapter))},observer:{file:observer,sha256:sha(fs.readFileSync(observer))},tooling,selection:{file,sha256:sha(fs.readFileSync(file))},base:{file:driverBase,sha256:sha(fs.readFileSync(driverBase))},driver:{file:driver,sha256:sha(fs.readFileSync(driver))},mainBefore:before,mainAfter:identity(project).sha256,scope:'Source factory only. Fresh normal replay parser/adapter negatives plus parent-coordinated FPS/visual/local authority acceptance are required.'};
 if(result.mainBefore!==result.mainAfter)throw Error('Main changed during private normal preparation');
 await require(adapter).readSelection(file,result.selection.sha256);
 fs.writeFileSync(path.join(directory,'preparation.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(result));
}
main().catch(error=>{console.error(error.stack);process.exitCode=1;});
