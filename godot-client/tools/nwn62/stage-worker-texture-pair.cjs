'use strict';
// Stage default-off and private worker-texture-on selections from one source.
// This copies code only; no game assets, client launch or FPS measurement.
const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const label=process.argv.find(value=>value.startsWith('--label='))?.slice(8)??'a';
assert(/^[a-z]$/.test(label),'Use one lowercase immutable stage label');
const profiling=process.argv.includes('--profile-on');
const scope=path.join(root,'.cache/nwn62/worker-texture-pair-'+label);
const referenceFile=path.join(root,'.cache/native-presentation-parity/production-replay/nwn61-current-entry-staged-a/production-selection.json');
const captureFile=path.join(root,'.cache/nwn74/base-merge-pair-a/staged.json');
const changedFile='project.godot';
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
async function main(){
 const reference=JSON.parse(fs.readFileSync(referenceFile));
 const captured=JSON.parse(fs.readFileSync(captureFile));
 assert.equal(sha(path.join(captured.capture,'recording.json')),captured.recordingSha256);
 assert(!fs.readFileSync(path.join(root,changedFile),'utf8').includes('worker_texture_creation'));
 const seeds={version:1,expected:reference.preferences.expected,description:'NWN-62 private worker texture off/on, identical original-scene preferences'};
 for(const name of ['render','layout'])seeds[name]={file:reference.preferences[name].source,sha256:reference.preferences[name].sha256};
 const argv=reference.options.map(value=>profiling&&value==='--detailed-profiling=off'?'--detailed-profiling=on':value);
 assert(argv.some(value=>value==='--detailed-profiling='+(profiling?'on':'off')));
 if(process.argv.includes('--verify-only')){console.log(JSON.stringify({issue:'NWN-62',private:true,clientStarts:0,recordingSha256:captured.recordingSha256,options:argv,changed:[changedFile]},null,2));return;}
 assert(!fs.existsSync(scope),'Preserve previous worker texture stage');
 const helper=require(path.join(root,'tools/native-production-selection.cjs'));
 const control=await helper.stageProductionSelection({project:root,label:'nwn62-worker-texture-control-'+label,argv,preferenceSeeds:seeds,env:{}});
 fs.mkdirSync(scope,{recursive:true});
 const candidateInput=path.join(scope,'candidate-input');
 fs.cpSync(control.selection.sourceProject,candidateInput,{recursive:true,errorOnExist:true,force:false});
 fs.appendFileSync(path.join(candidateInput,changedFile),'\n[nwn]\nprivate/worker_texture_creation=true\n');
 for(const engineFile of ['.tools/native-core/Godot_native_core_e_win64.exe','.tools/native-core/accepted-core-e.json']){
  const target=path.join(candidateInput,engineFile);fs.mkdirSync(path.dirname(target),{recursive:true});fs.linkSync(path.join(root,engineFile),target);
 }
 const candidateHelper=require(path.join(candidateInput,'tools/native-production-selection.cjs'));
 const candidate=await candidateHelper.stageProductionSelection({project:candidateInput,label:'nwn62-worker-texture-candidate-'+label,argv,preferenceSeeds:seeds,env:{}});
 await helper.readProductionSelection(control.file,control.sha256);
 await candidateHelper.readProductionSelection(candidate.file,candidate.sha256);
 assert.equal(control.selection.runtime.executableSha256,candidate.selection.runtime.executableSha256);
 assert.deepEqual(control.selection.flags,candidate.selection.flags);
 assert.deepEqual(control.selection.options,candidate.selection.options);
 assert.equal(control.selection.preferences.render.sha256,candidate.selection.preferences.render.sha256);
 assert.equal(control.selection.preferences.layout.sha256,candidate.selection.preferences.layout.sha256);
 const a=new Map(control.selection.mainSourceIdentity.files.map(row=>[row.file,row.sha256]));
 const b=new Map(candidate.selection.mainSourceIdentity.files.map(row=>[row.file,row.sha256]));
 assert.deepEqual([...a.keys()].sort(),[...b.keys()].sort());
 const changed=[...a.keys()].filter(file=>a.get(file)!==b.get(file)).sort();
 assert.deepEqual(changed,[changedFile]);
 const staged={version:1,issue:'NWN-62',private:true,accepted:false,capture:captured.capture,recordingSha256:captured.recordingSha256,engineSha256:control.selection.runtime.executableSha256,changed,sourcePins:{assetService:sha(path.join(root,'systems/native_data/asset_service.gd')),rasterUpload:sha(path.join(root,'systems/native_data/raster_upload_preparation.gd')),resourcePool:sha(path.join(root,'systems/native_render/resource_pool.gd'))},selections:{control:{file:control.file,sha256:control.sha256,sourceIdentity:control.selection.mainSourceIdentity.sha256},candidate:{file:candidate.file,sha256:candidate.sha256,sourceIdentity:candidate.selection.mainSourceIdentity.sha256}},scope:'Same code, engine, recording and preferences; only private project setting nwn/private/worker_texture_creation differs. No acceptance or FPS claim.'};
 const file=path.join(scope,'staged.json');fs.writeFileSync(file,JSON.stringify(staged,null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({file,sha256:sha(file),changed,control:staged.selections.control.sourceIdentity,candidate:staged.selections.candidate.sourceIdentity,clientStarts:0}));
}
main().catch(error=>{console.error(error.stack);process.exitCode=1;});
