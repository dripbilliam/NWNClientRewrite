// Selects only the reviewed, already-built atlas ownership engine. Read-only:
// no engine build, source copying, executable launch or runtime installation.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

const sha=raw=>crypto.createHash('sha256').update(raw).digest('hex');
const expected={
 descriptor:'50ee3055ede64a5cf00b7bef1da1ebb2ae8b780d277d5d52892ea5e791ea591d',
 parent:'0f640f95b3ffc2a0a2cf65695004ea5c77eae36718a6a43ae87199578902991e',
 baseline:'ce2d36407d0a6107a3076a00faf7d9f9dae185c86994ccea8dfd7e450c50f12a',
 executable:'62f54a7f7ff4638987730a246833cea4054779e7cb2a333bb5921fd5b0aea6dc',
 acceptance:'e5059f21dcab25fe589589240711ba587f13136311fa48af0b9c477755d8c0f7',
 sourceFreeze:'92b6a1df2a02c92e58d4579f26e88a7ca95eedb6b8751143ca6c5023330107d4',
};

export function verifyClientLaunchEngine(engine){
 if(engine?.sha256!==expected.executable||engine.descriptorSha256!==expected.descriptor||
    engine.proof?.baselineSha256!==expected.baseline||engine.proof.acceptance?.sha256!==expected.acceptance||
    engine.proof.sourceFreeze?.sha256!==expected.sourceFreeze||!Array.isArray(engine.proof.proofPins)||
    !engine.proof.proofPins.some(row=>row.file===engine.path&&row.sha256===engine.sha256)||
    !engine.proof.proofPins.some(row=>row.file===engine.descriptor&&row.sha256===engine.descriptorSha256))throw Error('Reviewed capsule engine proof missing');
 for(const row of engine.proof.proofPins)if(sha(fs.readFileSync(row.file))!==row.sha256)throw Error('Reviewed engine source/build/acceptance pin changed: '+row.file);
}

export function selectClientLaunchEngine(project){
 const proofPins=[];
 const checked=(file,hash)=>{
  const raw=fs.readFileSync(file);if(sha(raw)!==hash)throw Error('Reviewed engine proof changed: '+file);
  proofPins.push({file,sha256:hash});return raw;
 };
 const json=(file,hash)=>JSON.parse(checked(file,hash));
 const descriptorFile=path.join(project,'.cache/native-140fps/render-agent/engine-font-atlas-ownership-v1/engine-descriptor.json');
 const descriptor=json(descriptorFile,expected.descriptor);
 const parent=json(descriptor.parentDescriptor,expected.parent);
 const engine=descriptor.engines?.candidate;
 if(descriptor.version!==1||descriptor.sourceCommit!=='ed1daf0bf001b61586d9930840f2f1394092c079'||
    descriptor.parentDescriptorSha256!==expected.parent||descriptor.engines?.baseline?.sha256!==expected.baseline||
    parent.engines?.candidate?.sha256!==expected.baseline||engine?.sha256!==expected.executable||
    !descriptor.retainedPairedEnginesUnchanged||!descriptor.sharedOutputsUnchanged)throw Error('Engine ancestry differs');
 const features=descriptor.resolvedFeatures;
 if(Object.keys({...features,...parent.resolvedFeatures}).some(key=>features[key]!==parent.resolvedFeatures[key]))throw Error('Atlas engine feature policy differs from ce2d');
 for(const [key,value] of Object.entries({platform:'windows',arch:'x86_64',target:'template_release',vulkan:true,opengl3:true,d3d12:false,disable_path_overrides:false})){
  if(features?.[key]!==value)throw Error('Required engine feature differs: '+key);
 }
 const manifest=json(descriptor.sourceManifest,descriptor.sourceManifestSha256);
 const patch=descriptor.fontPatch;
 if(manifest.sharedSourceChanged!==false||manifest.sharedEngineChanged!==false||manifest.guards?.length!==12||
    JSON.stringify(manifest.fontPatch)!==JSON.stringify(patch)||patch?.dirtyPaths!==4||
    patch.canonicalImageReplaced!==false||patch.dirtyPolicyChanged!==false||patch.textureIdentityPolicyChanged!==false)throw Error('Atlas source ownership proof differs');
 checked(patch.beforeFile,patch.beforeSha256);checked(patch.afterFile,patch.afterSha256);checked(patch.patchFile,patch.patchSha256);
 checked(path.join(manifest.source,patch.relative),patch.afterSha256);
 // These are small, exact inherited module sources, not a whole-engine scan.
 for(const row of manifest.modulePins??[])checked(path.join(manifest.moduleDirectory,row.relative),row.sha256);
 for(const module of manifest.inheritedModules??[])for(const row of module.pins)checked(path.join(module.directory,row.relative),row.sha256);
 checked(path.join(manifest.source,manifest.nodePatch.relative),manifest.nodePatch.afterSha256);
 const build=json(engine.buildReceipt,engine.buildReceiptSha256);
 checked(engine.invocation,engine.invocationSha256);
 if(engine.buildExitCode!==0||engine.sourceUnchanged!==true||build.exitCode!==0||build.sourceUnchanged!==true||
    build.sharedSourceChanged!==false||build.sharedEngineChanged!==false||
    !build.outputs?.some(row=>row.path===engine.path&&row.sha256===engine.sha256))throw Error('Engine build receipt differs');
 checked(engine.path,engine.sha256);
 const acceptanceFile=path.join(project,'.cache/native-presentation-parity/particles-agent/image-atlas-engine-acceptance-v1/comparison.json');
 const acceptance=json(acceptanceFile,expected.acceptance);
 const sourceFreezeFile=path.join(project,'.cache/native-presentation-parity/particles-agent/image-atlas-source-v2/manifest.json');
 const sourceFreeze=json(sourceFreezeFile,expected.sourceFreeze);
 for(const row of sourceFreeze.files??[])checked(row.file,row.sha256);
 if(acceptance.success!==true||acceptance.descriptor?.sha256!==expected.descriptor||
    acceptance.engines?.candidate?.sha256!==expected.executable||acceptance.engines?.baseline?.sha256!==expected.baseline||
    acceptance.sourceUnchanged!==true||acceptance.sourcePinsMatch!==true||acceptance.engineUnchanged!==true||
    acceptance.candidate?.checks!==363||acceptance.candidate.errors!==0||acceptance.font_repro?.candidate_checks!==27||
    acceptance.font_repro.candidate_errors!==0||acceptance.pngs?.length!==24||
    !acceptance.pngs.every(row=>row.identical===true&&row.baseline_sha256===row.candidate_sha256)||
    acceptance.guards?.length!==12||!acceptance.guards.every(row=>row.unchanged===true))throw Error('Atlas acceptance proof differs');
 return {...engine,descriptor:descriptorFile,descriptorSha256:expected.descriptor,proof:{
  purpose:'Private font atlas upload ownership correction; same ce2d renderer and feature policy',
  baselineSha256:expected.baseline,acceptance:{file:acceptanceFile,sha256:expected.acceptance},
  sourceFreeze:{file:sourceFreezeFile,sha256:expected.sourceFreeze},proofPins,
  separateDialogueChecks:363,byteIdenticalDialogueImages:24,stockFontChecks:27,
  priorPerformanceCohortPreserved:false,performanceAccepted:false,liveClientValidated:false,
 }};
}
