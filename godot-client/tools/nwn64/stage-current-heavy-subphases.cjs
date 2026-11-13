'use strict';
// Stage one private original G2 replay with the previously validated C2
// diagnostic kernel. This script performs no build, launch or source edit.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const scope=path.join(root,'.cache/nwn64/current-heavy-subphases-b');
const referenceFile=path.join(root,'.cache/native-presentation-parity/production-replay/nwn62-completion-tail-c/production-selection.json');
const receiptFile=path.join(root,'.cache/native-render-gap/particles/nwn64-preparation-c/kernel-build/build-receipt.json');
const acceptedDll=path.join(root,'.cache/native-kernel/nwn-particle-kernel.dll');
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const read=file=>JSON.parse(fs.readFileSync(file,'utf8').replace(/^\uFEFF/,''));
const write=(file,value)=>fs.writeFileSync(file,JSON.stringify(value,null,2)+'\n',{flag:'wx'});
const replaceOnce=(file,before,after)=>{const source=fs.readFileSync(file,'utf8');assert.equal(source.split(before).length,2,'Diagnostic seam changed: '+file);fs.writeFileSync(file,source.replace(before,after));};
async function main(){
 assert(!fs.existsSync(scope),'Preserve prior diagnostic capsule');
 const acceptedHash='485741af15f0581a3c60c0f9a8ae738888eba08716c7a5c2c2d1bd550828963d';
 const receipt=read(receiptFile);assert(receipt.success&&receipt.exit===0&&sha(receipt.binary)===receipt.binarySha256&&sha(acceptedDll)===acceptedHash);
 const reference=read(referenceFile);assert(reference.complete&&reference.production);
 const seeds={version:1,expected:reference.preferences.expected,description:'Private C2 particle subphase G2 diagnostic'};
 for(const name of ['render','layout'])seeds[name]={file:reference.preferences[name].source,sha256:reference.preferences[name].sha256};
 const selector=require(path.join(root,'tools/native-production-selection.cjs'));
 const staged=await selector.stageProductionSelection({project:root,label:'nwn64-current-heavy-subphases-b',argv:reference.options,preferenceSeeds:seeds,env:{}});
 const selection=staged.selection,project=selection.sourceProject;
 const nativeRelative='.cache/native-kernel/nwn-particle-kernel.dll';
 const target=path.join(project,nativeRelative);assert.equal(sha(target),acceptedHash);
 fs.copyFileSync(receipt.binary,target);assert.equal(sha(target),receipt.binarySha256);
 const nativePin=selection.pins.find(row=>row.relative===nativeRelative);assert(nativePin);nativePin.sha256=receipt.binarySha256;
 const buildManifestFile=path.join(project,'.cache/native-kernel/build-manifest.json'),buildManifest=read(buildManifestFile);
 assert.equal(buildManifest.binarySha256,acceptedHash);
 buildManifest.binarySha256=receipt.binarySha256;buildManifest.privateBuildProof={file:receiptFile,sha256:sha(receiptFile)};
 buildManifest.scope='Private C2 particle G2 subphase diagnostic; accepted DLL untouched';
 fs.writeFileSync(buildManifestFile,JSON.stringify(buildManifest,null,2)+'\n');
 const manifestPin=selection.pins.find(row=>row.relative==='.cache/native-kernel/build-manifest.json');assert(manifestPin);manifestPin.sha256=sha(buildManifestFile);
 const group='systems/native_render/particle_stream_group.gd',world='native_live_world.gd',helper='tools/nwn64/phase_review_census.gd';
 replaceOnce(path.join(project,group),'native.call("dispatch",15,{"enabled":sparse_enabled,"stride":120,"min_members":1800,"coarse_phases":coarse_enabled,"setup_boundary":setup_enabled,"reset":true})','native.call("dispatch",15,{"enabled":true,"stride":120,"min_members":0,"coarse_phases":true,"preparation_subphases":true,"setup_boundary":setup_enabled,"reset":true})');
 replaceOnce(path.join(project,world),'\tif is_instance_valid(world): report.world=world.snapshot()','\tif is_instance_valid(world):\n\t\treport.world=world.snapshot()\n\t\treport.private_particle_phase_review=preload("res://tools/nwn64/phase_review_census.gd").collect(world)');
 const helperFile=path.join(project,helper);assert.equal(sha(helperFile),sha(path.join(root,helper)),'Diagnostic helper differs in clone');
 for(const relative of [group,world]){const pin=selection.pins.find(row=>row.relative===relative);assert(pin);pin.sha256=sha(path.join(project,relative));}
 const helperPin=selection.pins.find(row=>row.relative===helper);if(helperPin)helperPin.sha256=sha(helperFile);else selection.pins.push({relative:helper,sha256:sha(helperFile)});
 selection.mainSourceIdentity=require(path.join(root,'tools/native-feature-manifest.cjs')).sourceIdentity(project);
 selection.nativeBuilds=1;selection.scope='Private profile-OFF C2 particle subphase diagnostic, original G2 recording; no FPS/default/accepted-DLL claim';
 fs.writeFileSync(staged.file,JSON.stringify(selection,null,2)+'\n');
 const selectionHash=sha(staged.file);await selector.readProductionSelection(staged.file,selectionHash);
 const capture=read(path.join(root,'.cache/nwn64/animation-snapshot-client-pair-a/staged.json'));
 assert.equal(sha(path.join(capture.capture,'recording.json')),capture.recordingSha256);
 fs.mkdirSync(scope,{recursive:true});const result={version:1,issue:'NWN-64',private:true,accepted:false,selection:{file:staged.file,sha256:selectionHash,sourceIdentity:selection.mainSourceIdentity.sha256,engineSha256:selection.runtime.executableSha256,nativeSha256:receipt.binarySha256,pins:selection.pins.length},capture:capture.capture,recordingSha256:capture.recordingSha256,diagnosticBuild:{file:receiptFile,sha256:sha(receiptFile)},changed:[group,world,nativeRelative,'.cache/native-kernel/build-manifest.json'],added:[helper],scope:'Stage only; no launch, FPS or accepted artifact change. C2 diagnostic kernel previously passed focused/heavy exact state and packet parity.'};
 const file=path.join(scope,'staged.json');write(file,result);console.log(JSON.stringify({file,sha256:sha(file),selection:result.selection}));
}
main().catch(error=>{console.error(error.stack);process.exitCode=1;});
