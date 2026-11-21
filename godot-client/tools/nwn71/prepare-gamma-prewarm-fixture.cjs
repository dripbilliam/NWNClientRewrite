'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'.cache/nwn71/gamma-prewarm-a'),project=path.join(out,'project');
assert(!fs.existsSync(out),'Preserve previous fixture');
const files=['systems/native_render/native_gamma_effect.gd','systems/native_render/native_postprocess.gd','systems/native_render/native_light_policy.gd','systems/native_render/native_surface_state.gd','systems/area_environment_state.gd','tests/nwn71/gamma_prewarm_pixels.gd'];
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const sources={};
for(const relative of files){const source=path.join(root,relative),target=path.join(project,relative);fs.mkdirSync(path.dirname(target),{recursive:true});fs.copyFileSync(source,target);sources[relative]=sha(source);assert.equal(sha(target),sources[relative]);}
fs.writeFileSync(path.join(project,'project.godot'),'config_version=5\n\n[application]\nconfig/name="NWN71 Gamma Prewarm Fixture"\n\n[display]\nwindow/size/viewport_width=256\nwindow/size/viewport_height=256\n\n[rendering]\nrenderer/rendering_method="forward_plus"\n', {flag:'wx'});
// The runner selects Forward+ Vulkan explicitly; project defaults remain simple.
const engine=path.join(root,'.tools/Godot_v4.7.2-stable_win64.exe');
const manifest={schema:'nwn71-gamma-prewarm-fixture-v1',project,sourceHashes:sources,engine:{file:engine,sha256:sha(engine)},scope:'Private source clone and authored GPU correctness fixture; no FPS measurement.'};
fs.writeFileSync(path.join(out,'manifest.json'),JSON.stringify(manifest,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({project,manifest:path.join(out,'manifest.json'),engineSha256:manifest.engine.sha256}));
