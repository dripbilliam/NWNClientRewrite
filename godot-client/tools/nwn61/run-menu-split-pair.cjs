'use strict';
// Exclusive graphical timing lease only. --verify-only starts no client.
const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const assert=require('node:assert/strict');
const {spawn}=require('node:child_process');
const root=path.resolve(__dirname,'../..');
const scope=path.join(root,'.cache/nwn61/entry-menu-split-pair-a');
const pairFile=path.join(scope,'pair.json');
const pair=JSON.parse(fs.readFileSync(pairFile));
const single=process.argv.find(x=>x.startsWith('--single='))?.slice('--single='.length);
if(single && !/^candidate-[3-9]$/.test(single))throw Error('Unexpected single leg');
const order=single?[single]:['candidate-1','control-1','control-2','candidate-2'];
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
async function verify(){
 assert(pair.private && pair.launched===false);
 assert.deepEqual(pair.changed,['systems/native_key_settings.gd','systems/native_main_menu.gd','systems/native_video_options.gd']);
 assert.equal(sha(path.join(pair.recording.directory,'recording.json')),pair.recording.recordingJsonSha256);
 const helper=require(path.join(root,'tools/native-production-selection.cjs'));
 const selections={};
 for(const mode of ['control','candidate']){
  const row=pair.selections[mode];
  const selection=await helper.readProductionSelection(row.file,row.sha256);
  assert.equal(selection.mainSourceIdentity.sha256,row.sourceIdentity);
  assert.equal(selection.runtime.executableSha256,pair.engineSha256);
  selections[mode]=selection;
 }
 assert.deepEqual(selections.control.options,selections.candidate.options);
 assert.deepEqual(selections.control.flags,selections.candidate.flags);
 assert.equal(selections.control.preferences.render.sha256,selections.candidate.preferences.render.sha256);
 assert.equal(selections.control.preferences.layout.sha256,selections.candidate.preferences.layout.sha256);
 const old=new Map(selections.control.mainSourceIdentity.files.map(x=>[x.file,x.sha256]));
 assert.deepEqual(selections.candidate.mainSourceIdentity.files.filter(x=>old.get(x.file)!==x.sha256).map(x=>x.file).sort(),pair.changed);
 return {pairSha256:sha(pairFile),engineSha256:pair.engineSha256,recordingSha256:pair.recording.recordingJsonSha256,order,profiling:false,steadyMs:5000};
}
async function leg(name){
 const mode=name.startsWith('candidate')?'candidate':'control';
 const run='nwn61-menu-split-'+(single?'d':'c')+'-'+name;
 const report=path.join(root,'reports',run+'.json');
 const log=path.join(scope,run+'.driver.log');
 assert(!fs.existsSync(report)&&!fs.existsSync(log),'Preserve previous run: '+name);
 const row=pair.selections[mode];
 const args=[path.join(root,'tools/replay-native-loading.mjs'),'--capture='+pair.recording.directory,'--generation=2','--production-selection='+row.file,'--production-selection-sha256='+row.sha256,'--engine=production-selection','--profiling=false','--observe-profile=false','--steady-ms=5000','--preview','--run='+run];
 const output=fs.createWriteStream(log,{flags:'wx'});
 const child=spawn(process.execPath,args,{cwd:root,windowsHide:true,stdio:['ignore','pipe','pipe']});
 for(const stream of [child.stdout,child.stderr])stream.on('data',chunk=>output.write(chunk));
 const exit=await new Promise((resolve,reject)=>{child.once('error',reject);child.once('exit',resolve)});
 await new Promise(resolve=>output.end(resolve));
 console.log(JSON.stringify({run,exit,report,reportSha256:fs.existsSync(report)?sha(report):null}));
 assert(exit===0||exit===1,'Unexpected driver exit');
 assert(fs.existsSync(report),'Missing replay report: '+run);
 return {run,mode,exit,report,reportSha256:sha(report)};
}
async function main(){
 const plan=await verify();
 if(process.argv.includes('--verify-only')){console.log(JSON.stringify({...plan,clientStarts:0}));return;}
 const runs=[];
 for(const name of order){runs.push(await leg(name));fs.writeFileSync(path.join(scope,single?'matrix-partial-d.json':'matrix-partial.json'),JSON.stringify({plan,runs},null,2)+'\n')}
 console.log(JSON.stringify({complete:true,runs:runs.length}));
}
main().catch(error=>{console.error(error.stack);process.exitCode=1});
