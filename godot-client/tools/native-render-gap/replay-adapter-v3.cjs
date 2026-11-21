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
 for(const f of s.renderGap.extraFlags)if(!['--rig-skin-publisher=native','--particle-scene-boundary=native','--particle-scene-boundary=legacy','--skeleton-upload-guard=exact','--skeleton-pair-guard=exact','--motion-facing=native','--pair-record-reuse=exact','--particle-chunk-admission=childless'].includes(f))throw Error('Unsupported private flag');
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
 return {status:errors.length?'rejected':'observed',errors,variant:s.renderGap.variant,scope:'Pinned source/engine selection. Component actual-use counters and visual review are evaluated separately.'};
}
module.exports={readSelection,runtimeFiles,verifyNative};
