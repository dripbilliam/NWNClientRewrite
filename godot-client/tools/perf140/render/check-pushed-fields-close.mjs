import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import {spawnSync} from 'node:child_process';import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),label=process.argv[2];
if(!/^[a-z0-9-]+$/.test(label??''))throw Error('Fresh private label required');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex'),fileHash=f=>hash(fs.readFileSync(f));
const base=path.join(project,'.cache/native-140fps/render-agent'),stage=path.join(base,label);if(fs.existsSync(stage))throw Error('Preserve earlier edge proof');
const descriptorFile=path.join(base,'engine-pushed-fields-v4/engine-descriptor.json'),descriptor=JSON.parse(fs.readFileSync(descriptorFile)),engine=descriptor.engines.candidate;
if(fileHash(engine.path)!==engine.sha256)throw Error('Archived V4 engine changed');
const engineManifest=JSON.parse(fs.readFileSync(descriptor.sourceManifest));for(const guard of engineManifest.guards)if(fileHash(guard.path)!==guard.sha256)throw Error('Retained/shared guard changed');
const freezeFile=path.join(base,'pushed-fields-source-v4/manifest.json'),freeze=JSON.parse(fs.readFileSync(freezeFile)),parent=JSON.parse(fs.readFileSync(freeze.parentFile));if(fileHash(freeze.parentFile)!==freeze.parentSha256)throw Error('Frozen runtime parent drift');
const app=path.join(stage,'project'),pins=[];fs.mkdirSync(app,{recursive:true});
function install(relative,bytes){const target=path.join(app,relative);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,bytes);let pin=pins.find(p=>p.relative===relative);if(!pin){pin={relative};pins.push(pin);}pin.sha256=hash(bytes);}
for(const pin of parent.pins){const bytes=fs.readFileSync(path.join(parent.project,pin.relative));if(hash(bytes)!==pin.sha256)throw Error('Frozen parent source drift '+pin.relative);install(pin.relative,bytes);}
for(const fixture of freeze.fixtures){const bytes=fs.readFileSync(fixture.file);if(hash(bytes)!==fixture.sha256)throw Error('Frozen V4 source drift '+fixture.relative);install(fixture.relative,bytes);}
const relative='systems/native_render/focus_lighting_native_input_candidate.gd',original=fs.readFileSync(path.join(app,relative),'utf8');
const before='func close() -> void:\n\tsuper.close()\n\tif input_registry!=null:input_registry.call("dispatch",8,{});input_registry=null';
const normalized=original.replaceAll('\r\n','\n');if(normalized.split(before).length!==2)throw Error('Exact V4 close boundary changed');
const after='func close() -> void:\n\t# Retire our canonical publication capabilities before BaseFocus discards\n\t# membership. A caller may retain the registry through a nested writer.\n\tfor entry in members.values():\n\t\tvar light=entry.light.get_ref() if entry.light!=null else null\n\t\tif not is_instance_valid(light) or light.get_script()!=CanonicalLight:continue\n\t\tvar binding:WeakRef=light._native_input_registry\n\t\tif binding!=null and binding.get_ref()==input_registry:light.bind_native_input_registry(null)\n\tsuper.close()\n\tif input_registry!=null:input_registry.call("dispatch",8,{});input_registry=null';
const fixed=normalized.replace(before,after);fs.writeFileSync(path.join(stage,'original-adapter.gd'),original);fs.writeFileSync(path.join(stage,'corrected-adapter.gd'),fixed);
const fixtureRelative='tests/native_perf140_render_pushed_fields_close_test.gd';install(fixtureRelative,fs.readFileSync(path.join(project,fixtureRelative)));
install('project.godot',Buffer.from(fs.readFileSync(path.join(app,'project.godot'),'utf8').replace(/\[autoload\][\s\S]*?(?=\n\[|$)/,'')));
const results=[];
for(const role of ['negative-v4','candidate-close']){
 install(relative,Buffer.from(role==='negative-v4'?original:fixed));
 const dir=path.join(stage,role);fs.mkdirSync(dir);const report=path.join(dir,'native.json'),log=path.join(dir,'engine.log');
 const args=['--headless','--path',app,'--log-file',log,'--script','res://'+fixtureRelative,'--','--report='+report,'--light-input-registry=builtin','--light-input-fields=published'];
 fs.writeFileSync(path.join(dir,'invocation.json'),JSON.stringify({engine,args,gpu:false,serverConnections:0},null,2));
 const run=spawnSync(engine.path,args,{windowsHide:true,encoding:'utf8',timeout:30000,maxBuffer:2*1024*1024});fs.writeFileSync(path.join(dir,'stdout.log'),run.stdout??'');fs.writeFileSync(path.join(dir,'stderr.log'),run.stderr??'');
 const native=fs.existsSync(report)?JSON.parse(fs.readFileSync(report)):null,text=[run.stdout,run.stderr,fs.existsSync(log)?fs.readFileSync(log,'utf8'):''].join('\n');
 const clean=run.status===0&&!run.error&&native?.success===true&&!/SCRIPT ERROR|ERROR:|leaked|still in use/i.test(text);
 const result={role,success:clean,exitCode:run.status,error:run.error?.message??null,native,expectedNegative:role==='negative-v4'};results.push(result);
 if(role==='negative-v4'&&(clean||!native))break;
}
install(relative,Buffer.from(fixed));
const changed=pins.filter(pin=>fileHash(path.join(app,pin.relative))!==pin.sha256),changedGuards=engineManifest.guards.filter(guard=>fileHash(guard.path)!==guard.sha256);
const manifest={version:1,label,project:app,entry:'res://'+fixtureRelative,pins,descriptorFile,descriptorSha256:fileHash(descriptorFile),freezeFile,freezeSha256:fileHash(freezeFile),originalAdapterSha256:hash(Buffer.from(original)),correctedAdapterSha256:hash(Buffer.from(fixed)),changeScope:'GDS-only canonical capability unbind before existing close, no engine or Point writer edits',gpuTests:0,serverConnections:0};
fs.writeFileSync(path.join(stage,'manifest.json'),JSON.stringify(manifest,null,2),{flag:'wx'});
const receipt={success:results.length===2&&!results[0].success&&results[0].native!=null&&results[1].success&&!changed.length&&!changedGuards.length,stage,results,manifestSha256:fileHash(path.join(stage,'manifest.json')),changed,changedGuards,gpu:false,serverConnections:0};
fs.writeFileSync(path.join(stage,'receipt.json'),JSON.stringify(receipt,null,2));console.log(JSON.stringify(receipt,null,2));if(!receipt.success)process.exitCode=1;
