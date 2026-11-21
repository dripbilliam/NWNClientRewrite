'use strict';
// Private current-source world census selection. No client is launched here.
const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const assert=require('node:assert/strict');

const root=path.resolve(__dirname,'../..');
const scope=path.join(root,'.cache/nwn78/census-a');
const reference=JSON.parse(fs.readFileSync(path.join(root,'.cache/native-presentation-parity/production-replay/nwn61-current-entry-staged-a/production-selection.json')));
const capture=JSON.parse(fs.readFileSync(path.join(root,'.cache/nwn62/worker-texture-pair-c/staged.json')));
const hash=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const helper=require(path.join(root,'tools/native-production-selection.cjs'));

async function main(){
  assert(!fs.existsSync(scope),'Preserve earlier census selection');
  assert.equal(hash(path.join(capture.capture,'recording.json')),capture.recordingSha256);
  const seeds={version:1,expected:reference.preferences.expected,description:'NWN-78 private census with pinned original-scene settings'};
  for(const name of ['render','layout'])seeds[name]={file:reference.preferences[name].source,sha256:reference.preferences[name].sha256};
  const argv=reference.options.map(value=>value==='--detailed-profiling=off'?'--detailed-profiling=on':value);
  assert(argv.includes('--detailed-profiling=on'));
  const seed=await helper.stageProductionSelection({project:root,label:'nwn78-census-seed-a',argv,preferenceSeeds:seeds,env:{}});
  fs.mkdirSync(scope,{recursive:true});
  const input=path.join(scope,'candidate-input');
  fs.cpSync(seed.selection.sourceProject,input,{recursive:true,errorOnExist:true,force:false});
  const script=path.join(input,'native_session_world.gd');
  const before=fs.readFileSync(script,'utf8');
  const old='extends "res://native_live_world.gd"';
  assert.equal(before.split(old).length,2);
  fs.writeFileSync(script,before.replace(old,'extends "res://tools/nwn78/census_live_world.gd"'));
  for(const name of ['.tools/native-core/Godot_native_core_e_win64.exe','.tools/native-core/accepted-core-e.json']){
    const target=path.join(input,name);fs.mkdirSync(path.dirname(target),{recursive:true});fs.linkSync(path.join(root,name),target);
  }
  const candidateHelper=require(path.join(input,'tools/native-production-selection.cjs'));
  const candidate=await candidateHelper.stageProductionSelection({project:input,label:'nwn78-census-a',argv,preferenceSeeds:seeds,env:{}});
  await candidateHelper.readProductionSelection(candidate.file,candidate.sha256);
  assert.equal(seed.selection.runtime.executableSha256,candidate.selection.runtime.executableSha256);
  assert.deepEqual(seed.selection.options,candidate.selection.options);
  const baseline=new Map(seed.selection.mainSourceIdentity.files.map(row=>[row.file,row.sha256]));
  const changed=candidate.selection.mainSourceIdentity.files.filter(row=>baseline.get(row.file)!==row.sha256).map(row=>row.file);
  assert.deepEqual(changed,['native_session_world.gd']);
  const receipt={ticket:'NWN-78',private:true,accepted:false,scope:'Diagnostic census only; never use for FPS comparison',capture:capture.capture,recordingSha256:capture.recordingSha256,engineSha256:candidate.selection.runtime.executableSha256,changed,selection:{file:candidate.file,sha256:candidate.sha256,sourceSignature:candidate.selection.mainSourceIdentity.sha256},sourcePins:{census:hash(path.join(root,'tools/nwn78/census_live_world.gd')),counter:hash(path.join(root,'tools/nwn78/persistent_state_census.gd'))}};
  fs.writeFileSync(path.join(scope,'staged.json'),JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});
  process.stdout.write(JSON.stringify({file:path.join(scope,'staged.json'),selection:candidate.file,engineSha256:receipt.engineSha256,changed})+'\n');
}
main().catch(error=>{console.error(error.stack);process.exitCode=1;});
