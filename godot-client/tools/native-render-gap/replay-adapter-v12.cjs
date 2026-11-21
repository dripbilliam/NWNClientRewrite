'use strict';
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const helper=require('../native-production-selection.cjs');
const identity=require('../native-feature-manifest.cjs').sourceIdentity;
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
function pin(file,expected){if(!/^[a-f0-9]{64}$/.test(expected??'')||sha(fs.readFileSync(file))!==expected)throw Error('Render-gap pin changed '+file);}
async function readSelection(file,expected){
 pin(file,expected);const s=JSON.parse(fs.readFileSync(file));
 if(s.version!==3||s.kind!=='private-render-gap-selection'||s.production!==false||s.experimental!==true||path.resolve(s.sourceProject)!==path.join(path.dirname(path.resolve(file)),'project'))throw Error('Private render-gap selection policy differs');
 const base=await helper.readProductionSelection(s.renderGap.base.file,s.renderGap.base.sha256);
 for(const field of ['options','engineArguments','renderThread','environment','featureSelection','performanceOptions','renderConfiguration','loadingPipeline','profiling','preferences','cameraPolicy'])if(JSON.stringify(s[field])!==JSON.stringify(base[field]))throw Error('Private render-gap configuration differs '+field);
 if(JSON.stringify(s.flags)!==JSON.stringify([...base.flags,...s.renderGap.extraFlags]))throw Error('Private native flags differ');
 for(const f of s.renderGap.extraFlags)if(!['--rig-skin-publisher=native','--particle-scene-boundary=native','--particle-scene-boundary=legacy','--skeleton-upload-guard=exact','--skeleton-pair-guard=exact','--motion-facing=native','--pair-record-reuse=exact','--particle-chunk-admission=childless','--light-pair-layer-repair=exact','--light-pair-filter=consumers','--light-input-read=typed','--frame-pacing-metrics=on','--particle-sparse-timing','--particle-coarse-timing','--particle-setup-boundary=bound','--particle-scene-direct=pod','--particle-scene-direct=legacy','--skeleton-force-pass=once','--visibility-chain-cache=epochs','--light-input-proof=segments','--particle-hot-parameters=bound','--particle-hot-parameters=legacy','--window-feature-counters','--script-owner-trace=on','--particle-resident-text=borrow','--particle-resident-text=legacy'].includes(f))throw Error('Unsupported private flag');
 const proof=s.renderGap.engineProof;
 if(proof){
  pin(proof.file,proof.sha256); const r=JSON.parse(fs.readFileSync(proof.file));
  if(r.exitCode!==0||r.sourceUnchanged!==true||r.sharedOutputsChanged!==false||r.output!==s.engine||r.outputSha256!==s.runtime.executableSha256)throw Error('Private engine build proof differs');
  pin(s.engine,r.outputSha256);
  pin(proof.invocation.file,proof.invocation.sha256);
  const inv=JSON.parse(fs.readFileSync(proof.invocation.file));
  pin(proof.manifest.file,proof.manifest.sha256);
  if(inv.manifestSha256!==proof.manifest.sha256||path.resolve(proof.manifest.file)!==path.join(r.run,'source-manifest.json'))throw Error('Sealed engine manifest differs');
  const manifest=JSON.parse(fs.readFileSync(proof.manifest.file));
  for(const p of manifest.patches)pin(path.join(r.run,'source-evidence',p.relative),p.afterSha256);
  for(const p of manifest.modules)pin(path.join(r.run,'source-evidence',p.relative),p.sha256);
  const expectedRuntime={...base.runtime,executable:s.engine,executableSha256:r.outputSha256};
  if(JSON.stringify(s.runtime)!==JSON.stringify(expectedRuntime))throw Error('Private runtime differs beyond executable');
 }else if(JSON.stringify(s.runtime)!==JSON.stringify(base.runtime)||s.engine!==base.engine)throw Error('Installed runtime changed');
 for(const p of s.renderGap.overrides)pin(p.file,p.sha256);
 helper.validatePins(s);helper.validatePreferencePins(s);
 if(identity(s.sourceProject).sha256!==s.mainSourceIdentity.sha256)throw Error('Private source identity changed');
 pin(s.particleLoop.module.file,s.particleLoop.module.sha256);
 return {...s,evidence:{file:path.resolve(file),sha256:expected,sourceProject:s.sourceProject,sourceSignature:s.mainSourceIdentity.sha256,engineSha256:s.runtime.executableSha256,particleSha256:s.particleLoop.module.sha256,flags:[...s.flags],production:false,experimental:'isolated-render-gap',scope:'Pinned current application plus explicit private overrides; matched settings/display/camera/authority gates remain required.'}};
}
function runtimeFiles(s){
 const proof=s.renderGap.engineProof,out={renderGapAdapter:__filename,renderGapBase:s.renderGap.base.file};
 if(proof){
  out.renderGapEngineProof=proof.file;out.renderGapEngineInvocation=proof.invocation.file;out.renderGapEngineManifest=proof.manifest.file;
  const r=JSON.parse(fs.readFileSync(proof.file)),m=JSON.parse(fs.readFileSync(proof.manifest.file));
  let i=0;for(const p of [...m.patches,...m.modules])out['renderGapEngineSource'+i++]=path.join(r.run,'source-evidence',p.relative);
 }
 return out;
}
function verifyNative(s,n){
 const errors=[];
 if(n?.runtime_features?.executable&&path.resolve(n.runtime_features.executable)!==path.resolve(s.engine))errors.push('Native executable mismatch');
 const g=n?.render_gap??{},flags=s.renderGap.extraFlags,proof={};
 const requireUse=(flag,name,value)=>{if(flags.includes(flag)){proof[name]=value===true;if(value!==true)errors.push('Actual feature work was not observed: '+name);}};
 requireUse('--motion-facing=native','motion',g.motion?.supported>0);
 requireUse('--particle-scene-boundary=native','boundary',g.particle_boundary?.boundary?.eligibility_reads>0||g.particle_boundary?.eligibility_reads>0);
 requireUse('--rig-skin-publisher=native','skin',(g.skin_owners??[]).some(x=>x.totals?.completed>0));
 requireUse('--light-input-read=typed','lightReader',g.light_inputs?.plain_claims>0&&g.light_inputs?.plain_rows>0&&g.light_inputs?.plain_field_reads>0);
 requireUse('--pair-record-reuse=exact','pairReuse',g.engine_features?.pair_reused>0&&g.engine_features?.pair_reuse_passes>0);
 requireUse('--light-pair-filter=consumers','lightFilter',g.engine_features?.light_excluded>0&&g.engine_features?.light_filter_passes>0);
 requireUse('--particle-chunk-admission=childless','childless',(g.chunk_admission?.entries??[]).some(x=>x.requested===true&&x.last_checked===true));
 requireUse('--particle-sparse-timing','sparseTiming',g.particle_sample?.enabled===true&&g.particle_sample?.samples>0&&g.particle_sample?.successes===g.particle_sample?.samples&&g.particle_sample?.errors===0);
 requireUse('--particle-setup-boundary=bound','setupBoundary',g.particle_sample?.setup_boundary===true&&g.particle_sample?.animating_key_binds>0&&g.particle_sample?.static_noncallable_uses+g.particle_sample?.static_null_callable_uses>0);
 requireUse('--frame-pacing-metrics=on','pacing',g.pacing?.enabled===true&&g.pacing?.main?.length>0&&g.pacing?.render?.length>0&&g.pacing?.cpu_windows?.length>0);
 const boundary=g.particle_boundary?.boundary??g.particle_boundary;
 requireUse('--particle-scene-direct=pod','directScene',boundary?.direct_enabled===true&&boundary?.direct_eligibility_calls>0&&boundary?.direct_pose_reads>0);
 requireUse('--skeleton-force-pass=once','skeletonForce',g.engine_features?.skeleton_force_once?.stable_calls>0&&g.engine_features?.skeleton_force_once?.avoided_offsets>0);
 requireUse('--particle-coarse-timing','coarseTiming',g.particle_sample?.coarse_phases===true&&g.particle_sample?.phase_success_samples>0&&g.particle_sample?.phase_clock_reads===4*g.particle_sample?.phase_success_samples);
 const script=g.script_context;
 requireUse('--script-owner-trace=on','scriptOwnerTrace',script?.enabled===true&&script?.available===true&&script?.registered>0&&script?.registered===script?.rows?.length&&script?.main_native_thread_id===g.pacing?.main_thread_policy?.thread_id);
 requireUse('--particle-resident-text=borrow','residentTextBorrow',g.resident_text?.borrowed===true&&g.resident_text?.borrowed_reads>0);
 requireUse('--particle-resident-text=legacy','residentTextLegacy',g.resident_text?.borrowed===false&&g.resident_text?.legacy_reads>0);
 const visibility=g.engine_features?.visibility_chain_cache;
 requireUse('--visibility-chain-cache=epochs','visibilityCache',visibility?.enabled===true&&visibility?.disabled===false&&visibility?.queries>10000&&(visibility?.hits+visibility?.ancestor_hits)>10000);
 requireUse('--light-input-proof=segments','lightProofSegments',g.light_inputs?.plain_segment_proofs>0&&g.light_inputs?.plain_segment_reuses>0);
 const hotOwners=g.hot_parameters?.owners??[];
 requireUse('--particle-hot-parameters=legacy','hotLegacy',hotOwners.length>0&&hotOwners.every(x=>x.enabled===false));
 requireUse('--particle-hot-parameters=bound','hotFields',hotOwners.some(x=>x.enabled===true&&(x.fields??[]).some(f=>f.reads>0&&f.hits>0)));
 requireUse('--window-feature-counters','windowFeatures',Object.keys(n?.performance_window?.engine_features_begin??{}).length>0&&Object.keys(n?.performance_window?.engine_features_end??{}).length>0&&n?.performance_window?.engine_process_frame_end>n?.performance_window?.engine_process_frame_begin);
 return {status:errors.length?'rejected':'observed',errors,variant:s.renderGap.variant,features:proof,scope:'Pinned source/engine selection plus requested current-route feature counters. Performance, visual and public-server acceptance remain separate.'};
}
module.exports={readSelection,runtimeFiles,verifyNative};
