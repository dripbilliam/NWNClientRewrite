// SOURCE-PREPARED runner. Stage/finalize perform substantial private copying
// and hashing: execute only in a root-scheduled CPU lane, never while gaming.
// This does not compile, start an engine, run a fixture or contact a server.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {digest} from './processor-graph.mjs';

const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const [label,mode]=process.argv.slice(2);
if(!/^terrain-height-build-[a-z0-9-]+$/.test(label??'')||!['stage','finalize'].includes(mode))throw Error('Fresh owned terrain-height-build label and explicit stage/finalize required');
const parentFile=path.join(project,'.cache/native-140fps/root/drive-clear-fenced-v2/manifest.json');
const parentSha='7a4a6a2728886b5d0de135e13e66ae829426414cac70289231fafd1974a7cb74';
const overlayFile=path.join(project,'.cache/native-140fps/loading-agent/terrain-height-integration-v1/source-overlay.json');
const overlaySha='a89f2889d7288c3225d9fff963bc6d5c9358be56e38044567f158663ba21d5a1';
const goldenSha='78f4b8e56251b0a87ef74a8cde93d94de1bf3ff229f4d390f3a8972c961e4421';
const baseDll='101efc79d3c2985d2267d05f9ffbd01578d2f14bbf52bad575ef921cd2412417';
const dll='.cache/native-kernel/nwn-particle-kernel.dll';
const kernelManifest='.cache/native-kernel/build-manifest.json';
const receiptRelative='.cache/native-kernel/terrain-height-build-proof.json';
const outputPins=new Map([
 ['native/particle_kernel.cpp','e642f2de8487b737201e36b997ee5405bd3c2279231bf384ed8e24cadd6f1102'],
 ['systems/native_render/terrain_surface.gd','06cc6fa37f68418697c89d8eed2c61ed65c39ca8c5b5fbd38a0ece87604e223e'],
 ['native/experimental/terrain_height_kernel.hpp','1f38c101efd7e45dc50c2ba1af1a053736914a5012a32aa95a19db078d2b796a'],
 ['native/terrain_height.hpp','3bc21f9280f4a76079fd926b4b944423ec100df31e23f4e379e69a6525715e21'],
 ['systems/native_render/terrain_height_cache.gd','a867b3b3949b92b624ae388ccd3f1d6be8b691cd67e9f7c50dbfa124ef9d2fc6']
]);
const stage=path.join(project,'.cache/native-140fps/loading-agent',label);
const copy=path.join(stage,'project'),draftFile=path.join(stage,'draft.json'),manifestFile=path.join(stage,'manifest.json');
const samePath=(a,b)=>typeof a==='string'&&typeof b==='string'&&path.resolve(a).toLowerCase()===path.resolve(b).toLowerCase();
const json=bytes=>JSON.parse(bytes.toString('utf8').replace(/^\uFEFF/,''));
const text=value=>Buffer.from(JSON.stringify(value,null,2)+'\n');
function rel(value){
 if(typeof value!=='string'||value.length===0||value.includes('\\')||path.isAbsolute(value)||value.split('/').some(part=>!part||part==='.'||part==='..')||value.includes(':'))throw Error('Unsafe relative pin');
 return value;
}
function file(root,relative){
 const result=path.resolve(root,rel(relative));
 if(!result.toLowerCase().startsWith(path.resolve(root).toLowerCase()+path.sep))throw Error('Pin escaped owner root');
 return result;
}
function regularBytes(filename){if(!fs.lstatSync(filename).isFile())throw Error('Regular pinned input required '+filename);return fs.readFileSync(filename);}
function readPinned(filename,sha){const bytes=regularBytes(filename);if(digest(bytes)!==sha)throw Error('Pinned bytes changed '+filename);return bytes;}
function pinMap(rows){
 if(!Array.isArray(rows)||rows.length===0||rows.length>100000)throw Error('Bounded pin inventory required');
 const result=new Map();for(const row of rows){rel(row.relative);if(result.has(row.relative)||!/^[0-9a-f]{64}$/.test(row.sha256??''))throw Error('Duplicate or invalid pin');result.set(row.relative,row.sha256);}return result;
}
function pinsArray(pins){return [...pins].map(([relative,sha256])=>({relative,sha256})).sort((a,b)=>a.relative.localeCompare(b.relative));}
function samePins(actual,expected,label){
 if(actual.size!==expected.size)throw Error(label+' inventory length differs');
 for(const [relative,sha]of expected)if(actual.get(relative)!==sha)throw Error(label+' pin differs '+relative);
}
function expectedPins(parent){const result=new Map(parent.pins);for(const [relative,sha]of outputPins)result.set(relative,sha);return result;}
function verifyProject(root,pins){for(const [relative,sha]of pins)readPinned(file(root,relative),sha);}
function freshWrite(filename,bytes){fs.mkdirSync(path.dirname(filename),{recursive:true});fs.writeFileSync(filename,bytes,{flag:'wx'});}
function replacePinned(filename,before,after){
 readPinned(filename,before);const temporary=filename+'.height-new';freshWrite(temporary,after);fs.renameSync(temporary,filename);
}
function parents(){
 const parentBytes=readPinned(parentFile,parentSha),parent=json(parentBytes),pins=pinMap(parent.pins);
 if(!samePath(parent.project,path.join(path.dirname(parentFile),'project'))||pins.get(dll)!==baseDll)throw Error('Frozen clear parent path/DLL differs');
 const overlayBytes=readPinned(overlayFile,overlaySha),overlay=json(overlayBytes);
 if(overlay.kind!=='source-only-overlay'||overlay.class!=='NwnTerrainHeight'||overlay.outputs?.length!==5||overlay.parent?.sha256!==parentSha||!samePath(overlay.parent?.project,parent.project)||!samePath(overlay.parent?.file,parentFile)||overlay.golden?.sha256!==goldenSha)throw Error('Frozen overlay provenance differs');
 const listed=pinMap(overlay.outputs);for(const [relative,sha]of outputPins)if(listed.get(relative)!==sha)throw Error('Unreviewed height overlay output '+relative);
 for(const row of overlay.outputs)if((row.beforeSha256??null)!==(pins.get(row.relative)??null))throw Error('Overlay parent seam differs '+row.relative);
 return {parent,parentBytes,pins,overlay,overlayBytes};
}
if(mode==='stage'){
 if(fs.existsSync(stage))throw Error('Existing source/build evidence preserved; use a new label');
 const p=parents();if(p.pins.has(receiptRelative))throw Error('New height proof slot already exists');
 const overlayRoot=path.join(path.dirname(overlayFile),'overlay');
 const overlayBytes=new Map([...outputPins].map(([relative,sha])=>[relative,readPinned(file(overlayRoot,relative),sha)]));
 const goldenBytes=readPinned(p.overlay.golden.file,goldenSha);if(json(goldenBytes).success!==true)throw Error('Accepted strict-kernel oracle missing');
 fs.mkdirSync(copy,{recursive:true});
 for(const [relative,sha]of p.pins)freshWrite(file(copy,relative),readPinned(file(p.parent.project,relative),sha));
 const pins=new Map(p.pins),changes=[];
 for(const [relative,bytes]of overlayBytes){
  const before=pins.get(relative)??null,target=file(copy,relative);
  if(before!==null){freshWrite(file(path.join(stage,'originals'),relative),readPinned(target,before));replacePinned(target,before,bytes);}else freshWrite(target,bytes);
  pins.set(relative,digest(bytes));changes.push({relative,before,after:digest(bytes)});
 }
 verifyProject(copy,pins);verifyProject(p.parent.project,p.pins);
 freshWrite(path.join(stage,'source-overlay-input.json'),p.overlayBytes);
 const nativeSourcePins=pinsArray(pins).filter(pin=>pin.relative.startsWith('native/'));
 const draft={version:1,label,kind:'unbuilt-height-native-candidate',stage,project:copy,candidate:copy,parent:{file:parentFile,sha256:parentSha,project:p.parent.project},sourceOverlay:{file:overlayFile,sha256:overlaySha,copiedReceipt:'source-overlay-input.json'},acceptedGolden:{file:p.overlay.golden.file,sha256:goldenSha},changes,pins:pinsArray(pins),nativeSourcePins,nativeInventoryScope:'Complete pinned native directory as a conservative compiler-input superset; not a claimed minimal include graph.',baseBinary:baseDll,buildOutput:path.join(stage,'build-output'),nativeBuilds:0,testOnly:false,launchable:false,scope:'Private source staging only. Parent DLL/build manifest are historical until a fresh native build and finalize succeed. No runtime, authority, graphical or performance acceptance.'};
 freshWrite(draftFile,text(draft));console.log(JSON.stringify({file:draftFile,sha256:digest(regularBytes(draftFile)),project:copy,sourceOutputs:changes.length,nativeBuilds:0,launchable:false}));
}else{
 if(fs.existsSync(manifestFile))throw Error('Finalized evidence preserved');
 const p=parents(),draftBytes=regularBytes(draftFile),draft=json(draftBytes),pins=pinMap(draft.pins);
 if(draft.kind!=='unbuilt-height-native-candidate'||draft.label!==label||!samePath(draft.project,copy)||!samePath(draft.stage,stage)||draft.parent?.sha256!==parentSha||draft.sourceOverlay?.sha256!==overlaySha||draft.baseBinary!==baseDll||draft.launchable!==false)throw Error('Original draft/candidate provenance differs');
 if(digest(regularBytes(path.join(stage,'source-overlay-input.json')))!==overlaySha)throw Error('Staged overlay receipt drift');
 const expected=expectedPins(p);samePins(pins,expected,'Five-output candidate');
 if(!Array.isArray(draft.changes)||draft.changes.length!==5)throw Error('Expected exactly five source changes');
 const changePins=new Map();for(const row of draft.changes){if(changePins.has(row.relative)||(row.before??null)!==(p.pins.get(row.relative)??null)||row.after!==outputPins.get(row.relative))throw Error('Unreviewed source change');changePins.set(row.relative,row.after);}samePins(changePins,outputPins,'Source changes');
 const buildFile=path.join(stage,'build-output/build-proof.json'),buildBytes=regularBytes(buildFile),build=json(buildBytes);
 const builtBinary=path.join(stage,'build-output/nwn-particle-kernel.dll'),binary=regularBytes(builtBinary),binarySha=digest(binary);
 if(build.success!==true||build.exit!==0||build.kind!=='isolated-terrain-height-native-build'||build.testOnly!==false||build.sharedOutputWrites!==0||build.nativeBuilds!==1||build.engineStarts!==0||build.sourceOverlaySha256!==overlaySha||build.draftSha256!==digest(draftBytes)||!samePath(build.compiledSourceRoot,copy)||!samePath(build.sourceProject,copy)||!samePath(build.binary,builtBinary)||build.binarySha256!==binarySha||binarySha===baseDll)throw Error('Actual private compilation/source/binary correlation differs');
 if(build.builder?.copiedInput!=='builder.input.ps1'||!/^[0-9a-f]{64}$/.test(build.builder?.sha256??'')||digest(regularBytes(path.join(stage,'build-output/builder.input.ps1')))!==build.builder.sha256)throw Error('Actual builder input proof differs');
 const args=build.arguments,prefix=['/nologo','/O2','/fp:strict','/EHsc','/W4','/WX','/std:c++17','/MD','/LD','/I'];
 if(build.flags!=='/O2 /fp:strict /EHsc /W4 /WX /std:c++17 /MD /LD'||!Array.isArray(args)||args.length!==15||prefix.some((arg,index)=>args[index]!==arg)||!samePath(args[10],path.join(project,'.tools/extension-api'))||!samePath(args[11],path.join(copy,'native/particle_kernel.cpp'))||!args[12].startsWith('/Fe:')||!samePath(args[12].slice(4),builtBinary)||args[13]!=='/link'||args[14]!=='/INCREMENTAL:NO'||!path.isAbsolute(build.compilerFile??'')||!/^[0-9a-f]{64}$/.test(build.compilerSha256??''))throw Error('Exact strict compiler invocation differs');
 const native=pinMap(draft.nativeSourcePins),actual=pinMap(build.sourceInventory);
 samePins(native,new Map([...expected].filter(([relative])=>relative.startsWith('native/'))),'Draft native source');samePins(actual,native,'Compiled native source');
 if(build.abi?.version!=='Godot Engine v4.7.2.stable.official'||build.abi?.precision!=='single'||build.abi?.buildConfiguration!=='float_64'||build.abi?.sizes?.PackedFloat64Array!==16||build.abi?.sizes?.PackedByteArray!==16||build.headerSha256!=='640b48188708ba0016f8d7ace9e0e1d3279a41fa1226c59ff3193b15538bd254'||build.apiSha256!=='d0e4c08c03b165156dabe6bfb6a906baf0069189f62035341230a246c86d6986')throw Error('Pinned packed-reference ABI proof differs');
 verifyProject(copy,pins);verifyProject(p.parent.project,p.pins);
 const oldDll=readPinned(file(copy,dll),baseDll),oldKernel=readPinned(file(copy,kernelManifest),pins.get(kernelManifest));
 freshWrite(file(path.join(stage,'originals'),dll),oldDll);freshWrite(file(path.join(stage,'originals'),kernelManifest),oldKernel);
 const proofSha=digest(buildBytes);freshWrite(file(copy,receiptRelative),buildBytes);pins.set(receiptRelative,proofSha);
 replacePinned(file(copy,dll),baseDll,binary);pins.set(dll,binarySha);
 const guards=[dll,'.cache/native-resource-index/nwn-resource-index.dll','.cache/native-window/nwn-window-modes.exe'].map(relative=>({relative,sha256:pins.get(relative)}));if(guards.some(row=>!row.sha256))throw Error('Candidate binary guard absent');
 const kernel={version:3,label,success:true,exit:0,binary:file(copy,dll),binarySha256:binarySha,compiledTranslationUnit:'native/particle_kernel.cpp',compiledSourceRoot:build.compiledSourceRoot,relocatedSourceProject:copy,sourceInventory:build.sourceInventory,sourceInventoryScope:draft.nativeInventoryScope,sourceReceiptSha256:proofSha,sourceReceiptRelative:receiptRelative,originalBuildReceipt:{file:buildFile,sha256:proofSha},compiler:build.compiler,compilerSha256:build.compilerSha256,flags:build.flags,headerSha256:build.headerSha256,apiSha256:build.apiSha256,abi:build.abi,startedAt:build.startedAt,endedAt:build.endedAt,compiledParent:draft.parent,sourceOverlay:draft.sourceOverlay,acceptedGolden:draft.acceptedGolden,sourceGoldenExecutedByThisBuild:false,isolatedNativeBuilds:1,successorCompilations:1,sharedNativeBuilds:0,changedSharedOutputs:[],engineStarts:0,serverConnections:0,guards,guardsScope:'Actual candidate bytes; historical parent DLL/metadata are backed up and not reused as proof for this new DLL.',testOnly:false,scope:'A separately compiled optional numeric height provider. Existing clear/physical sources retained. Native/caller/golden/physical regression, original-local authority, visual and performance gates are pending.'};
 const kernelBytes=text(kernel);replacePinned(file(copy,kernelManifest),pins.get(kernelManifest),kernelBytes);pins.set(kernelManifest,digest(kernelBytes));
 const changes=[...draft.changes,{relative:dll,before:baseDll,after:binarySha},{relative:kernelManifest,before:digest(oldKernel),after:digest(kernelBytes)},{relative:receiptRelative,before:null,after:proofSha}];
 verifyProject(copy,pins);
 const manifest={...draft,kind:'compiled-height-native-candidate',launchable:true,nativeBuilds:1,pins:pinsArray(pins),changes,changed:changes,build:{file:buildFile,sha256:proofSha},draft:{file:draftFile,sha256:digest(draftBytes)},kernelManifest:{relative:kernelManifest,sha256:digest(kernelBytes)},flags:['--drive-collision=indexed','--drive-clear=native','--terrain-height=native'],defaultHeightRoute:'script',preparedCacheDescriptorRegenerated:false,runtimeAcceptance:{testsRun:false,newNativeClassValidated:false,authority:false,graphics:false},graphics:0,serverConnections:0,sharedNativeBuilds:0,scope:kernel.scope};
 freshWrite(manifestFile,text(manifest));console.log(JSON.stringify({file:manifestFile,sha256:digest(regularBytes(manifestFile)),binarySha256:binarySha,compiledSourceRoot:kernel.compiledSourceRoot,relocatedSourceProject:copy,runtimeAccepted:false}));
}
