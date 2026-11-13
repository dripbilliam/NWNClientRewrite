import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import {spawnSync} from 'node:child_process';import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),label=process.argv[2];
if(!/^[a-z0-9-]+$/.test(label??''))throw Error('Fresh private label required');
const base=path.join(project,'.cache/native-140fps/render-agent'),stage=path.join(base,label);if(fs.existsSync(stage))throw Error('Preserve previous result');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex'),fileHash=f=>hash(fs.readFileSync(f));
const sourceGuardV5=process.argv.includes('--source-guard-v5'),v5Baseline=process.argv.includes('--v5-baseline');
if(v5Baseline&&!sourceGuardV5)throw Error('V5 baseline requires explicit V5 cohort');
const descriptorFile=path.join(base,sourceGuardV5?'engine-pushed-source-guard-v5/engine-descriptor.json':'engine-pushed-fields-v4/engine-descriptor.json'),descriptor=JSON.parse(fs.readFileSync(descriptorFile)),engine=descriptor.engines[v5Baseline?'baseline':'candidate'];
if(fileHash(engine.path)!==engine.sha256)throw Error('Archived V4 engine changed');
const engineManifest=JSON.parse(fs.readFileSync(descriptor.sourceManifest));for(const guard of engineManifest.guards)if(fileHash(guard.path)!==guard.sha256)throw Error('Retained/shared guard changed');
const freezeFile=path.join(base,'pushed-fields-source-v4/manifest.json'),freeze=JSON.parse(fs.readFileSync(freezeFile));
const parent=JSON.parse(fs.readFileSync(freeze.parentFile));if(fileHash(freeze.parentFile)!==freeze.parentSha256)throw Error('Runtime baseline changed');
const app=path.join(stage,'project'),pins=[];fs.mkdirSync(app,{recursive:true});
for(const pin of parent.pins){const b=fs.readFileSync(path.join(parent.project,pin.relative));if(hash(b)!==pin.sha256)throw Error('Frozen parent source drift '+pin.relative);const target=path.join(app,pin.relative);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,b);pins.push({...pin});}
function install(relative,bytes){const target=path.join(app,relative);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,bytes);let pin=pins.find(p=>p.relative===relative);if(!pin){pin={relative};pins.push(pin);}pin.sha256=hash(bytes);}
for(const fixture of freeze.fixtures){const b=fs.readFileSync(fixture.file);if(hash(b)!==fixture.sha256)throw Error('Frozen V4 source drift '+fixture.relative);install(fixture.relative,b);}
const fixtureOverrides=[];
if(process.argv.includes('--close-successor')){
 const relative='systems/native_render/focus_lighting_native_input_candidate.gd',directory=path.join(base,'pushed-fields-close-check-v1');
 const manifest=JSON.parse(fs.readFileSync(path.join(directory,'manifest.json'))),before=fs.readFileSync(path.join(app,relative)),after=fs.readFileSync(path.join(directory,'corrected-adapter.gd'));
 if(hash(before)!==manifest.originalAdapterSha256||hash(after)!==manifest.correctedAdapterSha256)throw Error('Frozen close successor cohort drift');
 install(relative,after);fixtureOverrides.push({relative,sha256:hash(after),scope:'GDS-only canonical capability unbind before inherited close; V4 engine/Point unchanged'});
}
if(process.argv.includes('--current-v4-fixture')){const relative='tests/native_perf140_render_pushed_fields_v4_test.gd',b=fs.readFileSync(path.join(project,relative));install(relative,b);fixtureOverrides.push({relative,sha256:hash(b),scope:'Explicit additional same-Script detach/reattach and replacement oracle on unchanged frozen module'});}
if(sourceGuardV5){
 const v5FreezeFile=path.join(base,'pushed-source-guard-v5/manifest.json'),v5Freeze=JSON.parse(fs.readFileSync(v5FreezeFile));
 for(const fixture of v5Freeze.fixtures){const bytes=fs.readFileSync(fixture.file);if(hash(bytes)!==fixture.sha256)throw Error('V5 frozen fixture drift');install(fixture.relative,bytes);fixtureOverrides.push({relative:fixture.relative,sha256:fixture.sha256,scope:'Exact V5 real COW-source replacement/close boundary fixture'});}
}
const full='tests/native_light_input_registry_test.gd';let fullSource=fs.readFileSync(path.join(project,full),'utf8');
const before='Focus=load("res://systems/native_render/focus_lighting_native_input_candidate.gd")',after='Focus=load("res://systems/native_render/focus_lighting_builtin_input_candidate.gd")';if(fullSource.split(before).length!==2)throw Error('Full Focus fixture boundary changed');fullSource=fullSource.replace(before,after);install(full,Buffer.from(fullSource));
const baseline=path.join(app,'systems/native_render/focus_lighting.gd'),baselineHash=/const BASELINE_SHA="([a-f0-9]{64})"/.exec(fullSource)?.[1];if(fileHash(baseline)!==baselineHash)throw Error('Exact original Focus oracle mismatch');
const config='project.godot';install(config,Buffer.from(fs.readFileSync(path.join(app,config),'utf8').replace(/\[autoload\][\s\S]*?(?=\n\[|$)/,'')));
const adapterRelative='systems/native_render/focus_lighting_builtin_input_candidate.gd',fixedAdapter=fs.readFileSync(path.join(app,adapterRelative));
const negativeFile=path.join(base,'builtin-light-constructor-v2/failed-adapter.gd'),negativeAdapter=fs.readFileSync(negativeFile);if(hash(negativeAdapter)!=='06eb0d83b1b8c2f9b6d360b0bd0dd36b78a71d71ecf611b5a6fa96559dbe5807')throw Error('Frozen negative constructor changed');
let suite=[
 ['direct','tests/native_perf140_render_builtin_light_registry_test.gd',[]],
 ['focus-builtin',full,['--baseline='+baseline,'--light-input-registry=builtin']],
 ['focus-published',full,['--baseline='+baseline,'--light-input-registry=builtin','--light-input-fields=published']],
 ['focus-extension',full,['--baseline='+baseline]],
 ['constructor-negative','tests/native_perf140_render_builtin_light_constructor_test.gd',['--expect-missing-registry']],
 ['constructor-extension','tests/native_perf140_render_builtin_light_constructor_test.gd',[]],
 ['constructor-builtin','tests/native_perf140_render_builtin_light_constructor_test.gd',['--light-input-registry=builtin','--light-input-fields=published']],
 ['published-fields','tests/native_perf140_render_pushed_fields_v4_test.gd',['--light-input-registry=builtin','--light-input-fields=published']],
];
if(sourceGuardV5){const extra=[['source-cow-guard','tests/native_perf140_render_pushed_fields_v5_test.gd',['--light-input-registry=builtin','--light-input-fields=published']],['close-writer','tests/native_perf140_render_pushed_fields_close_test.gd',['--light-input-registry=builtin','--light-input-fields=published']]];suite=v5Baseline?extra:[...suite,...extra];}
const results=[];
for(const [name,entry,extra]of suite){
 install(adapterRelative,name==='constructor-negative'?negativeAdapter:fixedAdapter);
 const directory=path.join(stage,name);fs.mkdirSync(directory);const report=path.join(directory,'native.json'),log=path.join(directory,'engine.log');
 const args=['--headless','--path',app,'--log-file',log,'--script','res://'+entry,'--','--report='+report,...extra];
 fs.writeFileSync(path.join(directory,'invocation.json'),JSON.stringify({engine,entry,args,gpu:false,serverConnections:0},null,2));
 const run=spawnSync(engine.path,args,{windowsHide:true,encoding:'utf8',timeout:45000,maxBuffer:4*1024*1024});
 fs.writeFileSync(path.join(directory,'stdout.log'),run.stdout??'');fs.writeFileSync(path.join(directory,'stderr.log'),run.stderr??'');
 const native=fs.existsSync(report)?JSON.parse(fs.readFileSync(report)):null,text=[run.stdout,run.stderr,fs.existsSync(log)?fs.readFileSync(log,'utf8'):''].join('\n');
 const result={name,success:run.status===0&&!run.error&&native?.success===true&&!/SCRIPT ERROR|ERROR:|leaked|still in use/i.test(text),exitCode:run.status,error:run.error?.message??null,native};
 fs.writeFileSync(path.join(directory,'receipt.json'),JSON.stringify(result,null,2));results.push(result);if(!result.success)break;
}
install(adapterRelative,fixedAdapter);
const changed=pins.filter(pin=>fileHash(path.join(app,pin.relative))!==pin.sha256),changedGuards=engineManifest.guards.filter(guard=>fileHash(guard.path)!==guard.sha256);
const receipt={success:results.length===suite.length&&results.every(r=>r.success)&&!changed.length&&!changedGuards.length,stage,engine,descriptorFile,descriptorSha256:fileHash(descriptorFile),freezeFile,freezeSha256:fileHash(freezeFile),parentFile:freeze.parentFile,parentSha256:freeze.parentSha256,pins,fixtureOverrides,results,changed,changedGuards,gpu:false,serverConnections:0};
fs.writeFileSync(path.join(stage,'receipt.json'),JSON.stringify(receipt,null,2));console.log(JSON.stringify({success:receipt.success,stage,results:results.map(r=>({name:r.name,success:r.success,exitCode:r.exitCode,checks:r.native?.checks,failures:r.native?.failures})),changed,changedGuards},null,2));if(!receipt.success)process.exitCode=1;
