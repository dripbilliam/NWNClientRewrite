'use strict';
// Prepare two private production selections from one source identity. No client launch.
const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const label=process.argv.find(value=>value.startsWith('--label='))?.slice(8)??'b';
assert(/^[a-z]$/.test(label),'Use one lowercase letter for an immutable stage label');
const scope=path.join(root,'.cache/nwn62/drive-reindex-pair-'+label);
const referenceFile=path.join(root,'.cache/native-presentation-parity/production-replay/nwn61-current-entry-staged-a/production-selection.json');
const captureStage=path.join(root,'.cache/nwn74/base-merge-pair-a/staged.json');
const replacements=[
 ['systems/native_render/drive_collision_indexed.gd','tools/nwn62/drive_collision_indexed_staged_lazy_pair_overlay.gd','516ea7d7ac8ab7de0fa1b34fd265fa61016ac8e7699bf59784563d05a6c6f73f'],
 ['systems/native_render/drive_spatial_index.gd','tools/nwn62/drive_spatial_index_staged_candidate.gd','7d18acd8cd290249ebe65fce37c2089771f992d4e0e1e07cf7c6927d9751b0cf'],
];
const productionPins={
 'systems/native_render/drive_collision_indexed.gd':'f3c2b35e783dd7d0dec24a1978a6f47edc2e3024ef2f37d8b158b6a8cfaca928',
 'systems/native_render/drive_spatial_index.gd':'33864b13f75604548e7bbe1e1263536a6d4ff2db24b3e59b8b7882cc6673e209',
};
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
function inputs(){
 for(const [relative,expected] of Object.entries(productionPins))assert.equal(sha(path.join(root,relative)),expected,`Production changed: ${relative}`);
 for(const [,candidate,expected] of replacements)assert.equal(sha(path.join(root,candidate)),expected,`Private candidate changed: ${candidate}`);
 const reference=JSON.parse(fs.readFileSync(referenceFile));
 const prior=JSON.parse(fs.readFileSync(captureStage));
 assert.equal(sha(path.join(prior.capture,'recording.json')),prior.recordingSha256);
 assert(reference.preferences?.render?.source&&reference.preferences?.layout?.source);
 const seeds={version:1,expected:reference.preferences.expected,description:'NWN-62 current drive reindex pair, same reviewed original-scene preferences'};
 for(const name of ['render','layout'])seeds[name]={file:reference.preferences[name].source,sha256:reference.preferences[name].sha256};
 return {reference,prior,seeds,argv:[...reference.options]};
}
async function main(){
 const {prior,seeds,argv}=inputs();
 if(process.argv.includes('--verify-only')){
  console.log(JSON.stringify({success:true,mode:'verify-only',clientStarts:0,sourceCopies:0,scope,capture:prior.capture,recordingSha256:prior.recordingSha256,productionPins,replacements:replacements.map(([relative,candidate,sha256])=>({relative,candidate,sha256})),options:argv},null,2));return;
 }
 assert(!fs.existsSync(path.join(scope,'staged.json')),'Preserve previous reindex pair stage');
 const helper=require(path.join(root,'tools/native-production-selection.cjs'));
 const control=await helper.stageProductionSelection({project:root,label:'nwn62-drive-reindex-control-'+label,argv,preferenceSeeds:seeds,env:{}});
 const candidateInput=path.join(scope,'candidate-input');
 assert(!fs.existsSync(candidateInput));fs.mkdirSync(scope,{recursive:true});
 fs.cpSync(control.selection.sourceProject,candidateInput,{recursive:true,errorOnExist:true,force:false});
 for(const [relative,candidate] of replacements)fs.copyFileSync(path.join(root,candidate),path.join(candidateInput,relative));
 for(const relative of ['.tools/native-core/Godot_native_core_e_win64.exe','.tools/native-core/accepted-core-e.json']){
  const target=path.join(candidateInput,relative);fs.mkdirSync(path.dirname(target),{recursive:true});fs.linkSync(path.join(root,relative),target);
 }
 const candidateHelper=require(path.join(candidateInput,'tools/native-production-selection.cjs'));
 const candidate=await candidateHelper.stageProductionSelection({project:candidateInput,label:'nwn62-drive-reindex-candidate-'+label,argv,preferenceSeeds:seeds,env:{}});
 await helper.readProductionSelection(control.file,control.sha256);
 await candidateHelper.readProductionSelection(candidate.file,candidate.sha256);
 assert.equal(control.selection.runtime.executableSha256,candidate.selection.runtime.executableSha256);
 assert.equal(control.selection.preferences.render.sha256,candidate.selection.preferences.render.sha256);
 assert.equal(control.selection.preferences.layout.sha256,candidate.selection.preferences.layout.sha256);
 assert.deepEqual(control.selection.flags,candidate.selection.flags);
 const a=new Map(control.selection.mainSourceIdentity.files.map(x=>[x.file,x.sha256]));
 const b=new Map(candidate.selection.mainSourceIdentity.files.map(x=>[x.file,x.sha256]));
 assert.deepEqual([...a.keys()].sort(),[...b.keys()].sort());
 const changed=[...a.keys()].filter(key=>a.get(key)!==b.get(key)).sort();
 assert.deepEqual(changed,replacements.map(x=>x[0]).sort(),'Unexpected source difference');
 const staged={version:1,issue:'NWN-62',private:true,accepted:false,capture:prior.capture,recordingSha256:prior.recordingSha256,engineSha256:control.selection.runtime.executableSha256,changed,candidateInput,selections:{control:{file:control.file,sha256:control.sha256,sourceIdentity:control.selection.mainSourceIdentity.sha256},candidate:{file:candidate.file,sha256:candidate.sha256,sourceIdentity:candidate.selection.mainSourceIdentity.sha256}},scope:'Same captured original-scene recording, settings, engine and current source; only two private drive reindex source files differ. No live Arelith acceptance.'};
 const file=path.join(scope,'staged.json');fs.writeFileSync(file,JSON.stringify(staged,null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({file,sha256:sha(file),changed,control:staged.selections.control.sourceIdentity,candidate:staged.selections.candidate.sourceIdentity,clientStarts:0}));
}
main().catch(error=>{console.error(error.stack);process.exitCode=1;});
