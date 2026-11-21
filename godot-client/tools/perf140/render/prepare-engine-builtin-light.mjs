import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const [label='engine-builtin-light-v1',freezeLabel='builtin-light-source-v1',reuseLabel]=process.argv.slice(2);
if(![label,freezeLabel,...(reuseLabel?[reuseLabel]:[])].every(value=>/^[a-z0-9-]+$/.test(value)))throw Error('Private labels required');
const base=path.join(project,'.cache/native-140fps/render-agent'),stage=path.join(base,label),freeze=path.join(base,freezeLabel);
if(fs.existsSync(stage)||fs.existsSync(freeze))throw Error('Existing private evidence preserved');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex'),fileHash=f=>hash(fs.readFileSync(f));
const parentFolder=path.join(base,'engine-scene-snapshot-thread-v1'),parentFile=path.join(parentFolder,'manifest.json'),parent=JSON.parse(fs.readFileSync(parentFile));
const descriptorFile=path.join(parentFolder,'engine-descriptor.json'),descriptor=JSON.parse(fs.readFileSync(descriptorFile));
if(fileHash(descriptorFile)!=='6d1b1f80140ab637de50d00407c9211d0f69b8c691d68c214db55e659f91d4ff')throw Error('Frozen snapshot-thread descriptor changed');
if(fileHash(descriptor.engines.candidate.path)!==descriptor.engines.candidate.sha256)throw Error('Frozen snapshot-thread engine changed');
for(const pin of parent.modulePins)if(fileHash(path.join(parent.moduleDirectory,pin.relative))!==pin.sha256)throw Error('Parent snapshot source drift');
if(fileHash(path.join(parent.source,parent.nodePatch.relative))!==parent.nodePatch.afterSha256)throw Error('Parent cached-owner accessor drift');
fs.mkdirSync(freeze,{recursive:true});
const moduleName='nwn_light_input_registry',sourceModule=path.join(project,'tools/perf140/render/engine_module',moduleName),frozenModule=path.join(freeze,'engine-module',moduleName),pins=[];
fs.mkdirSync(frozenModule,{recursive:true});
for(const relative of ['config.py','SCsub','register_types.h','register_types.cpp','light_input_registry.h','light_input_registry.cpp']){const bytes=fs.readFileSync(path.join(sourceModule,relative));fs.writeFileSync(path.join(frozenModule,relative),bytes,{flag:'wx'});pins.push({relative,sha256:hash(bytes)});}
const fixtures=[];
for(const relative of ['tests/native_perf140_render_builtin_light_registry_test.gd','tools/perf140/render/focus_lighting_builtin_input_candidate.gd']){const bytes=fs.readFileSync(path.join(project,relative)),destination=path.join(freeze,relative);fs.mkdirSync(path.dirname(destination),{recursive:true});fs.writeFileSync(destination,bytes,{flag:'wx'});fixtures.push({relative,file:destination,sha256:hash(bytes)});}
const referenceFolder=path.join(project,'.cache/native-140fps/root/lease-scene-diagnostics-v1/project');
const references=['native/experimental/light_input_registry.hpp','systems/native_render/focus_lighting_native_input_candidate.gd'].map(relative=>({relative,file:path.join(referenceFolder,relative),sha256:fileHash(path.join(referenceFolder,relative))}));
const sourceReceipt={version:1,label:freezeLabel,module:frozenModule,pins,fixtures,references,metadata:'NEW class uses Variant/Variant dispatch with strict old body/error conversions; no custom MethodBind and no old class modification.',builds:0};
const sourceReceiptFile=path.join(freeze,'manifest.json');fs.writeFileSync(sourceReceiptFile,JSON.stringify(sourceReceipt,null,2),{flag:'wx'});
let copySource=parent.source,reusedSource=null;
if(reuseLabel){
 const reusedFile=path.join(base,reuseLabel,'manifest.json'),reused=JSON.parse(fs.readFileSync(reusedFile));
 if(!path.resolve(reused.source).startsWith(path.join(base,reuseLabel)+path.sep))throw Error('Reuse source escaped private stage');
 for(const pin of reused.modulePins)if(fileHash(path.join(reused.moduleDirectory,pin.relative))!==pin.sha256)throw Error('Unsuccessful source reuse changed');
 for(const module of reused.inheritedModules??[])for(const pin of module.pins)if(fileHash(path.join(module.directory,pin.relative))!==pin.sha256)throw Error('Inherited reuse source changed');
 if(fileHash(path.join(reused.source,parent.nodePatch.relative))!==parent.nodePatch.afterSha256)throw Error('Reuse Node accessor changed');
 if(fileHash(path.join(reused.source,'servers/rendering/rendering_server_default.cpp'))!==parent.changedTargetSha256)throw Error('Reuse RD source changed');
 copySource=reused.source;reusedSource={manifest:reusedFile,manifestSha256:fileHash(reusedFile),modulePins:reused.modulePins};
}
const source=path.join(stage,'source');
if(!source.startsWith(stage+path.sep)||!path.resolve(parent.source).startsWith(parentFolder+path.sep))throw Error('Engine copy escaped explicit stages');
fs.mkdirSync(stage,{recursive:true});
fs.cpSync(copySource,source,{recursive:true,preserveTimestamps:true,force:false,errorOnExist:true});
const moduleDirectory=path.join(source,'modules',moduleName);
if(fs.existsSync(moduleDirectory)){
 if(!reusedSource)throw Error('Parent unexpectedly has builtin light class');
 for(const pin of reusedSource.modulePins)if(fileHash(path.join(moduleDirectory,pin.relative))!==pin.sha256)throw Error('Copied previous light source changed');
 for(const pin of pins)fs.copyFileSync(path.join(frozenModule,pin.relative),path.join(moduleDirectory,pin.relative));
}else fs.cpSync(frozenModule,moduleDirectory,{recursive:true,preserveTimestamps:true,force:false,errorOnExist:true});
const inheritedModule={directory:path.join(source,'modules/nwn_particle_snapshot'),pins:parent.modulePins};
for(const pin of inheritedModule.pins)if(fileHash(path.join(inheritedModule.directory,pin.relative))!==pin.sha256)throw Error('Copied inherited snapshot changed');
if(fileHash(path.join(source,parent.nodePatch.relative))!==parent.nodePatch.afterSha256)throw Error('Copied Node accessor changed');
const guards=[...parent.guards,{path:descriptor.engines.candidate.path,sha256:descriptor.engines.candidate.sha256,kind:'thread-preflight-baseline'}];
for(const guard of guards)if(fileHash(guard.path)!==guard.sha256)throw Error('Shared/retained guard changed');
const manifest={version:1,directory:stage,source,reusedSource,initialSourceState:'patched',originalRepository:'https://github.com/godotengine/godot',originalCommit:parent.originalCommit,archiveSha256:parent.archiveSha256,originalTargetSha256:parent.originalTargetSha256,changedTargetSha256:parent.changedTargetSha256,parentDescriptor:descriptorFile,parentDescriptorSha256:fileHash(descriptorFile),moduleManifest:sourceReceiptFile,moduleManifestSha256:fileHash(sourceReceiptFile),moduleDirectory,modulePins:pins,inheritedModules:[inheritedModule],nodePatch:parent.nodePatch,resolvedParentFeatures:parent.resolvedParentFeatures,guards,variantDescription:'Fresh optional builtin light registry on the exact cached-thread-preflight snapshot engine; no snapshot/Node/occlusion changes. Compare old/new registry modes on the SAME engine.',baselineRole:'corrected RD + cached-thread snapshot; no builtin light class',candidateRole:'same engine plus optional builtin light class (default off)',copyPolicy:'Real full copies, no hard links or mutations of retained engines/source',sharedSourceChanged:false,sharedEngineChanged:false,buildStarted:false};
fs.writeFileSync(path.join(stage,'manifest.json'),JSON.stringify(manifest,null,2),{flag:'wx'});
console.log(JSON.stringify({stage,sourceFreeze:sourceReceiptFile,sourceFreezeSha256:fileHash(sourceReceiptFile),modulePins:pins.length,inheritedModules:1,guards:guards.length,engineStarts:0}));
