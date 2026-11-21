'use strict';
// Private normal-policy replay only. Never marks an unpromoted overlay production.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const project=path.resolve(__dirname,'../../../..');
const production=require(path.join(project,'tools/native-production-selection.cjs'));
const identity=require(path.join(project,'tools/native-feature-manifest.cjs')).sourceIdentity;
const coldHooks=require('./cold-window-hooks.cjs');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
function pin(file,expected){if(!/^[a-f0-9]{64}$/.test(expected??'')||sha(fs.readFileSync(file))!==expected)throw Error('Normal replay pin changed '+file);}
function same(actual,expected,label){if(JSON.stringify(actual)!==JSON.stringify(expected))throw Error('Normal replay differs: '+label);}
async function readSelection(file,expected){
 pin(file,expected);const s=JSON.parse(fs.readFileSync(file));
 if(s.version!==3||s.kind!=='private-normal-full-bundle-replay'||s.production!==false||s.experimental!==true||path.resolve(s.sourceProject)!==path.join(path.dirname(path.resolve(file)),'project'))throw Error('Private normal replay policy differs');
 if(!['control','candidate'].includes(s.normalIntegration?.route))throw Error('Unknown normal replay route');
 const proposal=s.normalIntegration;pin(proposal.manifest.file,proposal.manifest.sha256);pin(proposal.acceptance.file,proposal.acceptance.sha256);
 const m=JSON.parse(fs.readFileSync(proposal.manifest.file)),accepted=JSON.parse(fs.readFileSync(proposal.acceptance.file));
 same(proposal.base,{file:m.baseline.file,sha256:m.baseline.sha256},'baseline proof');
 if(m.production!==false||m.installed!==false||accepted.success!==true||accepted.production!==false||accepted.installed!==false||accepted.manifestSha256!==proposal.manifest.sha256||accepted.sourcePinsUnchanged!==true)throw Error('Private normal integration acceptance differs');
 if(identity(project).sha256!==m.baseline.sourceIdentity)throw Error('Installed main changed after the normal baseline was frozen');
 const base=await production.readProductionSelection(m.baseline.file,m.baseline.sha256);
 const candidate=proposal.route==='candidate';
 const overrides=s.normalIntegration.metadataOverrides;
 if(!Array.isArray(overrides)||JSON.stringify(overrides.map(row=>row.relative))!==JSON.stringify(['native_session_world.gd','native_live_world.gd']))throw Error('Exact shared cold metadata hooks required');
 const expectedPins=m.pins.map(row=>({...row}));
 for(const override of overrides){const expected=expectedPins.find(row=>row.relative===override.relative);if(!expected||expected.sha256!==override.beforeSha256)throw Error('Cold metadata original pin differs');const original=fs.readFileSync(path.join(m.candidate,override.relative),'utf8'),after=coldHooks.projectSource(override.relative,original);if(sha(Buffer.from(after))!==override.sha256)throw Error('Cold metadata transform differs');const relative=path.relative(path.dirname(file),override.file);if(relative.startsWith('..')||path.isAbsolute(relative))throw Error('Cold metadata evidence escaped stage');pin(override.file,override.sha256);expected.sha256=override.sha256;}
 if(m.sourceSnapshots)for(const row of m.sourceSnapshots)pin(row.file,row.sha256);
 same(s.pins,expectedPins,'exact source pins');
 production.validatePins(s);production.validatePreferencePins(s);
 if(fs.existsSync(path.join(s.sourceProject,'override.cfg'))||fs.existsSync(path.join(s.sourceProject,'fixture-ca.crt')))throw Error('Headless-only TLS fixture leaked into normal replay');
 if(identity(s.sourceProject).sha256!==s.mainSourceIdentity.sha256)throw Error('Normal replay source identity changed');
 {
  for(const p of m.overlays)pin(p.file,p.sha256);
  pin(path.join(s.sourceProject,m.artifact.relative),m.artifact.sha256);
  pin(path.join(s.sourceProject,m.artifact.proofRelative),m.artifact.proofSha256);
 }
 const helper=require(path.join(s.sourceProject,'tools/native-production-selection.cjs'));
 const c=helper.configuration(s.sourceProject,s.options,{env:{}});
 const selector=require(path.join(s.sourceProject,'tools/native-performance-runtime.cjs'));
 const runtime=await selector.selectPerformanceRuntime(s.sourceProject,c.performance.runtime)??{...await require(path.join(s.sourceProject,'tools/native-engine-runtime.cjs')).selectNativeRuntime(project,c.performance.nativeRuntime?.value??'editor'),requiresProjectPath:true};
 same(s.runtime,runtime,'selected runtime');same(s.engine,runtime.executable,'engine');
 for(const [actual,wanted,label]of [
  [s.flags,c.flags,'native flags'],[s.performanceOptions,c.performance,'performance options'],
  [s.engineArguments,c.performance.engineArguments,'engine arguments'],[s.renderThread,c.performance.renderThread,'render-thread policy'],
  [s.featureSelection,c.performance.requested,'feature selection'],[s.renderConfiguration,c.render.summary,'render configuration'],
  [s.loadingPipeline,c.loading.summary,'loading pipeline'],[s.profiling,c.profiling,'profile policy'],
  [s.environment,{...c.render.environment,NWN_PARTICLE_KERNEL:'compiled'},'environment'],
  [s.preferences,base.preferences,'common preferences'],[s.cameraPolicy,base.cameraPolicy,'camera policy']
 ])same(actual,wanted,label);
 if(s.profiling!=='false')throw Error('Normal replay requires profiling OFF');
 if(c.performance.runtime!=='verified-native'||c.performance.renderThread!=='separate'||c.performance.requested['light-input-registry'].value!=='builtin'||c.renderCore?.typed!==true)throw Error('Normal selected route differs from accepted defaults');
 same(c.renderCore.flags,m.normal.renderCore.flags,'exact accepted functional bundle');
 if(s.particleLoop?.module?.file!==path.join(s.sourceProject,'.cache/native-kernel/nwn-particle-kernel.dll'))throw Error('Normal particle module path escaped source');
 pin(s.particleLoop.module.file,s.particleLoop.module.sha256);
 if(s.particleLoop.module.sha256!==(m.nativeKernel?.sha256??base.pins.find(p=>p.relative==='.cache/native-kernel/nwn-particle-kernel.dll')?.sha256))throw Error('Normal replay must retain the installed particle DLL');
 return {...s,evidence:{file:path.resolve(file),sha256:expected,sourceProject:s.sourceProject,sourceSignature:s.mainSourceIdentity.sha256,engineSha256:s.runtime.executableSha256,particleSha256:s.particleLoop.module.sha256,flags:[...s.flags],production:false,experimental:'private-normal-policy',scope:'Exact implicit normal option/runtime helpers and selected artifact, plus explicit cold benchmark metadata overrides; replay transport is private. Full normal broker/local authority acceptance and main promotion remain separate.'}};
}
function runtimeFiles(s){const out={normalReplayAdapter:__filename,normalColdHooks:path.join(__dirname,'cold-window-hooks.cjs'),normalAuditPolicy:path.join(__dirname,'audit-policy.cjs'),normalAuditCase:path.join(__dirname,'audit-case.cjs'),normalIntegrationManifest:s.normalIntegration.manifest.file,normalIntegrationAcceptance:s.normalIntegration.acceptance.file,normalBaseline:s.normalIntegration.base.file};for(const [index,row]of s.normalIntegration.metadataOverrides.entries())out['normalColdSource'+index]=row.file;const m=JSON.parse(fs.readFileSync(s.normalIntegration.manifest.file));for(const [index,row]of (m.sourceSnapshots??[]).entries())out['normalFactorySource'+index]=row.file;if(m.artifact.buildKind==='private-manual-light-module-engine'){const proof=JSON.parse(fs.readFileSync(path.join(s.sourceProject,m.artifact.proofRelative))),file=proof.engineBuildProof.receipt.file,receipt=JSON.parse(fs.readFileSync(file)),helper=path.resolve(__dirname,'../../replay-adapter-v18.cjs');pin(helper,'66b92bee7c393edacd6be98aba3819a490ff95bf303f1c7a0b18c0bdc854dc07');out.manualEngineValidator=helper;for(const [index,file]of require(helper).manualLightFiles(receipt,false).entries())out['normalManualEngine'+index]=file;}return out;}
function verifyNative(s,n,outer){
 const helper=require(path.join(s.sourceProject,'tools/native-feature-manifest.cjs'));
 const manifest=helper.createStartupManifest({run:'private-normal-replay-final',project:s.sourceProject,runtime:s.runtime,options:s.performanceOptions,renderConfiguration:s.renderConfiguration,engineAndNativeArguments:[...s.engineArguments,...s.flags]});
 const observed=helper.verifyNativeObservation(manifest,n?.runtime_features,{requireObservedThread:true});
 const world=helper.worldSelection(n?.world??{},{connection:n?.connection??0,generation:n?.generation??0,areaId:n?.world?.area_id??0});
 const owners=helper.verifyWorldSelection(manifest,world),errors=[...observed.errors,...owners.errors],features={};
 const policy=require('./audit-policy.cjs').normalPolicyChecks(s,n);
 if(!policy.thread)errors.push('Actual normal render-thread ID evidence is missing or differs from the canonical mode');
 if(!policy.owners)errors.push('Actual normal world owners differ from the canonical route');
 const bundle=helper.verifyAcceptedBundleUse(s.performanceOptions.renderCore,n?.accepted_render_bundle,{requireBusyUse:true});Object.assign(features,bundle.features);errors.push(...bundle.errors);
 const cold=coldHooks.metrics(n,outer);if(!cold.valid||!cold.hostValid)errors.push('Complete native/host steady throughput metadata is missing or inconsistent');
 return {status:errors.length?'rejected':'observed',errors,variant:'normal-'+s.normalIntegration.route,features,startup:observed,owners,production:false,scope:'Actual executable/thread/profile/current owners and requested selected exact normal-bundle work. Matched FPS, visual inspection, full launcher/local checks and promotion remain separate.'};
}
module.exports={readSelection,runtimeFiles,verifyNative};
