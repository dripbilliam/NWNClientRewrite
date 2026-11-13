import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';

// Deliberately do not enumerate the current application graph: another owner
// may be writing it. Only verified accepted manifest inputs plus this NEW
// fixture are copied into a fresh disposable test project.
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const label=process.argv[2];
if(!/^[a-z0-9-]{3,80}$/.test(label??''))throw Error('Supply a unique evidence label');
const baseline=path.join(project,'.cache/overhead-integration/native-ordinary-text-v5');
const acceptedProofPath=path.join(baseline,'proof.json'),acceptedBytes=fs.readFileSync(acceptedProofPath);
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const accepted=JSON.parse(acceptedBytes);
if(!accepted.success||!accepted.cleanEngine||accepted.inputs.length!==476)throw Error('Unexpected accepted baseline');
const directory=path.join(project,'.cache/tlk-family-before',label),copy=path.join(directory,'inputs');
if(fs.existsSync(directory))throw Error('Preserve earlier evidence');
const within=(root,file)=>file.startsWith(root+path.sep);
const inputs=accepted.inputs.map(row=>{
 const file=path.resolve(path.join(baseline,'inputs'),row.path);
 if(!within(path.join(baseline,'inputs'),file)||!row.sha256?.match(/^[0-9a-f]{64}$/)||hash(fs.readFileSync(file))!==row.sha256)throw Error('Accepted input mismatch: '+row.path);
 return{path:row.path,sha256:row.sha256};
});
if(new Set(inputs.map(row=>row.path.toLowerCase())).size!==inputs.length)throw Error('Ambiguous accepted paths');
const fixturePath=path.join(project,'tests/native_tlk_family_publication_test.gd'),fixtureBytes=fs.readFileSync(fixturePath);
const overlay={path:'godot-client/tests/native_tlk_family_publication_test.gd',sha256:hash(fixtureBytes)};
if(inputs.some(row=>row.path===overlay.path))throw Error('Fixture is not a new overlay');
const outputs=accepted.nativeOutputs;
if(!Array.isArray(outputs)||outputs.length!==6)throw Error('Expected six accepted native output pins');
for(const row of outputs)if(hash(fs.readFileSync(path.join(project,row.file??row.path)))!==row.sha256)throw Error('Shared native output differs from accepted baseline');
const engine=path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe');
if(hash(fs.readFileSync(engine))!==accepted.engineSha256||accepted.engineSha256!=='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424')throw Error('Unexpected engine');
fs.mkdirSync(copy,{recursive:true});
for(const row of inputs){const to=path.resolve(copy,row.path);if(!within(copy,to))throw Error('Copy leaves test root');fs.mkdirSync(path.dirname(to),{recursive:true});fs.copyFileSync(path.resolve(baseline,'inputs',row.path),to);if(hash(fs.readFileSync(to))!==row.sha256)throw Error('Copy mismatch');}
const fixtureCopy=path.join(copy,overlay.path);fs.mkdirSync(path.dirname(fixtureCopy),{recursive:true});fs.writeFileSync(fixtureCopy,fixtureBytes);
const copiedProject=path.join(copy,'godot-client');
for(const match of fixtureBytes.toString().matchAll(/["']res:\/\/([^"'\r\n]+\.gd)["']/g)){
 const relative='godot-client/'+match[1];if(!inputs.some(row=>row.path===relative))throw Error('Fixture dependency is not an accepted input: '+relative);
}
fs.writeFileSync(path.join(copiedProject,'project.godot'),'config_version=5\n[application]\nconfig/name="Sealed TLK Family Before"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n');
fs.mkdirSync(path.join(copiedProject,'.godot'),{recursive:true});fs.writeFileSync(path.join(copiedProject,'.godot/extension_list.cfg'),'res://native/particle_kernel.gdextension\n');
const report=path.join(directory,'result.json'),log=path.join(directory,'engine.log');
console.log(JSON.stringify({stage:'copy-complete',acceptedInputs:inputs.length,overlay,report}));
const outcome=await new Promise(resolve=>{
 const child=spawn(engine,['--headless','--max-fps','60','--path',copiedProject,'--log-file',log,'--script','res://tests/native_tlk_family_publication_test.gd','--','--report='+report],{windowsHide:true,stdio:['ignore','pipe','pipe']});
 let stdout='',stderr='',error=null;
 const stop=reason=>{error??=reason;if(child.exitCode===null)child.kill();};
 const consume=(which,bytes)=>{if(which==='stdout')stdout+=bytes;else stderr+=bytes;if(Buffer.byteLength(stdout)+Buffer.byteLength(stderr)>2*1024*1024){stdout=stdout.slice(-512*1024);stderr=stderr.slice(-512*1024);stop('Owned output exceeded2MiB');}if(/SCRIPT ERROR|Parse Error|^ERROR:/m.test(stdout+'\n'+stderr))stop('Owned engine error');};
 child.stdout.on('data',bytes=>consume('stdout',bytes));child.stderr.on('data',bytes=>consume('stderr',bytes));
 const timer=setTimeout(()=>stop('Owned sealed baseline exceeded65s'),65000);
 child.once('error',value=>{error??=value.message;});
 child.once('close',(code,signal)=>{clearTimeout(timer);resolve({code,signal,error,stdout,stderr,ownedProcessId:child.pid});});
});
fs.writeFileSync(path.join(directory,'stdout.log'),outcome.stdout);fs.writeFileSync(path.join(directory,'stderr.log'),outcome.stderr);
const result=fs.existsSync(report)?JSON.parse(fs.readFileSync(report)):null;
const cleanEngine=!/^(?:ERROR:|WARNING:)|SCRIPT ERROR|Parse Error|ObjectDB instances leaked|Leaked instance|still in use at exit/m.test((fs.existsSync(log)?fs.readFileSync(log,'utf8'):'')+'\n'+outcome.stderr);
const changedAccepted=inputs.filter(row=>hash(fs.readFileSync(path.resolve(baseline,'inputs',row.path)))!==row.sha256).map(row=>row.path);
const changedCopies=inputs.filter(row=>hash(fs.readFileSync(path.resolve(copy,row.path)))!==row.sha256).map(row=>row.path);
const changedOutputs=outputs.filter(row=>hash(fs.readFileSync(path.join(project,row.file??row.path)))!==row.sha256).map(row=>row.file??row.path);
const fixtureUnchanged=hash(fs.readFileSync(fixturePath))===overlay.sha256&&hash(fs.readFileSync(fixtureCopy))===overlay.sha256;
const acceptedProofUnchanged=hash(fs.readFileSync(acceptedProofPath))===hash(acceptedBytes);
const guards=cleanEngine&&!outcome.error&&!changedAccepted.length&&!changedCopies.length&&!changedOutputs.length&&fixtureUnchanged&&acceptedProofUnchanged;
const expected='Failed current job cannot republish a prior loaded table as a new native family';
const failures=result?.failures??[];
const proof={success:guards&&outcome.code===0&&result?.success===true,baselineCaptured:guards&&result!==null,expectedStaleExposure:failures.length===2&&failures.every(row=>row===expected),checks:result?.checks??0,failures,exitCode:outcome.code,error:outcome.error,signal:outcome.signal,cleanEngine,acceptedBaseline:{proof:acceptedProofPath,sha256:hash(acceptedBytes),inputs},overlay,fixtureUnchanged,acceptedProofUnchanged,changedAccepted,changedCopies,nativeOutputs:outputs,changedOutputs,engineSha256:accepted.engineSha256,ownedProcessId:outcome.ownedProcessId,currentProductionEnumerated:false,currentProductionTested:false,scope:result?.scope??'No complete fixture result',gpu:false,serverConnections:0,keyReads:0,nativeBuilds:0,userProcessActions:0};
fs.writeFileSync(path.join(directory,'proof.json'),JSON.stringify(proof,null,2)+'\n');
console.log(JSON.stringify({...proof,acceptedBaseline:{sha256:proof.acceptedBaseline.sha256,inputs:inputs.length}}));
// Expected stale exposure remains a REAL failing baseline. Never turn its
// successful capture into functional production acceptance.
process.exitCode=proof.success?0:1;
