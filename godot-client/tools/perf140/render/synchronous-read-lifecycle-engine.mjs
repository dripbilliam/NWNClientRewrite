// PRIVATE TEST ENGINE ONLY. Source-prepared; each action needs Root's explicit
// execution grant. Never install this probe into a production/performance tree.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {generatedLifecycleOrder,parseLifecycleRecord,lifecyclePhasesValid,lifecycleEngineErrors} from './lifecycle_proof_contract.mjs';

const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const base=path.join(project,'.cache/native-140fps/render-agent');
const label='engine-synchronous-particle-reads-lifecycle-test-v1',directory=path.join(base,label);
const [action,value]=process.argv.slice(2),hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const fileHash=f=>hash(fs.readFileSync(f));
const moduleName='nwn_particle_reads_lifecycle_test',prefix='module/'+moduleName+'/';
const freezeFile=path.join(project,'.cache/native-140fps/particles-agent/synchronous-engine-read-lifecycle-source-v1/source-manifest.json');
const freezeSha256='2eee803ff43619ab49fb7d12657a1bb191b8d0a2e83fdb65a2588444092c0815';
const production=path.join(base,'engine-synchronous-particle-reads-v2');
const productionDescriptor=path.join(production,'engine-descriptor.json');
const manifestFile=path.join(directory,'manifest.json');

function assertInputs(m){
 if(m.testOnly!==true||m.performanceAccepted!==false)throw Error('Lifecycle source must be explicitly test-only');
 for(const guard of m.guards)if(fileHash(guard.path)!==guard.sha256)throw Error('Retained/shared test guard drift: '+guard.path);
 for(const mod of [{directory:m.moduleDirectory,pins:m.modulePins},...m.inheritedModules])for(const pin of mod.pins)if(fileHash(path.join(mod.directory,pin.relative))!==pin.sha256)throw Error('Test/inherited module source drift');
 for(const patch of [m.nodePatch,m.fontPatch])if(fileHash(path.join(m.source,patch.relative))!==patch.afterSha256)throw Error('Inherited Node/font source drift');
}
function orderProof(m){
 const file=path.join(m.source,'modules/register_module_types.gen.cpp'),text=fs.readFileSync(file,'utf8');
 const order=generatedLifecycleOrder(text);
 const result={version:1,testOnly:true,file,sha256:fileHash(file),...order,scope:'Actual derived generated source, both functions independently checked; no reverse teardown assumption.'};
 const proof=path.join(directory,'generated-order-'+result.sha256.slice(0,16)+'.json'),bytes=JSON.stringify(result,null,2)+'\n';
 if(fs.existsSync(proof)){if(fs.readFileSync(proof,'utf8')!==bytes)throw Error('Retain conflicting order proof');}else fs.writeFileSync(proof,bytes,{flag:'wx'});
 return {file:proof,sha256:fileHash(proof),generatedFile:file,generatedSha256:result.sha256};
}

if(action==='stage'){
 if(value!=='--stage-test-engine')throw Error('Explicit --stage-test-engine execution approval flag required');
 if(fs.existsSync(directory))throw Error('Preserve earlier lifecycle test engine');
 if(fileHash(freezeFile)!==freezeSha256)throw Error('Frozen lifecycle source changed');
 const freeze=JSON.parse(fs.readFileSync(freezeFile)),d=JSON.parse(fs.readFileSync(productionDescriptor));
 const parent=JSON.parse(fs.readFileSync(d.sourceManifest));
 if(freeze.testOnly!==true||freeze.requiredProducer!=='nwn_particle_reads'||freeze.producerManifestSha256!=='32c32bcb91a9d03782d62c575b44548a25a6b343378f2b3fe107e19fe23260e8'||freeze.abiSha256!=='985efa740c5284506b50f2703d4d9b028d2b5b7414f883a2461000bacc7f7527')throw Error('Exact producer/test source contract differs');
 if(d.engines.candidate.buildExitCode!==0||d.engines.candidate.sourceUnchanged!==true||fileHash(d.sourceManifest)!==d.sourceManifestSha256||fileHash(d.engines.candidate.path)!==d.engines.candidate.sha256)throw Error('Production engine must have a clean retained build first');
 for(const guard of parent.guards)if(fileHash(guard.path)!==guard.sha256)throw Error('Retained producer guard changed');
 for(const mod of [{directory:parent.moduleDirectory,pins:parent.modulePins},...parent.inheritedModules])for(const pin of mod.pins)if(fileHash(path.join(mod.directory,pin.relative))!==pin.sha256)throw Error('Retained producer/inherited module changed');
 for(const pin of freeze.files)if(fileHash(path.join(path.dirname(freezeFile),pin.relative))!==pin.sha256)throw Error('Frozen lifecycle file changed');
 fs.mkdirSync(directory,{recursive:true});const source=path.join(directory,'source');
 fs.cpSync(parent.source,source,{recursive:true,preserveTimestamps:true,force:false,errorOnExist:true});
 const moduleDirectory=path.join(source,'modules',moduleName);if(fs.existsSync(moduleDirectory))throw Error('Probe already present in production tree');fs.mkdirSync(moduleDirectory);
 const modulePins=freeze.files.filter(pin=>pin.relative.startsWith(prefix)).map(pin=>({relative:pin.relative.slice(prefix.length),sha256:pin.sha256}));
 if(modulePins.length!==6)throw Error('Expected exact six-file lifecycle module');
 for(const pin of modulePins)fs.copyFileSync(path.join(path.dirname(freezeFile),prefix,pin.relative),path.join(moduleDirectory,pin.relative));
 const inheritedModules=[{directory:path.join(source,path.relative(parent.source,parent.moduleDirectory)),pins:parent.modulePins},...parent.inheritedModules.map(mod=>({...mod,directory:path.join(source,path.relative(parent.source,mod.directory))}))];
 const guards=[...parent.guards,{path:productionDescriptor,sha256:fileHash(productionDescriptor),kind:'retained-production-engine-descriptor'},{path:d.engines.candidate.path,sha256:d.engines.candidate.sha256,kind:'retained-production-engine'},{path:freezeFile,sha256:freezeSha256,kind:'frozen-test-only-lifecycle-source'},{path:fileURLToPath(import.meta.url),sha256:fileHash(fileURLToPath(import.meta.url)),kind:'lifecycle-recipe-source'}];
 const helper=path.join(project,'tools/perf140/render/lifecycle_proof_contract.mjs');guards.push({path:helper,sha256:fileHash(helper),kind:'lifecycle-proof-parser-source'});
 for(const relative of ['main/main.cpp','modules/modules_builders.py'])for(const root of [parent.source,source])guards.push({path:path.join(root,relative),sha256:fileHash(path.join(root,relative)),kind:'unchanged-engine-lifecycle-order-source'});
 const m={...parent,directory,source,reusedSource:undefined,testOnly:true,performanceAccepted:false,parentDescriptor:productionDescriptor,parentDescriptorSha256:fileHash(productionDescriptor),moduleManifest:freezeFile,moduleManifestSha256:freezeSha256,moduleDirectory,modulePins,inheritedModules,guards,lifecycleSourceFreeze:{file:freezeFile,sha256:freezeSha256},variantDescription:'TEST ONLY actual cold CORE/SCENE/SERVERS producer lifetime probe; never a gameplay/performance engine',baselineRole:'Retained production synchronous read engine, no test probe',candidateRole:'Same source/flags plus test-only cold lifecycle module; not accepted by benchmark driver',buildStarted:false};
 fs.writeFileSync(manifestFile,JSON.stringify(m,null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({manifest:manifestFile,testOnly:true,builds:0,engineStarts:0,requiredNext:'Build with existing build-engine-scene-snapshot.ps1, then order/finalize before any run.'}));
}else if(action==='order'){
 const m=JSON.parse(fs.readFileSync(manifestFile));assertInputs(m);console.log(JSON.stringify(orderProof(m)));
}else if(action==='finalize'){
 if(!/^build-[0-9]+$/.test(value??''))throw Error('Exact completed build receipt label required');
 const m=JSON.parse(fs.readFileSync(manifestFile));assertInputs(m);const order=orderProof(m);
 const run=path.join(directory,value),receiptFile=path.join(run,'receipt.json'),invocationFile=path.join(run,'invocation.json');
 const r=JSON.parse(fs.readFileSync(receiptFile)),inv=JSON.parse(fs.readFileSync(invocationFile)),parent=JSON.parse(fs.readFileSync(m.parentDescriptor));
 if(r.exitCode!==0||r.sourceUnchanged!==true||JSON.stringify(inv.arguments)!==JSON.stringify(parent.engines.candidate.arguments)||inv.compilerSha256!==parent.engines.candidate.compilerSha256)throw Error('Test build failed or compiler/flags differ');
 const output=r.outputs.find(v=>v.path.endsWith('godot.windows.template_release.x86_64.exe'));
 if(!output||!path.resolve(output.path).startsWith(directory+path.sep)||fileHash(output.path)!==output.sha256)throw Error('Actual archived test engine missing/drifted');
 const descriptor={version:1,testOnly:true,performanceAccepted:false,scope:m.variantDescription,sourceManifest:manifestFile,sourceManifestSha256:fileHash(manifestFile),lifecycleSourceFreeze:m.lifecycleSourceFreeze,generatedOrder:order,engine:{...output,buildExitCode:0,sourceUnchanged:true,buildReceipt:receiptFile,buildReceiptSha256:fileHash(receiptFile),invocation:invocationFile,invocationSha256:fileHash(invocationFile),compilerSha256:inv.compilerSha256,arguments:inv.arguments},testsRun:0};
 const file=path.join(directory,'lifecycle-test-engine.json');fs.writeFileSync(file,JSON.stringify(descriptor,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({file,sha256:fileHash(file),testOnly:true,benchmarkDescriptor:false}));
}else if(action==='check'){
 if(!/^[a-z0-9-]+$/.test(value??''))throw Error('Fresh private functional run label required');
 const run=path.join(base,value);if(fs.existsSync(run))throw Error('Retain earlier lifecycle evidence');
 const descriptorFile=path.join(directory,'lifecycle-test-engine.json'),d=JSON.parse(fs.readFileSync(descriptorFile)),m=JSON.parse(fs.readFileSync(d.sourceManifest));assertInputs(m);
 if(d.testOnly!==true||d.performanceAccepted!==false||fileHash(d.sourceManifest)!==d.sourceManifestSha256||fileHash(d.engine.path)!==d.engine.sha256||fileHash(d.engine.buildReceipt)!==d.engine.buildReceiptSha256||fileHash(d.engine.invocation)!==d.engine.invocationSha256||fileHash(d.generatedOrder.file)!==d.generatedOrder.sha256||fileHash(d.generatedOrder.generatedFile)!==d.generatedOrder.generatedSha256)throw Error('Actual test engine/order proof changed');
 fs.mkdirSync(run,{recursive:true});const app=path.join(run,'project');fs.mkdirSync(path.join(app,'.godot'),{recursive:true});
 fs.writeFileSync(path.join(app,'project.godot'),'config_version=5\n[application]\nconfig/name="Private producer lifecycle test"\n');
 fs.writeFileSync(path.join(app,'.godot/global_script_class_cache.cfg'),'list=[]\n');
 fs.writeFileSync(path.join(app,'quit.gd'),'extends SceneTree\nfunc _initialize() -> void:\n\tcall_deferred("quit")\n');
 const log=path.join(run,'engine.log'),args=['--headless','--path',app,'--log-file',log,'--script','res://quit.gd'];
 fs.writeFileSync(path.join(run,'invocation.json'),JSON.stringify({engine:d.engine,args,gpu:false,serverConnections:0,testOnly:true},null,2));
 const result=await new Promise(resolve=>{const child=spawn(d.engine.path,args,{windowsHide:true,stdio:['ignore','pipe','pipe']});let stdout='',stderr='',error=null,timedOut=false;child.stdout.on('data',b=>{stdout+=b;});child.stderr.on('data',b=>{stderr+=b;});child.once('error',e=>{error=e.message;});const timeout=setTimeout(()=>{timedOut=true;child.kill();},60000);child.once('close',(exitCode,signal)=>{clearTimeout(timeout);resolve({exitCode,signal,stdout,stderr,error,timedOut});});});
 fs.writeFileSync(path.join(run,'stdout.log'),result.stdout);fs.writeFileSync(path.join(run,'stderr.log'),result.stderr);
 let native=null,parseError=null;try{native=parseLifecycleRecord(result.stdout);}catch(error){parseError=error.message;}
 const phasesValid=lifecyclePhasesValid(native);
 const errors=lifecycleEngineErrors(result.stdout,result.stderr,fs.existsSync(log)?fs.readFileSync(log,'utf8'):'');
 assertInputs(m);const success=result.exitCode===0&&!result.error&&!result.timedOut&&!parseError&&!errors&&phasesValid;
 const receipt={version:1,success,testOnly:true,exitCode:result.exitCode,signal:result.signal,error:result.error,timedOut:result.timedOut,parseError,engineErrors:errors,phasesValid,native,descriptorFile,descriptorSha256:fileHash(descriptorFile),gpu:false,serverConnections:0,scope:'Actual cold producer activation/deactivation only; not hot DLL unload or gameplay/performance acceptance.'};
 fs.writeFileSync(path.join(run,'receipt.json'),JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success,run,native,engineErrors:errors,parseError}));if(!success)process.exitCode=1;
}else throw Error('Choose explicit stage, order, finalize or check action; source preparation alone starts nothing.');
