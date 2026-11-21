// Run only in a Root-granted functional CPU lane. This does not build a DLL,
// create/copy an engine/project, connect to a server, or launch a GPU renderer.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';

const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const label=process.argv[2];
const argument=name=>process.argv.find(value=>value.startsWith('--'+name+'='))?.slice(name.length+3);
if(!/^[a-z0-9-]+$/.test(label??''))throw Error('Fresh private check label required');
const fixtureFile=argument('fixture-manifest');
if(!fixtureFile||!path.isAbsolute(fixtureFile))throw Error('Explicit absolute built fixture manifest required');
const base=path.join(project,'.cache/native-140fps/render-agent'),stage=path.join(base,label);
if(fs.existsSync(stage))throw Error('Retain all prior functional evidence');
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex'),fileHash=file=>hash(fs.readFileSync(file));
const descriptorFile=path.join(base,'engine-synchronous-particle-reads-v2/engine-descriptor.json');
const d=JSON.parse(fs.readFileSync(descriptorFile));
const m=JSON.parse(fs.readFileSync(d.sourceManifest));
if(d.version!==1||d.retainedPairedEnginesUnchanged!==true||d.sharedOutputsUnchanged!==true||fileHash(d.sourceManifest)!==d.sourceManifestSha256||fileHash(d.moduleManifest)!==d.moduleManifestSha256)throw Error('Engine source proof changed');
if(m.sourceFreeze.sha256!=='32c32bcb91a9d03782d62c575b44548a25a6b343378f2b3fe107e19fe23260e8'||fileHash(m.sourceFreeze.file)!==m.sourceFreeze.sha256)throw Error('Exact producer V2 source freeze changed');
const module=JSON.parse(fs.readFileSync(d.moduleManifest));
if(path.resolve(module.module)!==path.resolve(m.moduleDirectory)||module.abi.sha256!=='985efa740c5284506b50f2703d4d9b028d2b5b7414f883a2461000bacc7f7527')throw Error('Actual producer module/ABI proof differs');
for(const pin of module.pins)if(fileHash(path.join(module.module,pin.relative))!==pin.sha256)throw Error('Actual producer module changed');
const engines=[['present',d.engines.candidate],['absent',d.engines.baseline]];
if(engines[1][1].sha256!=='0f8876c3dd25927e4e1064142e4fcd51e103d757e11b0cc19de1c909acb371b9')throw Error('Missing-module control must be exact immutable-font parent');
for(const [,engine] of engines)if(engine.buildExitCode!==0||engine.sourceUnchanged!==true||fileHash(engine.path)!==engine.sha256||fileHash(engine.buildReceipt)!==engine.buildReceiptSha256||fileHash(engine.invocation)!==engine.invocationSha256)throw Error('Built engine proof differs');
if(d.engines.candidate.compilerSha256!==d.engines.baseline.compilerSha256||JSON.stringify(d.engines.candidate.arguments)!==JSON.stringify(d.engines.baseline.arguments))throw Error('Same-feature engine compiler/flags differ');
const fixture=JSON.parse(fs.readFileSync(fixtureFile));
if(fixture.version!==1||fixture.compiled!==true||fixture.testOnly!==true||fixture.compileDefine!=='NWN_PARTICLE_READ_TEST_ACCESS'||fixture.sourceUnchanged!==true||fixture.sharedOutputsUnchanged!==true||fixture.entry!=='tests/native_perf140_particle_fused_read_actual_test.gd'||!path.isAbsolute(fixture.project)||!Array.isArray(fixture.pins)||!fixture.pins.length)throw Error('Actual private fixture build proof is incomplete');
const fixtureProject=path.resolve(fixture.project);
if(!fixtureProject.startsWith(path.join(project,'.cache/native-140fps')+path.sep))throw Error('Fixture must remain inside the private experiment tree');
function assertFixture(){
 for(const pin of fixture.pins){
  const file=path.resolve(fixtureProject,pin.relative);
  if(!file.startsWith(fixtureProject+path.sep)||fileHash(file)!==pin.sha256)throw Error('Actual fixture pin changed: '+pin.relative);
 }
}
assertFixture();
for(const required of ['project.godot',fixture.entry,'.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-kernel/build-manifest.json'])if(!fixture.pins.some(pin=>pin.relative.replaceAll('\\','/')===required))throw Error('Missing actual fixture proof: '+required);
for(const guard of m.guards)if(fileHash(guard.path)!==guard.sha256)throw Error('Retained/shared guard changed');
fs.mkdirSync(stage,{recursive:true});
const results=[];
const outsideError={message:'Condition "!is_inside_tree()" is true. Returning: Transform3D()',count:2,function:'Node3D::get_global_transform'};
async function runCase(expectModule,engine,testCase){
 const directory=path.join(stage,testCase==='normal'?expectModule:expectModule+'-'+testCase);fs.mkdirSync(directory);
 const report=path.join(directory,'native.json'),log=path.join(directory,'engine.log');
 const args=['--headless','--path',fixtureProject,'--log-file',log,'--script','res://'+fixture.entry,'--','--report='+report,'--expect-module='+expectModule,'--case='+testCase];
 const invocation={engine,entry:fixture.entry,args,gpu:false,serverConnections:0,expectedModule:expectModule,case:testCase,compileDefine:fixture.compileDefine};
 fs.writeFileSync(path.join(directory,'invocation.json'),JSON.stringify(invocation,null,2)+'\n',{flag:'wx'});
 const result=await new Promise(resolve=>{
  const child=spawn(engine.path,args,{windowsHide:true,stdio:['ignore','pipe','pipe'],env:{...process.env,NWN_PARTICLE_KERNEL:'compiled',NWN_PARTICLE_READS:'ordinary'}});
  let stdout='',stderr='',error=null,timedOut=false;
  child.stdout.on('data',bytes=>{stdout+=bytes;});child.stderr.on('data',bytes=>{stderr+=bytes;});
  child.once('error',value=>{error=value.message;});
  const timeout=setTimeout(()=>{timedOut=true;child.kill();},120000);
  // Wait for CLOSE: stdout/log writers may still be active at process exit.
  child.once('close',(exitCode,signal)=>{clearTimeout(timeout);resolve({exitCode,signal,error,timedOut,stdout,stderr});});
 });
 fs.writeFileSync(path.join(directory,'stdout.log'),result.stdout);fs.writeFileSync(path.join(directory,'stderr.log'),result.stderr);
 const native=fs.existsSync(report)?JSON.parse(fs.readFileSync(report)):null;
 const logText=fs.existsSync(log)?fs.readFileSync(log,'utf8'):'';
 const combined=[result.stdout,result.stderr,logText].join('\n');
 const errorBodies=text=>[...text.matchAll(/^ERROR:\s*(.*)$/gm)].map(match=>match[1].trim());
 const canonicalErrors=errorBodies(logText),consoleErrors=errorBodies(result.stdout+'\n'+result.stderr);
 const lifetimeOrScriptError=/SCRIPT ERROR|ObjectDB.*leak|resources still in use/im.test(combined);
 let expectedErrorPolicyMatched=false;
 if(testCase==='normal'){
  expectedErrorPolicyMatched=canonicalErrors.length===0&&consoleErrors.length===0&&(!native?.expected_engine_errors||native.expected_engine_errors.length===0);
 }else{
  // One isolated negative case: retain the original getter's two errors.
  // Count only the canonical log, not its duplicated console copies. Every
  // console error must still match the exact expected body; no broad filtering.
  const sourceWitnesses=(logText.match(/at:\s+(?:Node3D::)?get_global_transform\s+\(scene\/3d\/node_3d\.cpp:648\)/g)??[]).length;
  const declared=native?.expected_engine_errors;
  const metadataMatches=Array.isArray(declared)&&declared.length===1&&declared[0]&&JSON.stringify(Object.keys(declared[0]).sort())===JSON.stringify(['count','function','message'])&&declared[0].message===outsideError.message&&declared[0].count===2&&declared[0].function===outsideError.function;
  expectedErrorPolicyMatched=native?.case==='outside-transform'&&metadataMatches&&canonicalErrors.length===2&&canonicalErrors.every(body=>body===outsideError.message)&&consoleErrors.every(body=>body===outsideError.message)&&sourceWitnesses===2;
 }
 const engineErrors=lifetimeOrScriptError||!expectedErrorPolicyMatched;
 const value={expectedModule:expectModule,case:testCase,success:result.exitCode===0&&!result.error&&!result.timedOut&&!engineErrors&&native?.success===true,exitCode:result.exitCode,signal:result.signal,error:result.error,timedOut:result.timedOut,engineErrors,expectedErrorPolicyMatched,canonicalErrors,native};
 fs.writeFileSync(path.join(directory,'receipt.json'),JSON.stringify(value,null,2)+'\n',{flag:'wx'});
 return value;
}
const cases=['normal','outside-transform'].flatMap(testCase=>engines.map(([expectModule,engine])=>[expectModule,engine,testCase]));
for(const [expectModule,engine,testCase] of cases){const value=await runCase(expectModule,engine,testCase);results.push(value);if(!value.success)break;}
assertFixture();
const changedGuards=m.guards.filter(guard=>fileHash(guard.path)!==guard.sha256);
const changedModules=module.pins.filter(pin=>fileHash(path.join(module.module,pin.relative))!==pin.sha256);
const changedEngines=engines.filter(([,engine])=>fileHash(engine.path)!==engine.sha256).map(([mode])=>mode);
const receipt={version:1,success:results.length===cases.length&&results.every(value=>value.success)&&!changedGuards.length&&!changedModules.length&&!changedEngines.length,descriptorFile,descriptorSha256:fileHash(descriptorFile),fixtureFile,fixtureSha256:fileHash(fixtureFile),fixtureProject,results,changedGuards,changedModules,changedEngines,gpu:false,serverConnections:0,scope:'Actual fixed ABI/consumer fixture with present producer and exact missing-module parent; clean normal runs plus isolated exact outside-tree getter-error parity, no broad error filtering or timing claim.'};
fs.writeFileSync(path.join(stage,'receipt.json'),JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({success:receipt.success,stage,results:results.map(value=>({expectedModule:value.expectedModule,case:value.case,success:value.success,checks:value.native?.checks,failures:value.native?.failures})),changedGuards,changedModules,changedEngines},null,2));
if(!receipt.success)process.exitCode=1;
