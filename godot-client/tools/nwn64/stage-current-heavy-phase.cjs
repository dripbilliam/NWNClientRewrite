'use strict';
// Private source-only sampler on the current normal client and heavy original scene.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),scope=path.join(root,'.cache/nwn64/current-heavy-phase-a');
const referenceFile=path.join(root,'.cache/native-presentation-parity/production-replay/nwn62-completion-tail-c/production-selection.json');
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const write=(file,value)=>fs.writeFileSync(file,JSON.stringify(value,null,2)+'\n',{flag:'wx'});
function replaceOnce(file,before,after){const source=fs.readFileSync(file,'utf8');if(source.includes(after)){assert(!source.includes(before));return;}assert.equal(source.split(before).length,2,'Diagnostic seam changed: '+file);fs.writeFileSync(file,source.replace(before,after));}
async function main(){
 assert(!fs.existsSync(scope),'Preserve previous phase capsule');
 const reference=JSON.parse(fs.readFileSync(referenceFile));assert(reference.complete&&reference.production);
 const seeds={version:1,expected:reference.preferences.expected,description:'Private current heavy particle phase census'};
 for(const name of ['render','layout'])seeds[name]={file:reference.preferences[name].source,sha256:reference.preferences[name].sha256};
 const selector=require(path.join(root,'tools/native-production-selection.cjs'));
 const priorFile=path.join(root,'.cache/native-presentation-parity/production-replay/nwn64-current-heavy-phase-a/production-selection.json');
 const staged=fs.existsSync(priorFile)?{file:priorFile,selection:JSON.parse(fs.readFileSync(priorFile))}:await selector.stageProductionSelection({project:root,label:'nwn64-current-heavy-phase-a',argv:reference.options,preferenceSeeds:seeds,env:{}});
 const selection=staged.selection,project=selection.sourceProject;
 const group='systems/native_render/particle_stream_group.gd',world='native_live_world.gd',helper='tools/nwn64/phase_review_census.gd';
 replaceOnce(path.join(project,group),'native.call("dispatch",15,{"enabled":sparse_enabled,"stride":120,"min_members":1800,"coarse_phases":coarse_enabled,"setup_boundary":setup_enabled,"reset":true})','native.call("dispatch",15,{"enabled":true,"stride":120,"min_members":0,"coarse_phases":true,"setup_boundary":setup_enabled,"reset":true})');
 replaceOnce(path.join(project,world),'\tif is_instance_valid(world): report.world=world.snapshot()','\tif is_instance_valid(world):\n\t\treport.world=world.snapshot()\n\t\treport.private_particle_phase_review=preload("res://tools/nwn64/phase_review_census.gd").collect(world)');
 const helperFile=path.join(project,helper);fs.mkdirSync(path.dirname(helperFile),{recursive:true});if(!fs.existsSync(helperFile))fs.copyFileSync(path.join(root,helper),helperFile,fs.constants.COPYFILE_EXCL);assert.equal(sha(helperFile),sha(path.join(root,helper)));
 for(const relative of [group,world]){const pin=selection.pins.find(row=>row.relative===relative);assert(pin);pin.sha256=sha(path.join(project,relative));}
 const helperPin=selection.pins.find(row=>row.relative===helper);if(helperPin)helperPin.sha256=sha(helperFile);else selection.pins.push({relative:helper,sha256:sha(helperFile)});
 selection.mainSourceIdentity=require(path.join(root,'tools/native-feature-manifest.cjs')).sourceIdentity(project);
 selection.scope='Private accepted-DLL coarse particle phase diagnostic; original heavy recording, no FPS acceptance or default change.';
 fs.writeFileSync(staged.file,JSON.stringify(selection,null,2)+'\n');
 const selectionSha=sha(staged.file);await selector.readProductionSelection(staged.file,selectionSha);
 const capture=JSON.parse(fs.readFileSync(path.join(root,'.cache/nwn64/animation-snapshot-client-pair-a/staged.json')));
 assert.equal(sha(path.join(capture.capture,'recording.json')),capture.recordingSha256);
 fs.mkdirSync(scope,{recursive:true});const receipt={version:1,issue:'NWN-64',private:true,acceptedRuntimeUnchanged:true,selection:{file:staged.file,sha256:selectionSha,sourceIdentity:selection.mainSourceIdentity.sha256,engineSha256:selection.runtime.executableSha256,nativeSha256:selection.renderCore.nativeKernelSha256,pins:selection.pins.length},capture:capture.capture,recordingSha256:capture.recordingSha256,changed:[group,world],added:[helper],scope:'Current normal-client heavy-scene coarse owner phase sample. Timing attribution diagnostic only; no FPS or Arelith claim.'};
 const file=path.join(scope,'staged.json');write(file,receipt);console.log(JSON.stringify({file,sha256:sha(file),selection:receipt.selection,capture:receipt.capture}));
}
main().catch(error=>{console.error(error.stack);process.exitCode=1;});
