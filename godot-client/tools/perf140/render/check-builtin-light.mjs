import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import {spawnSync} from 'node:child_process';import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),label=process.argv[2]??'builtin-light-check-v1';
if(!/^[a-z0-9-]+$/.test(label))throw Error('Private label required');
const stage=path.join(project,'.cache/native-140fps/render-agent',label);if(fs.existsSync(stage))throw Error('Previous proof retained');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex'),fileHash=f=>hash(fs.readFileSync(f));
const engineDescriptorFile=path.join(project,'.cache/native-140fps/render-agent/engine-builtin-light-v2/engine-descriptor.json'),engineDescriptor=JSON.parse(fs.readFileSync(engineDescriptorFile)),engine=engineDescriptor.engines.candidate;
if(fileHash(engine.path)!==engine.sha256)throw Error('Frozen optional engine changed');
const engineManifest=JSON.parse(fs.readFileSync(engineDescriptor.sourceManifest));for(const guard of engineManifest.guards)if(fileHash(guard.path)!==guard.sha256)throw Error('Retained/shared engine guard changed');
const parentFile=path.join(project,'.cache/native-140fps/root/lease-scene-diagnostics-v1/manifest.json'),parent=JSON.parse(fs.readFileSync(parentFile));
const freezeFile=path.join(project,'.cache/native-140fps/render-agent/builtin-light-source-v2/manifest.json'),freeze=JSON.parse(fs.readFileSync(freezeFile));
const app=path.join(stage,'project'),pins=[];fs.mkdirSync(app,{recursive:true});
for(const pin of parent.pins){const bytes=fs.readFileSync(path.join(parent.project,pin.relative));if(hash(bytes)!==pin.sha256)throw Error('Frozen functional baseline drifted: '+pin.relative);const destination=path.join(app,pin.relative);fs.mkdirSync(path.dirname(destination),{recursive:true});fs.writeFileSync(destination,bytes);pins.push({...pin});}
function install(relative,bytes){const target=path.join(app,relative);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,bytes);let pin=pins.find(pin=>pin.relative===relative);if(!pin){pin={relative};pins.push(pin);}pin.sha256=hash(bytes);}
for(const fixture of freeze.fixtures){const bytes=fs.readFileSync(fixture.file);if(hash(bytes)!==fixture.sha256)throw Error('Frozen fixture changed');install(fixture.relative,bytes);}
const fixtureOverrides=[];
if(process.argv.includes('--extended')){
 const relative='tests/native_perf140_render_builtin_light_registry_test.gd',bytes=fs.readFileSync(path.join(project,relative));install(relative,bytes);fixtureOverrides.push({relative,sha256:hash(bytes),scope:'Explicit new lifecycle/getter oracle on unchanged frozen V2 engine/module'});
}
if(process.argv.includes('--corrected-adapter')){
 const relative='tools/perf140/render/focus_lighting_builtin_input_candidate.gd',bytes=fs.readFileSync(path.join(project,relative));install(relative,bytes);fixtureOverrides.push({relative,sha256:hash(bytes),scope:'Explicit super constructor fix; unchanged frozen V2 engine/module'});
}
const full='tests/native_light_input_registry_test.gd';let fullSource=fs.readFileSync(path.join(project,full),'utf8');
const before='Focus=load("res://systems/native_render/focus_lighting_native_input_candidate.gd")',after='Focus=load("res://tools/perf140/render/focus_lighting_builtin_input_candidate.gd")';
if(fullSource.split(before).length!==2)throw Error('Inherited full Focus fixture boundary changed');fullSource=fullSource.replace(before,after);install(full,Buffer.from(fullSource));
const baseline=path.join(app,'systems/native_render/focus_lighting.gd'),baselineHash=/const BASELINE_SHA="([a-f0-9]{64})"/.exec(fullSource)?.[1];
if(fileHash(baseline)!==baselineHash)throw Error('Exact original Focus fixture baseline not in this cohort');
install('project.godot',Buffer.from(fs.readFileSync(path.join(app,'project.godot'),'utf8').replace(/\[autoload\][\s\S]*?(?=\n\[|$)/,'')));
const suites=[['direct','tests/native_perf140_render_builtin_light_registry_test.gd',[],true],['focus',full,['--baseline='+baseline],true]],results=[];
if(process.argv.includes('--corrected-adapter'))suites.push(['focus-extension',full,['--baseline='+baseline],false]);
for(const [name,entry,extra,builtin]of suites){
 const directory=path.join(stage,name);fs.mkdirSync(directory);const report=path.join(directory,'native.json'),log=path.join(directory,'engine.log'),args=['--headless','--path',app,'--log-file',log,'--script','res://'+entry,'--','--report='+report,...(builtin?['--light-input-registry=builtin']:[]),...extra];
 fs.writeFileSync(path.join(directory,'invocation.json'),JSON.stringify({engine:engine.path,engineSha256:engine.sha256,args,gpu:false,serverConnections:0},null,2));
 const result=spawnSync(engine.path,args,{windowsHide:true,encoding:'utf8',timeout:45000,maxBuffer:4*1024*1024});fs.writeFileSync(path.join(directory,'stdout.log'),result.stdout??'');fs.writeFileSync(path.join(directory,'stderr.log'),result.stderr??'');
 const native=fs.existsSync(report)?JSON.parse(fs.readFileSync(report)):null,text=(result.stdout??'')+'\n'+(result.stderr??'')+'\n'+(fs.existsSync(log)?fs.readFileSync(log,'utf8'):'');
 const success=result.status===0&&!result.error&&native?.success===true&&!/SCRIPT ERROR|ERROR:|leaked|still in use/i.test(text);
 const receipt={name,success,exitCode:result.status,error:result.error?.message??null,native,gpu:false,serverConnections:0};fs.writeFileSync(path.join(directory,'receipt.json'),JSON.stringify(receipt,null,2));results.push(receipt);
 if(!success)break;
}
const changed=pins.filter(pin=>fileHash(path.join(app,pin.relative))!==pin.sha256),changedGuards=engineManifest.guards.filter(guard=>fileHash(guard.path)!==guard.sha256);
const receipt={success:results.length===suites.length&&results.every(result=>result.success)&&!changed.length&&!changedGuards.length,stage,pins,fixtureOverrides,engineDescriptorFile,engineDescriptorSha256:fileHash(engineDescriptorFile),freezeFile,freezeSha256:fileHash(freezeFile),results,changed,changedGuards,gpu:false,serverConnections:0};
fs.writeFileSync(path.join(stage,'receipt.json'),JSON.stringify(receipt,null,2));console.log(JSON.stringify({success:receipt.success,stage,results:results.map(result=>({name:result.name,success:result.success,exitCode:result.exitCode,checks:result.native?.checks,failures:result.native?.failures})),changed,changedGuards},null,2));if(!receipt.success)process.exitCode=1;
