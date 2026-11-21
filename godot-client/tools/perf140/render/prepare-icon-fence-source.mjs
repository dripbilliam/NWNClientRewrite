import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const id=process.argv[2]??'icon-draw-fence-source-v1';
if(!/^[a-z0-9-]+$/.test(id))throw Error('Fresh private source label required');
const stage=path.join(project,'.cache/native-140fps/render-agent',id);
const retainedArm=process.argv.includes('--retain-arm');
if(fs.existsSync(stage))throw Error('Existing source experiment preserved');
fs.mkdirSync(stage,{recursive:true});
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const source=path.join(project,'.cache/native-140fps/root/engine-runtime-ready-v1/project/systems/native_item_icons.gd');
const original=fs.readFileSync(source);let code=original.toString('utf8');
function replace(from,to){if(code.split(from).length!==2)throw Error('Pinned icon boundary changed: '+from);code=code.replace(from,to);}
replace('var pending_draw: Dictionary={}',`var pending_draw: Dictionary={}
var render_fence: CompositorEffect
var render_fence_compositor: Compositor
var render_epoch := 0`);
replace('\tstage=Node3D.new(); viewport.add_child(stage); camera=Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.keep_aspect=Camera3D.KEEP_HEIGHT; camera.near=0.1; camera.far=200; stage.add_child(camera); camera.current=true',`\tstage=Node3D.new(); viewport.add_child(stage); camera=Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.keep_aspect=Camera3D.KEEP_HEIGHT; camera.near=0.1; camera.far=200; stage.add_child(camera); camera.current=true
\t# Compositor callbacks are supported only by RD renderers. Keep the old
\t# non-RD/headless path; this experiment changes only the native Vulkan path.
\tif DisplayServer.get_name() != "headless" and RenderingServer.get_current_rendering_method() in ["forward_plus", "mobile"]:
\t\trender_fence = preload("res://systems/native_render/icon_draw_fence.gd").new(Callable(self, "icon_viewport_drawn"))
\t\trender_fence_compositor = Compositor.new()
\t\trender_fence_compositor.compositor_effects = [render_fence]
\t\tcamera.compositor = render_fence_compositor`);
replace('\tpending_draw={"job":job,"model":model,"wait_began":Timing.begin()}\n\tRenderingServer.frame_post_draw.connect(frame_rendered,CONNECT_ONE_SHOT)',`\tpending_draw={"job":job,"model":model,"wait_began":Timing.begin()}
\tif render_fence != null:
\t\trender_epoch += 1
\t\tpending_draw.render_epoch = render_epoch
\t\tpending_draw.completed_epoch = 0
\t\tRenderingServer.call_on_render_thread(Callable(render_fence, "arm").bind(render_epoch))
\telse:
\t\tRenderingServer.frame_post_draw.connect(frame_rendered,CONNECT_ONE_SHOT)
func icon_viewport_drawn(epoch: int) -> void:
\t# Main-thread deferred receiver. Old/retired/replaced camera completions
\t# cannot consume another request, including after owner closure.
\tif closed or pending_draw.is_empty() or int(pending_draw.get("render_epoch", -1)) != epoch:
\t\treturn
\tpending_draw.completed_epoch = epoch
\tframe_rendered()`);
replace('\tif closed or pending_draw.is_empty(): return\n\tvar draw: Dictionary=pending_draw; pending_draw={}',`\tif closed or pending_draw.is_empty(): return
\tif render_fence != null and int(pending_draw.get("completed_epoch", 0)) != int(pending_draw.get("render_epoch", -1)):
\t\treturn
\tvar draw: Dictionary=pending_draw; pending_draw={}`);
replace('\tclosed=true\n\tif RenderingServer.frame_post_draw.is_connected(frame_rendered):',`\tclosed=true
\tif is_instance_valid(camera): camera.compositor = null
\trender_fence = null
\trender_fence_compositor = null
\tif RenderingServer.frame_post_draw.is_connected(frame_rendered):`);
if(retainedArm)replace('Callable(render_fence, "arm").bind(render_epoch)','Callable(render_fence, "arm").bind(render_epoch, render_fence)');
const fenceSource=path.join(project,'tools/perf140/render',retainedArm?'native_icon_draw_fence_retained_candidate.gd':'native_icon_draw_fence_candidate.gd'),fence=fs.readFileSync(fenceSource);
for(const [relative,bytes]of [['native_item_icons.pristine.gd',original],['native_item_icons.candidate.gd',Buffer.from(code)],['icon_draw_fence.gd',fence]])fs.writeFileSync(path.join(stage,relative),bytes,{flag:'wx'});
const receipt={version:1,id,stage,retainedArm,source,sourceSha256:hash(original),candidateSha256:hash(code),fenceSource,fenceSha256:hash(fence),changedFunctions:['configure','draw_icon','frame_rendered','close'],newMainReceiver:'icon_viewport_drawn',renderThreadOnlyFields:['armed_epoch','published_epoch'],immutableRenderCallback:'completed',gpu:false,builds:0,enginesStarted:0,scope:'Private queued render epoch plus actual per-camera POST_TRANSPARENT completion. No stale global postdraw readback. No shared files changed. This fresh source variant requires its own lifetime/GPU acceptance.'};
fs.writeFileSync(path.join(stage,'manifest.json'),JSON.stringify(receipt,null,2),{flag:'wx'});console.log(JSON.stringify(receipt,null,2));
