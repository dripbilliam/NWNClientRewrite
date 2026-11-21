// Source freeze and, only with --stage-engine in a granted CPU window, a real
// private engine copy. Never mutates the archived parent or shared outputs.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';

const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const base=path.join(project,'.cache/native-140fps/render-agent');
const sourceLabel='synchronous-particle-reads-source-v2',engineLabel='engine-synchronous-particle-reads-v2';
const sourceDirectory=path.join(base,sourceLabel),sourceManifestFile=path.join(sourceDirectory,'manifest.json');
const parentDirectory=path.join(base,'engine-font-atlas-v1');
const parentFile=path.join(parentDirectory,'manifest.json'),parentDescriptor=path.join(parentDirectory,'engine-descriptor.json');
const parentDescriptorSha256='9b881b4b47d26fb897fb3dd8a64df1751344522bb1dd60b58a05d0795ed78f88';
const parentEngineSha256='0f8876c3dd25927e4e1064142e4fcd51e103d757e11b0cc19de1c909acb371b9';
const abiFile=path.join(project,'.cache/native-140fps/particles-agent/synchronous-engine-read-design-v1/nwn_particle_read_abi_v1.h');
const abiSha256='985efa740c5284506b50f2703d4d9b028d2b5b7414f883a2461000bacc7f7527';
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const fileHash=file=>hash(fs.readFileSync(file));
const descriptor=JSON.parse(fs.readFileSync(parentDescriptor));
if(fileHash(parentDescriptor)!==parentDescriptorSha256||descriptor.engines.candidate.sha256!==parentEngineSha256)throw Error('Exact immutable-font engine descriptor differs');

if(!process.argv.includes('--stage-engine')){
 if(fs.existsSync(sourceDirectory))throw Error('Retain earlier source freeze');
 if(fileHash(abiFile)!==abiSha256)throw Error('Agreed particle ABI changed');
 const moduleDirectory=path.join(sourceDirectory,'engine_module/nwn_particle_reads');
 fs.mkdirSync(moduleDirectory,{recursive:true});
 const sourceModule=path.join(project,'tools/perf140/render/engine_module/nwn_particle_reads');
 const pins=[];
 for(const relative of ['config.py','SCsub','register_types.h','register_types.cpp','particle_reads.h','particle_reads.cpp']){
  const bytes=fs.readFileSync(path.join(sourceModule,relative));
  fs.writeFileSync(path.join(moduleDirectory,relative),bytes,{flag:'wx'});
  pins.push({relative,sha256:hash(bytes)});
 }
 const abiBytes=fs.readFileSync(abiFile);
 fs.writeFileSync(path.join(moduleDirectory,'nwn_particle_read_abi_v1.h'),abiBytes,{flag:'wx'});
 pins.push({relative:'nwn_particle_read_abi_v1.h',sha256:hash(abiBytes)});
 const manifest={version:1,moduleDirectory,pins,abi:{file:abiFile,sha256:abiSha256,revision:1,tableBytes:48,eligibilityBytes:16,transformBytes:56,features:31,order:'raw C++ Transform3D ROW0xyz,ROW1xyz,ROW2xyz,originxyz'},parentDescriptor,parentDescriptorSha256,parentEngineSha256,parentSourceManifest:parentFile,parentSourceManifestSha256:fileHash(parentFile),scope:'Stateless synchronous eligible/validate/miss-only transform C ABI; public getters and original conversion retained. No iterator, reverse callback, retained Node, batch snapshot, camera lease or unrelated experiment.',engineCopies:0,builds:0,engineStarts:0,gpuTests:0};
 fs.writeFileSync(sourceManifestFile,JSON.stringify(manifest,null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({file:sourceManifestFile,sha256:fileHash(sourceManifestFile),moduleDirectory,pins:pins.length,engineCopies:0,builds:0,engineStarts:0}));
}else{
 const freeze=JSON.parse(fs.readFileSync(sourceManifestFile));
 const parent=JSON.parse(fs.readFileSync(parentFile));
 const stage=path.join(base,engineLabel),source=path.join(stage,'source');
 if(fs.existsSync(stage))throw Error('Retain earlier engine stage');
 if(fileHash(parentFile)!==freeze.parentSourceManifestSha256||fileHash(parentDescriptor)!==freeze.parentDescriptorSha256||fileHash(descriptor.engines.candidate.path)!==freeze.parentEngineSha256)throw Error('Retained font parent changed');
 for(const pin of freeze.pins)if(fileHash(path.join(freeze.moduleDirectory,pin.relative))!==pin.sha256)throw Error('Frozen read source changed: '+pin.relative);
 for(const pin of parent.modulePins)if(fileHash(path.join(parent.moduleDirectory,pin.relative))!==pin.sha256)throw Error('Parent module changed');
 for(const module of parent.inheritedModules)for(const pin of module.pins)if(fileHash(path.join(module.directory,pin.relative))!==pin.sha256)throw Error('Inherited module changed');
 for(const guard of parent.guards)if(fileHash(guard.path)!==guard.sha256)throw Error('Retained/shared guard changed');
 const fontRelative=parent.fontPatch.relative,fontSource=path.join(parent.source,fontRelative);
 if(fileHash(fontSource)!==parent.fontPatch.afterSha256)throw Error('Retained immutable atlas source changed');
 fs.mkdirSync(stage,{recursive:true});
 // Full real copies including reusable objects; no hard links to retained work.
 fs.cpSync(parent.source,source,{recursive:true,preserveTimestamps:true,force:false,errorOnExist:true});
 const moduleDirectory=path.join(source,'modules/nwn_particle_reads');
 if(fs.existsSync(moduleDirectory))throw Error('New private module already exists');
 fs.mkdirSync(moduleDirectory,{recursive:true});
 for(const pin of freeze.pins)fs.copyFileSync(path.join(freeze.moduleDirectory,pin.relative),path.join(moduleDirectory,pin.relative));
 const inheritedModules=[{directory:path.join(source,path.relative(parent.source,parent.moduleDirectory)),pins:parent.modulePins},...parent.inheritedModules.map(module=>({...module,directory:path.join(source,path.relative(parent.source,module.directory))}))];
 const guards=[...parent.guards,{path:parentDescriptor,sha256:freeze.parentDescriptorSha256,kind:'retained-immutable-font-descriptor'},{path:descriptor.engines.candidate.path,sha256:freeze.parentEngineSha256,kind:'retained-immutable-font-engine'},{path:fontSource,sha256:parent.fontPatch.afterSha256,kind:'retained-immutable-font-source'},{path:path.join(source,fontRelative),sha256:parent.fontPatch.afterSha256,kind:'copied-immutable-font-source'},{path:abiFile,sha256:abiSha256,kind:'agreed-particle-C-ABI'}];
 for(const name of ['prepare-synchronous-particle-reads.mjs','build-engine-synchronous-particle-reads.ps1','finalize-engine-synchronous-particle-reads.mjs','check-synchronous-read-producer.mjs']){
  const file=path.join(project,'tools/perf140/render',name);
  guards.push({path:file,sha256:fileHash(file),kind:'synchronous-producer-tool-source'});
 }
 // Adapt the immutable source freeze to the replay driver's existing proof
 // schema. Pin the ACTUAL compiled module directory, not only its source copy.
 const moduleProofFile=path.join(stage,'module-source-proof.json');
 const moduleProof={version:1,module:moduleDirectory,pins:freeze.pins,abi:freeze.abi,sourceFreeze:{file:sourceManifestFile,sha256:fileHash(sourceManifestFile)},scope:freeze.scope};
 fs.writeFileSync(moduleProofFile,JSON.stringify(moduleProof,null,2)+'\n',{flag:'wx'});
 const manifest={...parent,directory:stage,source,reusedSource:undefined,parentDescriptor,parentDescriptorSha256:freeze.parentDescriptorSha256,moduleManifest:moduleProofFile,moduleManifestSha256:fileHash(moduleProofFile),sourceFreeze:moduleProof.sourceFreeze,moduleDirectory,modulePins:freeze.pins,inheritedModules,guards,variantDescription:freeze.scope,baselineRole:'Exact immutable-font0f8876 engine with all inherited runtime features',candidateRole:'Same engine with optional stateless synchronous particle read interface; use SAME candidate engine for ordinary/fused timing',copyPolicy:'Real copies only; archived engines, sources and shared outputs unchanged',buildStarted:false};
 fs.writeFileSync(path.join(stage,'manifest.json'),JSON.stringify(manifest,null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({stage,source,moduleDirectory,sourceManifestFile,guards:guards.length,builds:0,engineStarts:0}));
}
