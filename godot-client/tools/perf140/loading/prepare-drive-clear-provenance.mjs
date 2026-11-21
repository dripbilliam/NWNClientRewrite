// Source-prepared only until root grants a CPU/staging lane. No native build.
import fs from 'node:fs';import path from 'node:path';import {fileURLToPath} from 'node:url';import {digest} from './processor-graph.mjs';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),label=process.argv[2];
if(!/^drive-preview-clear-provenance-[a-z0-9-]+$/.test(label??''))throw Error('Fresh owned provenance successor label required');
const parentFile=path.join(project,'.cache/native-140fps/loading-agent/drive-preview-clear-v1/manifest.json'),parentBytes=fs.readFileSync(parentFile),parent=JSON.parse(parentBytes);
if(digest(parentBytes)!=='85f8eb412cc424c360ccd771271597bf8001135ac0af2eca037249c9edf57749')throw Error('Frozen clear V1 differs');
const buildFile=parent.build.file,buildBytes=fs.readFileSync(buildFile),build=JSON.parse(buildBytes.toString('utf8').replace(/^\uFEFF/,''));
if(digest(buildBytes)!=='f19c7f383953cf25b058daf51c06155fbaa019709b779e0da5231919578cb571'||parent.build.sha256!==digest(buildBytes)||!build.success||build.project!==parent.project||build.sharedOutputWrites!==0)throw Error('Actual private build proof differs');
const stage=path.join(project,'.cache/native-140fps/loading-agent',label),copy=path.join(stage,'project');if(fs.existsSync(stage))throw Error('Existing evidence preserved');
const pins=new Map(parent.pins.map(p=>[p.relative,p.sha256]));
for(const [relative,sha256]of Object.entries(build.sources))if(pins.get(relative)!==sha256)throw Error('Built native source inventory differs '+relative);
const dll='.cache/native-kernel/nwn-particle-kernel.dll',oldManifest='.cache/native-kernel/build-manifest.json',proofRelative='.cache/native-kernel/drive-clear-build-proof.json';
if(pins.has(proofRelative))throw Error('New receipt destination already exists');
if(build.binarySha256!=='101efc79d3c2985d2267d05f9ffbd01578d2f14bbf52bad575ef921cd2412417'||pins.get(dll)!==build.binarySha256)throw Error('Actual built DLL identity differs');
// Recheck every actual byte before creating the derivative. This can be a
// substantial staging/hash pass; do not execute during a live or GPU window.
for(const pin of parent.pins)if(digest(fs.readFileSync(path.join(parent.project,pin.relative)))!==pin.sha256)throw Error('Frozen V1 source drift '+pin.relative);
fs.mkdirSync(copy,{recursive:true});
for(const pin of parent.pins){const file=path.join(copy,pin.relative);fs.mkdirSync(path.dirname(file),{recursive:true});fs.copyFileSync(path.join(parent.project,pin.relative),file);}
const original=fs.readFileSync(path.join(copy,oldManifest));
if(digest(original)!==pins.get(oldManifest))throw Error('Inherited stale receipt drift');
const backup=path.join(stage,'originals',oldManifest);fs.mkdirSync(path.dirname(backup),{recursive:true});fs.writeFileSync(backup,original);
fs.writeFileSync(path.join(copy,proofRelative),buildBytes);pins.set(proofRelative,digest(buildBytes));
const sourceInventory=Object.entries(build.sources).map(([relative,sha256])=>({relative,sha256})).sort((a,b)=>a.relative.localeCompare(b.relative));
const kernelManifest={
 version:2,label,success:true,exit:0,binary:path.join(copy,dll),binarySha256:build.binarySha256,
 compiledTranslationUnit:'native/particle_kernel.cpp',compiledSourceRoot:build.project,relocatedSourceProject:copy,
 sourceInventory,sourceInventoryScope:'Conservative complete pinned native-source directory superset, not an asserted minimal translation-unit dependency closure.',
 sourceReceiptSha256:digest(buildBytes),sourceReceiptRelative:proofRelative,originalBuildReceipt:{file:buildFile,sha256:digest(buildBytes)},
 compiler:build.compiler,flags:build.flags,headerSha256:build.headerSha256,apiSha256:build.apiSha256,
 startedAt:build.startedAt,endedAt:build.endedAt,pureSourceSha256:build.pureSourceSha256,
 pureExit:0,pureSuite:'Private builder executed the pure drive-clear test and aborts before this native build if its exit is nonzero. Check-count evidence is separate from this compiler receipt.',
 isolatedNativeBuilds:1,successorCompilations:0,sharedNativeBuilds:0,changedSharedOutputs:[],engineStarts:0,serverConnections:0,
 guards:[dll,'.cache/native-resource-index/nwn-resource-index.dll','.cache/native-window/nwn-window-modes.exe'].map(relative=>({relative,sha256:pins.get(relative)})),
 guardsScope:'Actual successor binary byte guards checked during this copy; not relabeled original shared-output/build guards. The historical build receipt and stale ancestor remain separate.',
 compiledParent:{file:parentFile,sha256:digest(parentBytes)},
 inheritedReceipt:{relative:oldManifest,sha256:digest(original),backup,scope:'Stale ancestor build metadata preserved for audit only; not evidence for this DLL.'},
 successorScope:'Metadata-only source/DLL-identical derivative. No recompilation, new runtime acceptance, graphical test or performance claim. Original compiled source root is retained rather than relabeled as this copy.'
};
if(kernelManifest.guards.some(g=>!g.sha256))throw Error('Required binary guard absent');
fs.writeFileSync(path.join(copy,oldManifest),JSON.stringify(kernelManifest,null,2)+'\n');pins.set(oldManifest,digest(fs.readFileSync(path.join(copy,oldManifest))));
const changes=[{relative:oldManifest,before:digest(original),after:pins.get(oldManifest)},{relative:proofRelative,before:null,after:pins.get(proofRelative)}];
const manifest={...parent,label,stage,project:copy,candidate:copy,parent:{file:parentFile,sha256:digest(parentBytes)},changes,changed:changes,pins:[...pins].map(([relative,sha256])=>({relative,sha256})),compiledBuild:{file:buildFile,sha256:digest(buildBytes)},runtimeAcceptance:{inheritedGate:'drive-preview-gate-clear-v1/receipt.json',inheritedGateAppliesTo:'Identical runtime source and DLL; successor source guards/metadata and pending physical regression still require a fresh gate.',newTestsRun:false},scope:kernelManifest.successorScope};
for(const pin of manifest.pins)if(digest(fs.readFileSync(path.join(copy,pin.relative)))!==pin.sha256)throw Error('Successor staging drift '+pin.relative);
const file=path.join(stage,'manifest.json');fs.writeFileSync(file,JSON.stringify(manifest,null,2)+'\n');console.log(JSON.stringify({file,sha256:digest(fs.readFileSync(file)),binarySha256:build.binarySha256,internalManifestSha256:pins.get(oldManifest),changes,compilations:0}));
