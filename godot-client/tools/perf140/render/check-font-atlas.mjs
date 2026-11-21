import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import {spawnSync} from 'node:child_process';import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),label=process.argv[2];
if(!/^[a-z0-9-]+$/.test(label??''))throw Error('Fresh private label required');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex'),fileHash=f=>hash(fs.readFileSync(f));
const base=path.join(project,'.cache/native-140fps/render-agent'),stage=path.join(base,label);if(fs.existsSync(stage))throw Error('Previous proof retained');
const descriptorFile=path.join(base,'engine-font-atlas-v1/engine-descriptor.json'),descriptor=JSON.parse(fs.readFileSync(descriptorFile));
const sourceManifest=JSON.parse(fs.readFileSync(descriptor.sourceManifest));for(const guard of sourceManifest.guards)if(fileHash(guard.path)!==guard.sha256)throw Error('Shared/retained guard changed');
const app=path.join(stage,'project'),pins=[];fs.mkdirSync(app,{recursive:true});
function install(relative,data){const destination=path.join(app,relative);fs.mkdirSync(path.dirname(destination),{recursive:true});fs.writeFileSync(destination,data);pins.push({relative,sha256:hash(data)});}
install('project.godot',Buffer.from('[application]\nconfig/name="Font atlas upload ownership fixture"\nconfig/features=PackedStringArray("4.7", "Forward Plus")\n[display]\nwindow/size/viewport_width=320\nwindow/size/viewport_height=240\nwindow/size/window_width_override=320\nwindow/size/window_height_override=240\nwindow/size/no_focus=true\n[rendering]\nrenderer/rendering_method="forward_plus"\nrenderer/rendering_method.mobile="forward_plus"\n'));
install('.godot/global_script_class_cache.cfg',Buffer.from('list=[]\n'));
for(const relative of ['tests/native_perf140_render_font_atlas_test.gd','tests/native_perf140_render_font_atlas_gpu_test.gd','tools/perf140/render/native_icon_draw_fence_retained_candidate.gd'])install(relative,fs.readFileSync(path.join(project,relative)));
const fontSource='C:/Windows/Fonts/arial.ttf';install('fixture-font.ttf',fs.readFileSync(fontSource));
const manifest={version:1,label,project:app,entry:'res://tests/native_perf140_render_font_atlas_gpu_test.gd',pins,descriptorFile,descriptorSha256:fileHash(descriptorFile),fontSource,fontSha256:fileHash(fontSource),gpuTests:0,serverConnections:0,scope:'Isolated no-extension actual TextServerAdvanced font fixture. GPU entry is root-owned; no_focus and secondary --screen supported. Headless update backend is no-op, so queued pixels are not headless acceptance.'};
fs.writeFileSync(path.join(stage,'manifest.json'),JSON.stringify(manifest,null,2),{flag:'wx'});
const results=[];
for(const role of ['baseline','candidate']){
 const engine=descriptor.engines[role];if(fileHash(engine.path)!==engine.sha256)throw Error('Archived engine drift');
 const dir=path.join(stage,role);fs.mkdirSync(dir);const report=path.join(dir,'native.json'),log=path.join(dir,'engine.log');
 const args=['--headless','--path',app,'--log-file',log,'--script','res://tests/native_perf140_render_font_atlas_test.gd','--','--report='+report];
 fs.writeFileSync(path.join(dir,'invocation.json'),JSON.stringify({engine,args,gpu:false,serverConnections:0},null,2));
 const run=spawnSync(engine.path,args,{windowsHide:true,encoding:'utf8',timeout:30000,maxBuffer:2*1024*1024});fs.writeFileSync(path.join(dir,'stdout.log'),run.stdout??'');fs.writeFileSync(path.join(dir,'stderr.log'),run.stderr??'');
 const native=fs.existsSync(report)?JSON.parse(fs.readFileSync(report)):null,text=[run.stdout,run.stderr,fs.existsSync(log)?fs.readFileSync(log,'utf8'):''].join('\n');
 const result={role,success:run.status===0&&!run.error&&native?.success===true&&!/SCRIPT ERROR|ERROR:|leaked|still in use/i.test(text),exitCode:run.status,error:run.error?.message??null,native};results.push(result);if(!result.success)break;
}
const parseLog=path.join(stage,'gpu-parse.log'),parse=spawnSync(descriptor.engines.candidate.path,['--headless','--path',app,'--log-file',parseLog,'--check-only','--script',manifest.entry],{windowsHide:true,encoding:'utf8',timeout:30000,maxBuffer:2*1024*1024});
const parseText=[parse.stdout,parse.stderr,fs.existsSync(parseLog)?fs.readFileSync(parseLog,'utf8'):''].join('\n');fs.writeFileSync(path.join(stage,'gpu-parse-stdout.log'),parse.stdout??'');fs.writeFileSync(path.join(stage,'gpu-parse-stderr.log'),parse.stderr??'');
const parsed=parse.status===0&&!parse.error&&!/SCRIPT ERROR|ERROR:|leaked|still in use/i.test(parseText),changed=pins.filter(pin=>fileHash(path.join(app,pin.relative))!==pin.sha256),changedGuards=sourceManifest.guards.filter(guard=>fileHash(guard.path)!==guard.sha256);
const receipt={success:results.length===2&&results.every(r=>r.success)&&parsed&&!changed.length&&!changedGuards.length,results,parsed,parseExit:parse.status,stage,manifestSha256:fileHash(path.join(stage,'manifest.json')),changed,changedGuards,gpu:false,serverConnections:0};
fs.writeFileSync(path.join(stage,'receipt.json'),JSON.stringify(receipt,null,2));console.log(JSON.stringify(receipt,null,2));if(!receipt.success)process.exitCode=1;
