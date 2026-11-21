import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import {spawnSync} from 'node:child_process';import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),label=process.argv[2]??'palette-upload-check-v1';
if(!/^[a-z0-9-]+$/.test(label))throw Error('Private label required');
const stage=path.join(project,'.cache/native-140fps/render-agent',label);if(fs.existsSync(stage))throw Error('Prior proof preserved');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex'),fileHash=f=>hash(fs.readFileSync(f));
const parentFile=path.join(project,'.cache/native-140fps/root/engine-runtime-ready-v1/manifest.json'),parent=JSON.parse(fs.readFileSync(parentFile));
const sourceFolder=path.join(project,'.cache/native-140fps/render-agent/palette-immutable-upload-v1'),sourceFile=path.join(sourceFolder,'manifest.json'),source=JSON.parse(fs.readFileSync(sourceFile));
const app=path.join(stage,'project'),pins=[];fs.mkdirSync(app,{recursive:true});
for(const pin of parent.pins){const data=fs.readFileSync(path.join(parent.project,pin.relative));if(hash(data)!==pin.sha256)throw Error('Frozen component baseline changed: '+pin.relative);const destination=path.join(app,pin.relative);fs.mkdirSync(path.dirname(destination),{recursive:true});fs.writeFileSync(destination,data);pins.push({...pin});}
function install(relative,data){const destination=path.join(app,relative);fs.mkdirSync(path.dirname(destination),{recursive:true});fs.writeFileSync(destination,data);let pin=pins.find(p=>p.relative===relative);if(!pin){pin={relative};pins.push(pin);}pin.sha256=hash(data);}
if(fileHash(path.join(app,source.relative))!==source.sourceSha256)throw Error('Palette component source cohort differs');
const palette=fs.readFileSync(path.join(sourceFolder,'native_light_palette.candidate.gd'));if(hash(palette)!==source.candidateSha256)throw Error('Frozen palette prototype changed');
install(source.relative,palette);
const entry='tests/native_perf140_render_palette_upload_test.gd';install(entry,fs.readFileSync(path.join(project,entry)));
const gpuEntry='tests/native_perf140_render_palette_upload_gpu_test.gd';
install(gpuEntry,fs.readFileSync(path.join(project,gpuEntry)));
install('tools/perf140/render/native_icon_draw_fence_retained_candidate.gd',fs.readFileSync(path.join(project,'tools/perf140/render/native_icon_draw_fence_retained_candidate.gd')));
install('project.godot',Buffer.from(fs.readFileSync(path.join(app,'project.godot'),'utf8').replace(/\[autoload\][\s\S]*?(?=\n\[|$)/,'')));
const parseOnly=process.argv.includes('--gpu-entry');
fs.writeFileSync(path.join(stage,'manifest.json'),JSON.stringify({version:1,label,project:app,entry:'res://'+(parseOnly?gpuEntry:entry),pins,parentFile,parentSha256:fileHash(parentFile),sourceFile,sourceSha256:fileHash(sourceFile),gpuTests:0,serverConnections:0,scope:'Frozen isolated palette upload fixture; actual GPU execution remains owned by root. Project preserves no_focus; root runner supplies secondary --screen and render thread mode.'},null,2),{flag:'wx'});
const engine=path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe'),log=path.join(stage,'engine.log'),report=path.join(stage,'native.json'),args=['--headless','--path',app,'--log-file',log,...(parseOnly?['--check-only']:[]),'--script','res://'+(parseOnly?gpuEntry:entry),...(parseOnly?[]:['--','--report='+report])];
fs.writeFileSync(path.join(stage,'invocation.json'),JSON.stringify({engine,engineSha256:fileHash(engine),args,pins,parentFile,parentSha256:fileHash(parentFile),sourceFile,sourceSha256:fileHash(sourceFile),gpu:false,serverConnections:0},null,2));
const result=spawnSync(engine,args,{windowsHide:true,encoding:'utf8',timeout:30000,maxBuffer:2*1024*1024});fs.writeFileSync(path.join(stage,'stdout.log'),result.stdout??'');fs.writeFileSync(path.join(stage,'stderr.log'),result.stderr??'');
const all=(result.stdout??'')+'\n'+(result.stderr??'')+'\n'+(fs.existsSync(log)?fs.readFileSync(log,'utf8'):''),native=fs.existsSync(report)?JSON.parse(fs.readFileSync(report)):null;
const changed=pins.filter(pin=>fileHash(path.join(app,pin.relative))!==pin.sha256);
const receipt={success:result.status===0&&!result.error&&(parseOnly||native?.success===true)&&!/SCRIPT ERROR|ERROR:|leaked|still in use/i.test(all)&&!changed.length,exitCode:result.status,error:result.error?.message??null,native,changed,parseOnly,gpu:false,serverConnections:0,stage};
fs.writeFileSync(path.join(stage,'receipt.json'),JSON.stringify(receipt,null,2));console.log(JSON.stringify(receipt,null,2));if(!receipt.success)process.exitCode=1;
