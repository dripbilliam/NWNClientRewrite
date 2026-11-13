'use strict';
// Coordinator-only graphical ABBA. --verify-only never starts a process.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict'),{spawn}=require('node:child_process');
const root=path.resolve(__dirname,'../..'),sha=b=>crypto.createHash('sha256').update(b).digest('hex'),read=f=>fs.readFileSync(f);
const planArg=process.argv.find(x=>x.startsWith('--plan='))?.slice(7);assert(planArg,'Pass --plan');
const planFile=path.resolve(root,planArg),planBytes=read(planFile),plan=JSON.parse(planBytes);
function verify(){
 assert.equal(plan.issue,'NWN-71');assert.equal(plan.status,'staged-no-launch');assert.deepEqual(plan.order,['off','on','on','off']);
 const selectionBytes=read(plan.selection.file);assert.equal(sha(selectionBytes),plan.selection.sha256);const selection=JSON.parse(selectionBytes);
 assert.equal(selection.sourceProject,path.join(path.dirname(plan.selection.file),'project'));
 const helper=require(path.join(selection.sourceProject,'tools/native-production-selection.cjs'));
 helper.validatePins(selection);helper.validatePreferencePins(selection);
 assert.equal(selection.mainSourceIdentity.sha256,plan.selection.sourceIdentity);
 assert.equal(require(path.join(selection.sourceProject,'tools/native-feature-manifest.cjs')).sourceIdentity(selection.sourceProject).sha256,plan.selection.sourceIdentity);
 assert.equal(selection.runtime.executable,plan.engine.file);assert.equal(selection.runtime.executableSha256,plan.engine.sha256);assert.equal(sha(read(plan.engine.file)),plan.engine.sha256);
 for(const [relative,pin] of Object.entries(plan.overlay))assert.equal(sha(read(path.join(selection.sourceProject,relative))),pin);
 const gamma=read(path.join(selection.sourceProject,'systems/native_render/native_gamma_effect.gd')).toString();
 assert(gamma.includes('const Post=preload("res://systems/native_render/native_postprocess.gd")'));
 assert(gamma.includes('OS.get_environment("NWN71_CPU_MIDPOINT")=="1"'));
 assert(gamma.includes('Post.midpoint_tone_cpu('));
 assert.equal(sha(read(path.join(plan.capture.directory,'recording.json'))),plan.capture.recordingSha256);
 assert.equal(sha(read(path.join(plan.capture.directory,'timeline.jsonl'))),plan.capture.timelineSha256);
 assert.equal(plan.capture.generation,2);
 for(const key of ['render','layout'])assert.equal(sha(read(path.join(path.dirname(plan.selection.file),plan.preferences[key].relative))),plan.preferences[key].sha256);
 assert(!Object.hasOwn(selection.environment,'NWN71_CPU_MIDPOINT'));
 assert.equal(plan.environmentRoute.switch,'NWN71_CPU_MIDPOINT');assert.equal(plan.environmentRoute.off,'0');assert.equal(plan.environmentRoute.on,'1');
 const driverText=read(path.join(root,'tools/replay-native-loading.mjs')).toString();
 assert(driverText.includes('env:{...process.env,...(clientCapsule?.environment??{})'));
 return {verified:true,issue:'NWN-71',selectionSha256:plan.selection.sha256,sourceIdentity:plan.selection.sourceIdentity,engineSha256:plan.engine.sha256,recordingSha256:plan.capture.recordingSha256,preferences:{render:plan.preferences.render.sha256,layout:plan.preferences.layout.sha256},legs:plan.order.map((mode,index)=>({index,mode,childEnvironment:{NWN71_CPU_MIDPOINT:plan.environmentRoute[mode],NWN71_GAMMA_PREWARM:plan.environmentRoute.gammaPrewarm}})),identicalSourceAllLegs:true,clientStarts:0};
}
async function run(){
 const check=verify();
 if(process.argv.includes('--verify-only')){
  const receipt=path.join(path.dirname(planFile),'verify-receipt.json');
  if(fs.existsSync(receipt))assert.deepEqual(JSON.parse(read(receipt)),check);else fs.writeFileSync(receipt,JSON.stringify(check,null,2)+'\n',{flag:'wx'});
  console.log(JSON.stringify(check));return;
 }
 assert(process.argv.includes('--run-after-exclusive-lease'),'Graphical run requires explicit coordinator lease switch');
 const output=path.join(path.dirname(planFile),'run-receipt.json');assert(!fs.existsSync(output),'Preserve previous graphical receipts');
 const legs=[];
 for(const [index,mode] of plan.order.entries()){
  verify();const runTag=path.basename(path.dirname(planFile)).match(/pair-([a-z])$/)?.[1]??'a';const runName=`nwn71-cpu-midpoint-original-${runTag}-${index+1}-${mode}`;
  const args=[path.join(root,'tools/replay-native-loading.mjs'),'--capture='+plan.capture.directory,'--generation='+plan.capture.generation,'--production-selection='+plan.selection.file,'--production-selection-sha256='+plan.selection.sha256,'--engine=production-selection',...plan.argv,'--run='+runName];
  const env={...process.env,NWN71_CPU_MIDPOINT:plan.environmentRoute[mode],NWN71_GAMMA_PREWARM:plan.environmentRoute.gammaPrewarm};
  const log=path.join(path.dirname(planFile),`leg-${index+1}-${mode}.driver.log`),stream=fs.createWriteStream(log,{flags:'wx'});
  const child=spawn(process.execPath,args,{cwd:root,windowsHide:true,stdio:['ignore','pipe','pipe'],env});let tail='';
  for(const input of [child.stdout,child.stderr])input.on('data',data=>{stream.write(data);tail=(tail+data.toString()).slice(-12000)});
  const timer=setTimeout(()=>child.kill(),240000);
  const exit=await new Promise((resolve,reject)=>{child.once('error',reject);child.once('exit',resolve)});clearTimeout(timer);await new Promise(resolve=>stream.end(resolve));
  const report=path.join(root,'reports',runName+'.json');
  const leg={index,mode,childEnvironment:{NWN71_CPU_MIDPOINT:env.NWN71_CPU_MIDPOINT,NWN71_GAMMA_PREWARM:env.NWN71_GAMMA_PREWARM},exit,report:fs.existsSync(report)?{file:report,sha256:sha(read(report))}:null,driverLog:{file:log,sha256:sha(read(log))},selectionSha256:plan.selection.sha256};legs.push(leg);
  fs.writeFileSync(output,JSON.stringify({issue:'NWN-71',plan:planFile,planSha256:sha(planBytes),legs,complete:false},null,2)+'\n');
  if(exit!==0){
   const result=leg.report?JSON.parse(read(report)):null;
   const engineLog=path.join(root,'reports',runName+'.engine.log');
   const errors=fs.existsSync(engineLog)?read(engineLog).toString().split(/\r?\n/).filter(line=>line.startsWith('ERROR: ')):[];
   const expectedErrors=new Set(["ERROR: Can't create shader cache folder, no shader caching will happen: user://",'ERROR: Failed to read the root certificate store.']);
   const knownDiagnostics=exit===1&&result?.native?.success===true&&result?.failure==='Native engine/lifetime diagnostics observed'&&result?.sourceUnchanged===true&&result?.runtimeUnchanged===true&&result?.native?.performance_window?.steady===true&&errors.length===2&&errors.every(line=>expectedErrors.has(line));
   if(!knownDiagnostics){console.error(tail);throw Error(`Leg ${index+1} exited ${exit}`)}
  }
 }
 verify();fs.writeFileSync(output,JSON.stringify({issue:'NWN-71',plan:planFile,planSha256:sha(planBytes),legs,complete:true},null,2)+'\n');
 console.log(JSON.stringify({complete:true,legs:legs.length,output}));
}
run().catch(error=>{console.error(error.stack);process.exitCode=1});
