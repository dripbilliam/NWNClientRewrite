'use strict';
// Exclusive graphical/FPS lease only. --verify-only never launches a client.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict'),{spawn}=require('node:child_process');
const root=path.resolve(__dirname,'../..');
const pair=process.argv.includes('--pair=a')?'a':'b';
const scope=path.join(root,'.cache/nwn62/small-recipe-f-pair-'+pair);
const stageFile=path.join(scope,'staged.json'),stage=JSON.parse(fs.readFileSync(stageFile));
const order=['candidate-1','control-1','control-2','candidate-2'];
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');

async function verify(){
 assert(stage.private&&!stage.accepted&&stage.issue==='NWN-62');
 assert.deepEqual(stage.changed,['systems/native_render/model_template.gd','systems/native_render/native_model_recipe.gd']);
 assert.equal(sha(path.join(stage.capture,'recording.json')),stage.recordingSha256);
 assert.equal(stage.engineSha256,'753b3e188068efaf865bda3abd6322ebe44e3a98ef2f5d199c8af1a78624c98b');
 const helper=require(path.join(root,'tools/native-production-selection.cjs'));
 const selections={};
 for(const mode of ['control','candidate']){
  const row=stage.selections[mode],s=await helper.readProductionSelection(row.file,row.sha256);
  assert.equal(s.mainSourceIdentity.sha256,row.sourceSignature);
  assert.equal(s.runtime.executableSha256,stage.engineSha256);
  selections[mode]=s;
 }
 assert.deepEqual(selections.control.options,selections.candidate.options);
 assert.deepEqual(selections.control.flags,selections.candidate.flags);
 assert.equal(selections.control.preferences.render.sha256,selections.candidate.preferences.render.sha256);
 assert.equal(selections.control.preferences.layout.sha256,selections.candidate.preferences.layout.sha256);
 const baseline=new Map(selections.control.mainSourceIdentity.files.map(x=>[x.file,x.sha256]));
 assert.deepEqual(selections.candidate.mainSourceIdentity.files.filter(x=>baseline.get(x.file)!==x.sha256).map(x=>x.file).sort(),stage.changed.slice().sort());
 return {pair,stageSha256:sha(stageFile),engineSha256:stage.engineSha256,recordingSha256:stage.recordingSha256,order,profiling:true,steadyMs:5000};
}

async function leg(name){
 const mode=name.startsWith('candidate')?'candidate':'control',run='nwn62-small-recipe-f-'+pair+'-'+name;
 const report=path.join(root,'reports',run+'.json'),log=path.join(scope,run+'.driver.log');
 assert(!fs.existsSync(report)&&!fs.existsSync(log),'Preserve previous run: '+name);
 const row=stage.selections[mode];
 const args=[path.join(root,'tools/replay-native-loading.mjs'),'--capture='+stage.capture,'--generation=2','--production-selection='+row.file,'--production-selection-sha256='+row.sha256,'--engine=production-selection','--profiling=true','--steady-ms=5000','--preview','--run='+run];
 const output=fs.createWriteStream(log,{flags:'wx'});
 const child=spawn(process.execPath,args,{cwd:root,windowsHide:true,stdio:['ignore','pipe','pipe']});
 for(const stream of [child.stdout,child.stderr])stream.on('data',chunk=>output.write(chunk));
 const exit=await new Promise((resolve,reject)=>{child.once('error',reject);child.once('exit',resolve)});
 await new Promise(resolve=>output.end(resolve));
 console.log(JSON.stringify({run,exit,report,reportSha256:fs.existsSync(report)?sha(report):null}));
 assert(exit===0||exit===1,'Unexpected driver exit');
 return {run,mode,exit,report,reportSha256:sha(report)};
}

async function main(){
 const plan=await verify();
 if(process.argv.includes('--verify-only')){console.log(JSON.stringify({...plan,clientStarts:0}));return}
 const runs=[];
 for(const name of order){runs.push(await leg(name));fs.writeFileSync(path.join(scope,'matrix-partial.json'),JSON.stringify({plan,runs},null,2)+'\n')}
 console.log(JSON.stringify({complete:true,runs:runs.length}));
}
main().catch(error=>{console.error(error.stack);process.exitCode=1});
