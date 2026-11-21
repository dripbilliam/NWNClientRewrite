import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const [id='icon-draw-fence-project-v1',sourceId='icon-draw-fence-source-v2']=process.argv.slice(2);
if(![id,sourceId].every(v=>/^[a-z0-9-]+$/.test(v)))throw Error('Private labels required');
const stage=path.join(project,'.cache/native-140fps/render-agent',id);if(fs.existsSync(stage))throw Error('Existing capsule preserved');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const parentFile=path.join(project,'.cache/native-140fps/root/engine-runtime-ready-v1/manifest.json'),parent=JSON.parse(fs.readFileSync(parentFile));
const sourceFolder=path.join(project,'.cache/native-140fps/render-agent',sourceId),sourceFile=path.join(sourceFolder,'manifest.json'),source=JSON.parse(fs.readFileSync(sourceFile));
const destination=path.join(stage,'project'),pins=parent.pins.map(pin=>({...pin})),edits=[];fs.mkdirSync(destination,{recursive:true});
for(const pin of pins){const bytes=fs.readFileSync(path.join(parent.project,pin.relative));if(hash(bytes)!==pin.sha256)throw Error('Frozen UI baseline changed: '+pin.relative);const target=path.join(destination,pin.relative);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,bytes);}
function install(relative,bytes){const file=path.join(destination,relative);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,bytes);let pin=pins.find(pin=>pin.relative===relative);if(!pin){pin={relative};pins.push(pin);}pin.sha256=hash(bytes);edits.push(relative);}
const icon=fs.readFileSync(path.join(sourceFolder,'native_item_icons.candidate.gd')),fence=fs.readFileSync(path.join(sourceFolder,'icon_draw_fence.gd'));
if(hash(icon)!==source.candidateSha256||hash(fence)!==source.fenceSha256)throw Error('Private source prototype drifted');
install('systems/native_item_icons.gd',icon);install('systems/native_render/icon_draw_fence.gd',fence);
const test='tests/native_perf140_render_icon_fence_lifetime_test.gd';install(test,fs.readFileSync(path.join(project,test)));
const gpuTest='tests/native_perf140_render_icon_fence_gpu_test.gd';if(fs.existsSync(path.join(project,gpuTest)))install(gpuTest,fs.readFileSync(path.join(project,gpuTest)));
install('project.godot',fs.readFileSync(path.join(destination,'project.godot'),'utf8').replace(/\[autoload\][\s\S]*?(?=\n\[|$)/,''));
const receipt={version:1,id,project:destination,pins,inputs:[{file:parentFile,sha256:hash(fs.readFileSync(parentFile))},{file:sourceFile,sha256:hash(fs.readFileSync(sourceFile))}],edits,gpu:false,engineStarts:0,scope:'Old-kernel UI baseline with private per-camera draw fence. No native rebuild or shared changes; component capsule excludes application autoloads.'};
fs.writeFileSync(path.join(stage,'manifest.json'),JSON.stringify(receipt,null,2),{flag:'wx'});console.log(JSON.stringify({stage,pins:pins.length,edits,engineStarts:0}));
