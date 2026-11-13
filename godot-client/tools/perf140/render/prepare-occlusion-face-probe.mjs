import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const label=process.argv[2]??'occlusion-faces-v1';
if(!/^[a-z0-9-]+$/.test(label))throw Error('Private label required');
const stage=path.join(project,'.cache/native-140fps/render-agent',label);
if(fs.existsSync(stage))throw Error('Existing capsule preserved');
const app=path.join(stage,'project');fs.mkdirSync(app,{recursive:true});
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const pins=[];
function write(relative,bytes){const target=path.join(app,relative);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,bytes);pins.push({relative,sha256:hash(bytes)});}
for(const relative of ['tools/perf140/render/native_icon_draw_fence_retained_candidate.gd','tests/native_perf140_render_occlusion_faces_gpu_test.gd'])write(relative,fs.readFileSync(path.join(project,relative)));
write('project.godot',Buffer.from('config_version=5\n[application]\nconfig/name="Private opaque occlusion face diagnostic"\n[display]\nwindow/size/viewport_width=320\nwindow/size/viewport_height=240\nwindow/size/no_focus=true\nwindow/vsync/vsync_mode=0\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n'));
// Root explicitly overrides renderer to Forward+ for graphical execution. The
// serialized setting remains Compatibility so check-only never creates a GPU.
write('.godot/global_script_class_cache.cfg',Buffer.from('list=Array[Dictionary]([])\n'));
const receipt={version:1,label,project:app,entry:'res://tests/native_perf140_render_occlusion_faces_gpu_test.gd',pins,engineStarts:0,serverConnections:0,scope:'Front/back opaque-wall occlusion diagnostic only. Explicit --rendering-method forward_plus is required for the compositor GPU test; use --headless --check-only for parse.'};
fs.writeFileSync(path.join(stage,'manifest.json'),JSON.stringify(receipt,null,2),{flag:'wx'});
console.log(JSON.stringify({stage,project:app,entry:receipt.entry,pins:pins.length,engineStarts:0}));
