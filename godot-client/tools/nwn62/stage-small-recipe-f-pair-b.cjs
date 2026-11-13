'use strict';
// Reuse the accepted-source E control selection as the immutable B baseline.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),scope=path.join(root,'.cache/nwn62/small-recipe-f-pair-b');
const privateRoot=path.join(root,'.cache/nwn62/small-recipe-f');
const e=JSON.parse(fs.readFileSync(path.join(root,'.cache/nwn62/small-recipe-e-pair-a/staged.json')));
const source=JSON.parse(fs.readFileSync(path.join(privateRoot,'source-receipt.json')));
const helper=require(path.join(root,'tools/native-production-selection.cjs'));
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const once=(value,old,next)=>{assert.equal(value.split(old).length,2,old);return value.replace(old,next)};

async function main(){
 assert(!fs.existsSync(scope),'immutable pair B already exists');
 assert.equal(sha(path.join(e.capture,'recording.json')),e.recordingSha256);
 const baseline=await helper.readProductionSelection(e.selections.control.file,e.selections.control.sha256);
 assert.equal(baseline.mainSourceIdentity.sha256,'304b31564c52102b9e1091aa4268352a88e0dce628bec992eec4056faf394fc0');
 assert.equal(baseline.runtime.executableSha256,'753b3e188068efaf865bda3abd6322ebe44e3a98ef2f5d199c8af1a78624c98b');
 for(const p of [source.template,source.recipe]){
  assert.equal(sha(path.join(baseline.sourceProject,p.relative)),p.beforeSha256);
  assert.equal(sha(path.join(privateRoot,p.relative)),p.afterSha256);
 }
 fs.mkdirSync(scope,{recursive:true});
 const input=path.join(scope,'candidate-input');
 fs.cpSync(baseline.sourceProject,input,{recursive:true,errorOnExist:true,force:false});
 const templateRelative=source.template.relative,recipeRelative=source.recipe.relative;
 fs.copyFileSync(path.join(privateRoot,recipeRelative),path.join(input,recipeRelative));
 let template=fs.readFileSync(path.join(privateRoot,templateRelative),'utf8');
 template=once(template,'res://.cache/nwn62/small-recipe-f/systems/native_render/native_model_recipe.gd','res://systems/native_render/native_model_recipe.gd');
 template=once(template,'if not OS.get_cmdline_user_args().has("--model-template=recipe-small-tail-f"):return false','if false:return false');
 fs.writeFileSync(path.join(input,templateRelative),template);
 for(const name of ['.tools/native-core/Godot_native_core_e_win64.exe','.tools/native-core/accepted-core-e.json']){
  const target=path.join(input,name);if(fs.existsSync(target))continue;
  fs.mkdirSync(path.dirname(target),{recursive:true});fs.linkSync(path.join(root,name),target);
 }
 const seeds={version:1,expected:baseline.preferences.expected,description:'NWN-62 F paired with immutable accepted-source E control'};
 for(const name of ['render','layout'])seeds[name]={file:baseline.preferences[name].source,sha256:baseline.preferences[name].sha256};
 const candidateHelper=require(path.join(input,'tools/native-production-selection.cjs'));
 const candidate=await candidateHelper.stageProductionSelection({project:input,label:'nwn62-small-recipe-f-candidate-b',argv:baseline.options,preferenceSeeds:seeds,env:{}});
 await candidateHelper.readProductionSelection(candidate.file,candidate.sha256);
 assert.equal(candidate.selection.runtime.executableSha256,baseline.runtime.executableSha256);
 assert.deepEqual(candidate.selection.options,baseline.options);
 assert.deepEqual(candidate.selection.flags,baseline.flags);
 assert.equal(candidate.selection.preferences.render.sha256,baseline.preferences.render.sha256);
 assert.equal(candidate.selection.preferences.layout.sha256,baseline.preferences.layout.sha256);
 const baselineFiles=new Map(baseline.mainSourceIdentity.files.map(row=>[row.file,row.sha256]));
 const changed=candidate.selection.mainSourceIdentity.files.filter(row=>baselineFiles.get(row.file)!==row.sha256).map(row=>row.file).sort();
 assert.deepEqual(changed,[templateRelative,recipeRelative].sort());
 const stage={issue:'NWN-62',private:true,accepted:false,scope:'Immutable accepted-source E control (no NWN-61 menu split) against F overlay; identical Core E, original recording, settings, camera, options and flags. Candidate forces F selector on, with exactly two changed source files.',capture:e.capture,recordingSha256:e.recordingSha256,engineSha256:baseline.runtime.executableSha256,privateSourceReceipt:path.join(privateRoot,'source-receipt.json'),changed,selections:{control:{file:e.selections.control.file,sha256:e.selections.control.sha256,sourceSignature:baseline.mainSourceIdentity.sha256},candidate:{file:candidate.file,sha256:candidate.sha256,sourceSignature:candidate.selection.mainSourceIdentity.sha256}}};
 const file=path.join(scope,'staged.json');fs.writeFileSync(file,JSON.stringify(stage,null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({file,sha256:sha(file),changed,control:stage.selections.control.sourceSignature,candidate:stage.selections.candidate.sourceSignature,engineSha256:stage.engineSha256}));
}
main().catch(error=>{console.error(error.stack);process.exitCode=1});
