// Deferred staging only: requires the reviewed, compiled PRODUCTION consumer.
// No test-only access binding is permitted in the timed renderer. Do not run
// this copy/hash pass during the user's game or another benchmark window.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {stage,hash} from './stage_library.mjs';
import {engineReadSourceComposition,engineReadV2BuildInvocation,CONSUMER_V2_MANIFEST_SHA,CONSUMER_V2_COMPOSE_SHA,CONSUMER_V2_BUILDER_SHA} from './engine_read_successor.mjs';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const [sourceArg,expectedSha,successorSha]=process.argv.slice(2),sourceFile=path.resolve(sourceArg??'');
const agentRoot=path.join(project,'.cache/native-140fps/particles-agent');
if(!/^[a-f0-9]{64}$/.test(expectedSha??'')||!sourceFile.startsWith(agentRoot+path.sep)||path.basename(sourceFile)!=='candidate-built-sources.json')throw Error('Explicit reviewed private production build receipt and SHA required');
const sourceBytes=fs.readFileSync(sourceFile);if(hash(sourceBytes)!==expectedSha)throw Error('Reviewed production receipt differs');
const source=JSON.parse(sourceBytes);
const parentFile=path.join(project,'.cache/native-140fps/root/builtin-light-fenced-v2/manifest.json');
if(hash(fs.readFileSync(parentFile))!=='672a89f094e3f8b845175b947556e3ca9b8c3bb4bd0e149a8f79058ad2cdc0d9')throw Error('Frozen renderer parent differs');
const parent=JSON.parse(fs.readFileSync(parentFile));
const overlayFile=path.join(agentRoot,'synchronous-engine-read-integration-v1/source-overlay.json');
const overlaySha='8af556f79785a0468f25cd9c87792e40da1f121eecd3a7ba81b0a7462da77e1b';
if(hash(fs.readFileSync(overlayFile))!==overlaySha||source.sourceOverlay?.sha256!==overlaySha||path.resolve(source.sourceOverlay.file)!==overlayFile)throw Error('Frozen production overlay differs');
const overlay=JSON.parse(fs.readFileSync(overlayFile));
const successorFile=path.join(agentRoot,'synchronous-engine-read-consumer-v2/source-manifest.json');
let successor=null;
if(successorSha!==undefined){
 if(successorSha!==CONSUMER_V2_MANIFEST_SHA||hash(fs.readFileSync(successorFile))!==successorSha)throw Error('Explicit reviewed ConsumerV2 manifest differs');
 successor=JSON.parse(fs.readFileSync(successorFile));
 if(path.resolve(successor.parentProductionOverlay.file)!==overlayFile)throw Error('ConsumerV2 overlay path differs');
}
const productionOutputs=engineReadSourceComposition(overlay,successor,successorSha);
const successorMatches=value=>successor?value?.sha256===successorSha&&typeof value.file==='string'&&path.resolve(value.file)===successorFile:value==null;
if(!successorMatches(source.consumerSuccessor))throw Error('Built consumer succession is absent or was not explicitly requested');
if(!source.isolatedBuildFinalized||source.testOnly!==false||source.sharedNativeBuilds!==0||source.parent?.sha256!=='20fab7baae2500eb4e45a95e77da68a2f4f913b52fe252666e1f2fa81a1afd14'||hash(fs.readFileSync(source.parent.file))!==source.parent.sha256)throw Error('Production build lineage differs');
const baselineBytes=fs.readFileSync(source.baselineReceipt.file);
if(hash(baselineBytes)!==source.baselineReceipt.sha256)throw Error('Compiled baseline receipt differs');
const baseline=JSON.parse(baselineBytes),before=new Map(baseline.sourcePins.map(p=>[p.relative,p.sha256])),after=new Map(source.sourcePins.map(p=>[p.relative,p.sha256]));
const runtimeSources=productionOutputs.map(p=>p.relative).sort();
const dll='.cache/native-kernel/nwn-particle-kernel.dll',metadataRelative='.cache/native-kernel/build-manifest.json';
const expected=[...runtimeSources,dll,metadataRelative].sort();
const actual=[...new Set([...before.keys(),...after.keys()])].filter(relative=>before.get(relative)!==after.get(relative)).sort();
if(JSON.stringify(actual)!==JSON.stringify(expected))throw Error('Production build contains unrelated or test-only changes');
for(const pin of productionOutputs)if(after.get(pin.relative)!==pin.sha256)throw Error('Reviewed consumer source differs: '+pin.relative);
for(const input of overlay.inputs)if(before.get(input.relative)!==input.beforeSha256)throw Error('Consumer source seam differs: '+input.relative);
const buildBytes=fs.readFileSync(source.build.file),build=JSON.parse(buildBytes);
if(hash(buildBytes)!==source.build.sha256||!build.success||build.exit!==0||build.sharedNativeBuilds!==0||build.isolatedNativeBuilds!==1||build.changedSharedOutputs?.length!==0||build.binarySha256!==after.get(dll)||hash(fs.readFileSync(build.binary))!==after.get(dll))throw Error('Actual production compile proof differs');
if(build.flags!=='/O2 /fp:strict /EHsc /W4 /WX /std:c++17 /MD /LD')throw Error('Production compiler flags differ');
const composeFile=path.join(agentRoot,'synchronous-engine-read-compose-v2/source-manifest.json');
if(successor){
 const builderFile=path.join(path.dirname(composeFile),'build_v2.ps1');
 if(hash(fs.readFileSync(composeFile))!==CONSUMER_V2_COMPOSE_SHA||hash(fs.readFileSync(builderFile))!==CONSUMER_V2_BUILDER_SHA)throw Error('Reviewed V2 build tools differ');
 engineReadV2BuildInvocation(build,source.sourceProject,path.join(project,'.tools/extension-api'),builderFile);
 if(hash(fs.readFileSync(build.actualInvocation.compilerFile))!==build.actualInvocation.compilerSha256)throw Error('Actual V2 compiler bytes differ');
}
const prebuildBytes=fs.readFileSync(source.prebuildReceipt.file);
if(hash(prebuildBytes)!==source.prebuildReceipt.sha256||build.sourceReceiptSha256!==source.prebuildReceipt.sha256)throw Error('Actual compiled source receipt differs');
const prebuild=JSON.parse(prebuildBytes);
if(!successorMatches(prebuild.consumerSuccessor))throw Error('Actual compiled source succession differs');
const samePath=(a,b)=>typeof a==='string'&&typeof b==='string'&&path.resolve(a).toLowerCase()===path.resolve(b).toLowerCase();
if(!samePath(prebuild.sourceProject,source.sourceProject)||!samePath(build.binary,path.join(source.sourceProject,dll)))throw Error('Actual compilation root or binary location differs; do not relabel a relocated derivative');
for(const pin of prebuild.sourcePins)if(![dll,metadataRelative].includes(pin.relative)&&after.get(pin.relative)!==pin.sha256)throw Error('Source changed during compile: '+pin.relative);
const originalMetadataFile=path.join(source.sourceProject,metadataRelative),originalMetadataBytes=fs.readFileSync(originalMetadataFile);
if(hash(originalMetadataBytes)!==after.get(metadataRelative)||hash(originalMetadataBytes)!==hash(buildBytes))throw Error('Actual internal compile metadata differs');
const label=successor?'engine-reads-fenced-v2':'engine-reads-fenced-v1',folder=path.join(project,'.cache/native-140fps/root',label),draft=folder+'-draft';
if(fs.existsSync(folder)||fs.existsSync(draft))throw Error('Existing derivative evidence preserved');
fs.mkdirSync(draft);
const changes=runtimeSources.concat(dll).map(relative=>({relative,from:path.join(source.sourceProject,relative),before:parent.pins.find(p=>p.relative===relative)?.sha256??null,after:after.get(relative)}));
for(const c of changes)if(c.relative!==dll&&c.before!==(before.get(c.relative)??null))throw Error('Renderer source seam differs: '+c.relative);
// Retain the actual compile root and receipt; relocating a DLL is no new build.
const metadata={...build,...(successor?{consumerSuccessor:{file:successorFile,sha256:successorSha}}:{}),compiledSourceRoot:source.sourceProject,compiledBinary:build.binary,binary:path.join(folder,'project',dll),relocatedSourceProject:path.join(folder,'project'),originalBuildReceipt:{file:source.build.file,sha256:source.build.sha256},originalInternalMetadata:{file:originalMetadataFile,sha256:hash(originalMetadataBytes)},successorCompilations:0,relocationScope:'Root source/DLL-identical copy of actual production build; no compilation occurred in this renderer copy.'};
const metadataFile=path.join(draft,'build-manifest.json');fs.writeFileSync(metadataFile,JSON.stringify(metadata,null,2)+'\n',{flag:'wx'});
changes.push({relative:metadataRelative,from:metadataFile,before:parent.pins.find(p=>p.relative===metadataRelative).sha256,after:hash(fs.readFileSync(metadataFile))});
const entryRelative='native_live_world.gd';let entry=fs.readFileSync(path.join(parent.project,entryRelative),'utf8');
const old='preload("res://tools/perf140/driver/particle_modes_dump.gd").capture(world)';
if(entry.split(old).length!==2)throw Error('Cold particle export seam differs');
entry=entry.replace(old,'preload("res://tools/perf140/driver/engine_read_modes_dump.gd").capture(world)');
const entryFile=path.join(draft,entryRelative);fs.writeFileSync(entryFile,entry,{flag:'wx'});
changes.push({relative:entryRelative,from:entryFile,before:parent.pins.find(p=>p.relative===entryRelative).sha256,after:hash(Buffer.from(entry))});
const helper='tools/perf140/driver/engine_read_modes_dump.gd',helperFile=path.join(project,helper);
changes.push({relative:helper,from:helperFile,before:null,after:hash(fs.readFileSync(helperFile))});
console.log(JSON.stringify(stage(project,parentFile,label,changes,[sourceFile,overlayFile,source.build.file,source.prebuildReceipt.file,...(successor?[successorFile,composeFile]:[])])));
