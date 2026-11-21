'use strict';
// Copies the normal current-source closure, then overlays a reviewed collision
// candidate in a separately identified private project. Never builds or launches.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const fileHash=file=>sha(fs.readFileSync(file));
function requirePin(file,expected){if(!/^[a-f0-9]{64}$/.test(expected??'')||fileHash(file)!==expected)throw Error('Pin differs: '+file);}
function within(root,file){const relative=path.relative(path.resolve(root),path.resolve(file));if(!relative||relative.startsWith('..')||path.isAbsolute(relative))throw Error('Path escapes owned root');return relative;}
async function preparePrivateStage({project,label,buildProof,buildProofSha256,preferenceSeeds,integrationDirectory,sidecar=true,argv=['--performance-runtime=verified-native','--render-thread=separate','--light-input-registry=builtin','--loading-pipeline=ordinary','--detailed-profiling=off']}){
 project=path.resolve(project);within(path.join(project,'.cache/native-drive-numeric'),buildProof);
 requirePin(buildProof,buildProofSha256);const build=JSON.parse(fs.readFileSync(buildProof,'utf8').replace(/^\uFEFF/,''));
 if(build.success!==true||build.schema!=='nwn-drive-numeric-v1'||build.sharedDllWrites!==0||build.activeDescriptorWrites!==0||build.heightCapability!==false)throw Error('Unaccepted private build');
 for(const [file,pin] of Object.entries(build.sourcePins)){within(project,file);requirePin(file,pin);}
 const binary=path.join(path.dirname(buildProof),'nwn-drive-numeric.dll'),descriptor=path.join(path.dirname(buildProof),'private.gdextension');
 requirePin(binary,build.binarySha256);
 if(fileHash(descriptor)!==fileHash(path.join(project,'tools/native-drive-numeric/private.gdextension.in')))throw Error('Private descriptor differs');
 within(path.join(project,'.cache/native-presentation-parity/root/pause-fixes-v1/movement/numeric-sidecar-v1'),integrationDirectory);
 const integration=JSON.parse(fs.readFileSync(path.join(integrationDirectory,'proof.json'),'utf8'));
 const ownerRelative='systems/native_render/drive_collision_indexed.gd',candidate=path.join(integrationDirectory,'drive_collision_indexed.gd');
 requirePin(path.join(project,ownerRelative),integration.baseline);requirePin(candidate,integration.candidate);
 if(integration.sourceOnly!==true||integration.applied!==false)throw Error('Reviewed source-only overlay required');
 const identity=require(path.join(project,'tools/native-feature-manifest.cjs')).sourceIdentity;
 const before=identity(project).sha256;
 const base=await require(path.join(project,'tools/native-production-selection.cjs')).stageProductionSelection({project,label,preferenceSeeds,argv});
 // Preserve the base receipt, but remove the production-selector filename: this
 // overlay must be consumed by its private verifier, never as an ordinary run.
 const directory=path.dirname(base.file),sourceProject=base.selection.sourceProject;
 fs.renameSync(base.file,path.join(directory,'base-selection-before-overlay.json'));
 const pins=new Map(base.selection.pins.map(row=>[row.relative,row.sha256]));
 const write=(relative,bytes)=>{const target=path.join(sourceProject,relative);within(sourceProject,target);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,bytes);pins.set(relative,sha(bytes));};
 write(ownerRelative,fs.readFileSync(candidate));
 if(sidecar){
  write('native/drive_numeric/private.gdextension',fs.readFileSync(descriptor));
  write('native/drive_numeric/nwn-drive-numeric.dll',fs.readFileSync(binary));
  write('.godot/extension_list.cfg',Buffer.from(fs.readFileSync(path.join(sourceProject,'.godot/extension_list.cfg'),'utf8')+'res://native/drive_numeric/private.gdextension\n'));
 }
 if(identity(project).sha256!==before)throw Error('Working source changed during private staging');
 const result={version:1,kind:'private-drive-numeric-stage',production:false,complete:true,sourceProject,originalProject:project,mainSource:before,stagedSource:identity(sourceProject).sha256,baseSelectionSha256:base.sha256,engine:base.selection.runtime,buildProof:{file:path.resolve(buildProof),sha256:buildProofSha256},integration:{directory:path.resolve(integrationDirectory),baseline:integration.baseline,candidate:integration.candidate},sidecar,expectedModule:sidecar?{file:path.join(sourceProject,'native/drive_numeric/nwn-drive-numeric.dll'),sha256:build.binarySha256,descriptor:'res://native/drive_numeric/private.gdextension'}:null,pins:[...pins].map(([relative,sha256])=>({relative,sha256})),launches:0,sharedDllWrites:0,scope:'Nonlaunching isolated numeric correctness candidate; original normal source/runtime plus explicit reviewed owner overlay. No FPS or performance acceptance.'};
 const file=path.join(directory,'private-stage.json');fs.writeFileSync(file,JSON.stringify(result,null,2)+'\n',{flag:'wx'});
 const digest=fileHash(file);readPrivateStage(file,digest);return {file,sha256:digest,selection:result};
}
function readPrivateStage(file,expected){
 requirePin(file,expected);const value=JSON.parse(fs.readFileSync(file,'utf8'));
 if(value.version!==1||value.kind!=='private-drive-numeric-stage'||value.production!==false||value.complete!==true||path.resolve(value.sourceProject)!==path.join(path.dirname(path.resolve(file)),'project'))throw Error('Private stage policy differs');
 requirePin(path.join(path.dirname(path.resolve(file)),'base-selection-before-overlay.json'),value.baseSelectionSha256);
 const seen=new Set();
 for(const pin of value.pins){
  if(seen.has(pin.relative))throw Error('Duplicate private source pin');seen.add(pin.relative);
  const target=path.join(value.sourceProject,pin.relative);within(value.sourceProject,target);requirePin(target,pin.sha256);
 }
 const identity=require(path.join(value.originalProject,'tools/native-feature-manifest.cjs')).sourceIdentity;
 if(identity(value.sourceProject).sha256!==value.stagedSource)throw Error('Private staged source differs');
 requirePin(value.engine.executable,value.engine.executableSha256);
 const extensions=fs.readFileSync(path.join(value.sourceProject,'.godot/extension_list.cfg'),'utf8').trim().split(/\r?\n/);
 const expectedExtensions=['res://native/particle_kernel.gdextension','res://native/resource_index.gdextension'];
 if(value.sidecar){
  const relative='native/drive_numeric/nwn-drive-numeric.dll';
  if(value.expectedModule?.descriptor!=='res://native/drive_numeric/private.gdextension'||path.resolve(value.expectedModule.file)!==path.join(value.sourceProject,relative))throw Error('Private module path differs');
  if(!seen.has(relative)||!seen.has('native/drive_numeric/private.gdextension')||value.pins.find(pin=>pin.relative===relative).sha256!==value.expectedModule.sha256)throw Error('Private module missing from complete pins');
  requirePin(value.expectedModule.file,value.expectedModule.sha256);expectedExtensions.push(value.expectedModule.descriptor);
 }else if(value.expectedModule!==null||fs.existsSync(path.join(value.sourceProject,'native/drive_numeric/nwn-drive-numeric.dll')))throw Error('Absent-class control contains sidecar');
 if(JSON.stringify(extensions)!==JSON.stringify(expectedExtensions))throw Error('Private active extension list differs');
 return value;
}
module.exports={preparePrivateStage,readPrivateStage};
