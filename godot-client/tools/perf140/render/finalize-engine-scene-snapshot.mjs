import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const [stageLabel='engine-scene-snapshot-v1',runLabel='build-1793900627491']=process.argv.slice(2);
if(![stageLabel,runLabel].every(v=>/^[a-z0-9-]+$/.test(v)))throw Error('Private labels required');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex'),fileHash=f=>hash(fs.readFileSync(f));
const stage=path.join(project,'.cache/native-140fps/render-agent',stageLabel),manifestFile=path.join(stage,'manifest.json'),manifest=JSON.parse(fs.readFileSync(manifestFile));
const run=path.join(stage,runLabel),receiptFile=path.join(run,'receipt.json'),receipt=JSON.parse(fs.readFileSync(receiptFile)),invocationFile=path.join(run,'invocation.json'),invocation=JSON.parse(fs.readFileSync(invocationFile));
if(receipt.exitCode!==0||!receipt.sourceUnchanged)throw Error('Engine build did not pass');
for(const pin of manifest.modulePins)if(fileHash(path.join(manifest.moduleDirectory,pin.relative))!==pin.sha256)throw Error('Module changed: '+pin.relative);
for(const module of manifest.inheritedModules??[])for(const pin of module.pins)if(fileHash(path.join(module.directory,pin.relative))!==pin.sha256)throw Error('Inherited module changed: '+pin.relative);
for(const guard of manifest.guards)if(fileHash(guard.path)!==guard.sha256)throw Error('Guard changed: '+guard.path);
const parent=JSON.parse(fs.readFileSync(manifest.parentDescriptor));
const baseline=parent.engines.candidate??parent.engines.patched;
if(fileHash(manifest.parentDescriptor)!==manifest.parentDescriptorSha256)throw Error('Retained parent descriptor changed');
const binary=receipt.outputs.find(output=>output.path.endsWith('godot.windows.template_release.x86_64.exe'));
if(!binary||fileHash(binary.path)!==binary.sha256)throw Error('New archived engine changed');
if(JSON.stringify(baseline.arguments)!==JSON.stringify(invocation.arguments))throw Error('Compiler flags differ from corrected baseline');
if(manifest.nodePatch){
 if(fileHash(path.join(manifest.source,manifest.nodePatch.relative))!==manifest.nodePatch.afterSha256)throw Error('Node accessor source changed');
 if(fileHash(manifest.nodePatch.sourceFile)!==manifest.nodePatch.beforeSha256)throw Error('Retained original Node header changed');
}
const descriptor={
 version:1,
 scope:manifest.variantDescription??'Private additive builtin scene snapshot experiment; baseline and candidate both include the already-proven RD shutdown fix. No front-face occlusion patch and no production engine replacement.',
 sourceCommit:manifest.originalCommit,sourceArchiveSha256:manifest.archiveSha256,resolvedFeatures:manifest.resolvedParentFeatures,
 moduleManifest:manifest.moduleManifest,moduleManifestSha256:manifest.moduleManifestSha256,modulePins:manifest.modulePins,
 nodePatch:manifest.nodePatch??null,
 sourceManifest:manifestFile,sourceManifestSha256:fileHash(manifestFile),retainedPairedEnginesUnchanged:true,sharedOutputsUnchanged:true,
 engines:{
  baseline:{...baseline,role:manifest.baselineRole??(manifest.nodePatch?'corrected RD plus snapshot V3 baseline with allocating thread preflight':'corrected RD engine without optional snapshot class')},
  candidate:{path:binary.path,sha256:binary.sha256,bytes:binary.bytes,buildReceipt:receiptFile,buildReceiptSha256:fileHash(receiptFile),invocation:invocationFile,invocationSha256:fileHash(invocationFile),arguments:invocation.arguments,compilerSha256:invocation.compilerSha256,buildExitCode:0,sourceUnchanged:true,role:manifest.candidateRole??(manifest.nodePatch?'corrected RD plus snapshot with cached thread preflight / validate-only skip':'corrected RD engine plus 7-file opt-in builtin snapshot module')}
 },
 warnings:['Optional WinRT, AccessKit and ANGLE SDKs unavailable, same as corrected baseline. Vulkan and ordinary OpenGL remain enabled.',...(manifest.nodePatch?[]:['Module v3 compiled with one GCC enum/non-enum conditional warning at scene_snapshot.cpp50; no compiler error.'])],
 gpuTests:0,performanceAccepted:false
};
const file=path.join(stage,'engine-descriptor.json');fs.writeFileSync(file,JSON.stringify(descriptor,null,2),{flag:'wx'});
console.log(JSON.stringify({descriptor:file,sha256:fileHash(file),candidate:descriptor.engines.candidate,sharedOutputsUnchanged:true}));
