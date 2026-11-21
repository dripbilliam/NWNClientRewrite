'use strict';
// Stage an immutable current-source F/control pair. This script never launches a client.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),scope=path.join(root,'.cache/nwn62/small-recipe-f-pair-a');
const privateRoot=path.join(root,'.cache/nwn62/small-recipe-f');
const source=JSON.parse(fs.readFileSync(path.join(privateRoot,'source-receipt.json')));
const reference=JSON.parse(fs.readFileSync(path.join(root,'.cache/native-presentation-parity/production-replay/nwn61-current-entry-staged-a/production-selection.json')));
const captured=JSON.parse(fs.readFileSync(path.join(root,'.cache/nwn62/worker-texture-pair-c/staged.json')));
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const once=(value,old,next)=>{assert.equal(value.split(old).length,2,old);return value.replace(old,next)};
const helper=require(path.join(root,'tools/native-production-selection.cjs'));

async function main(){
 assert(!fs.existsSync(scope),'immutable pair already exists');
 assert.equal(sha(path.join(captured.capture,'recording.json')),captured.recordingSha256);
 for(const p of [source.template,source.recipe]){
  assert.equal(sha(path.join(root,p.relative)),p.beforeSha256);
  assert.equal(sha(path.join(privateRoot,p.relative)),p.afterSha256);
 }
 const seeds={version:1,expected:reference.preferences.expected,description:'NWN-62 F original-scene ABBA source-pinned pair'};
 for(const name of ['render','layout'])seeds[name]={file:reference.preferences[name].source,sha256:reference.preferences[name].sha256};
 const argv=reference.options.map(value=>value==='--detailed-profiling=off'?'--detailed-profiling=on':value);
 assert(argv.includes('--detailed-profiling=on'));
 const control=await helper.stageProductionSelection({project:root,label:'nwn62-small-recipe-f-control-a',argv,preferenceSeeds:seeds,env:{}});
 fs.mkdirSync(scope,{recursive:true});
 const input=path.join(scope,'candidate-input');
 fs.cpSync(control.selection.sourceProject,input,{recursive:true,errorOnExist:true,force:false});
 const recipeRelative=source.recipe.relative,templateRelative=source.template.relative;
 fs.copyFileSync(path.join(privateRoot,recipeRelative),path.join(input,recipeRelative));
 let template=fs.readFileSync(path.join(privateRoot,templateRelative),'utf8');
 template=once(template,'res://.cache/nwn62/small-recipe-f/systems/native_render/native_model_recipe.gd','res://systems/native_render/native_model_recipe.gd');
 // Identical argv in both legs: the source overlay alone activates its scoped selector.
 template=once(template,'if not OS.get_cmdline_user_args().has("--model-template=recipe-small-tail-f"):return false','if false:return false');
 fs.writeFileSync(path.join(input,templateRelative),template);
 for(const name of ['.tools/native-core/Godot_native_core_e_win64.exe','.tools/native-core/accepted-core-e.json']){
  const target=path.join(input,name);fs.mkdirSync(path.dirname(target),{recursive:true});fs.linkSync(path.join(root,name),target);
 }
 const candidateHelper=require(path.join(input,'tools/native-production-selection.cjs'));
 const candidate=await candidateHelper.stageProductionSelection({project:input,label:'nwn62-small-recipe-f-candidate-a',argv,preferenceSeeds:seeds,env:{}});
 await helper.readProductionSelection(control.file,control.sha256);
 await candidateHelper.readProductionSelection(candidate.file,candidate.sha256);
 assert.equal(control.selection.runtime.executableSha256,candidate.selection.runtime.executableSha256);
 assert.equal(control.selection.runtime.executableSha256,'753b3e188068efaf865bda3abd6322ebe44e3a98ef2f5d199c8af1a78624c98b');
 assert.deepEqual(control.selection.options,candidate.selection.options);
 assert.deepEqual(control.selection.flags,candidate.selection.flags);
 const baseline=new Map(control.selection.mainSourceIdentity.files.map(row=>[row.file,row.sha256]));
 const changed=candidate.selection.mainSourceIdentity.files.filter(row=>baseline.get(row.file)!==row.sha256).map(row=>row.file).sort();
 assert.deepEqual(changed,[templateRelative,recipeRelative].sort());
 const stage={issue:'NWN-62',private:true,accepted:false,scope:'Current source and accepted Core E engine; same recording, preferences, camera, options and flags. Candidate differs only in ModelTemplate and NativeModelRecipe and forces the five original-byte F selector on.',capture:captured.capture,recordingSha256:captured.recordingSha256,engineSha256:control.selection.runtime.executableSha256,privateSourceReceipt:path.join(privateRoot,'source-receipt.json'),changed,selections:{control:{file:control.file,sha256:control.sha256,sourceSignature:control.selection.mainSourceIdentity.sha256},candidate:{file:candidate.file,sha256:candidate.sha256,sourceSignature:candidate.selection.mainSourceIdentity.sha256}}};
 const file=path.join(scope,'staged.json');fs.writeFileSync(file,JSON.stringify(stage,null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({file,sha256:sha(file),changed,control:stage.selections.control.sourceSignature,candidate:stage.selections.candidate.sourceSignature,engineSha256:stage.engineSha256}));
}
main().catch(error=>{console.error(error.stack);process.exitCode=1});
