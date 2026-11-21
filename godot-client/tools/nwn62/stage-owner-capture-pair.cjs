'use strict';
// Freeze one current source, then overlay only the two pre-owner-capture files
// in a private control. Run while all production source writers are stopped.
const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const scope=path.join(root,'.cache/nwn62/owner-capture-pair-a');
const referenceFile=path.join(root,'.cache/native-presentation-parity/production-replay/nwn62-completion-tail-c/production-selection.json');
const before=path.join(root,'.cache/nwn62/owner-capture-control');
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
async function main(){
 assert(!fs.existsSync(path.join(scope,'staged.json')),'Preserve previous owner-capture stage');
 assert.equal(sha(path.join(before,'model_template.gd')),'d24f1ba6b68b3b4190c36d2e2731fa5bb78e12f8540f7ab8f3b34c5a13169ee4');
 assert.equal(sha(path.join(before,'native_model_recipe.gd')),'9a4d5f0bbf9bcb7868ad7a1b4bfb68c2179f32a0c29a77be3ce620ead62dfff2');
 const reference=JSON.parse(fs.readFileSync(referenceFile));
 const seeds={version:1,expected:reference.preferences.expected,description:'NWN-62 current owner-capture pair, same reviewed original-scene preferences'};
 for(const name of ['render','layout'])seeds[name]={file:reference.preferences[name].source,sha256:reference.preferences[name].sha256};
 const argv=[...reference.options];
 const helper=require(path.join(root,'tools/native-production-selection.cjs'));
 const candidate=await helper.stageProductionSelection({project:root,label:'nwn62-owner-capture-candidate-a',argv,preferenceSeeds:seeds,env:{}});
 const controlInput=path.join(scope,'control-input');
 assert(!fs.existsSync(controlInput));fs.mkdirSync(scope,{recursive:true});
 fs.cpSync(candidate.selection.sourceProject,controlInput,{recursive:true,errorOnExist:true,force:false});
 const replacements=[['systems/native_render/model_template.gd','model_template.gd'],['systems/native_render/native_model_recipe.gd','native_model_recipe.gd']];
 for(const [relative,name] of replacements)fs.copyFileSync(path.join(before,name),path.join(controlInput,relative));
 for(const relative of ['.tools/native-core/Godot_native_core_e_win64.exe','.tools/native-core/accepted-core-e.json']){
  const target=path.join(controlInput,relative);fs.mkdirSync(path.dirname(target),{recursive:true});fs.linkSync(path.join(root,relative),target);
 }
 const controlHelper=require(path.join(controlInput,'tools/native-production-selection.cjs'));
 const control=await controlHelper.stageProductionSelection({project:controlInput,label:'nwn62-owner-capture-control-a',argv,preferenceSeeds:seeds,env:{}});
 await helper.readProductionSelection(candidate.file,candidate.sha256);
 await controlHelper.readProductionSelection(control.file,control.sha256);
 assert.equal(candidate.selection.runtime.executableSha256,control.selection.runtime.executableSha256);
 assert.equal(candidate.selection.preferences.render.sha256,control.selection.preferences.render.sha256);
 assert.equal(candidate.selection.preferences.layout.sha256,control.selection.preferences.layout.sha256);
 assert.deepEqual(candidate.selection.flags,control.selection.flags);
 const a=new Map(candidate.selection.mainSourceIdentity.files.map(x=>[x.file,x.sha256]));
 const b=new Map(control.selection.mainSourceIdentity.files.map(x=>[x.file,x.sha256]));
 assert.deepEqual([...a.keys()].sort(),[...b.keys()].sort());
 const changed=[...a.keys()].filter(key=>a.get(key)!==b.get(key)).sort();
 assert.deepEqual(changed,replacements.map(x=>x[0]).sort(),'Control differs beyond owner-capture files');
 const prior=JSON.parse(fs.readFileSync(path.join(root,'.cache/nwn74/base-merge-pair-a/staged.json')));
 assert.equal(sha(path.join(prior.capture,'recording.json')),prior.recordingSha256);
 const staged={version:1,issue:'NWN-62',private:true,accepted:false,capture:prior.capture,recordingSha256:prior.recordingSha256,engineSha256:candidate.selection.runtime.executableSha256,changed,controlInput,selections:{control:{file:control.file,sha256:control.sha256,sourceIdentity:control.selection.mainSourceIdentity.sha256},candidate:{file:candidate.file,sha256:candidate.sha256,sourceIdentity:candidate.selection.mainSourceIdentity.sha256}},scope:'Current source versus exact pre-owner-capture model template/recipe only; first-pose bounds change in both. Original generation-2 normal-client offline replay, no Arelith acceptance.'};
 const file=path.join(scope,'staged.json');fs.writeFileSync(file,JSON.stringify(staged,null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({file,sha256:sha(file),changed,control:staged.selections.control.sourceIdentity,candidate:staged.selections.candidate.sourceIdentity}));
}
main().catch(error=>{console.error(error.stack);process.exitCode=1;});
