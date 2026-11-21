'use strict';
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../..');
const parentFile = path.join(root, '.cache/nwn71/incremental-viewport-stages-b/build-plan.json');
const parent = JSON.parse(fs.readFileSync(parentFile, 'utf8'));
const label = process.argv.find(x => x.startsWith('--label='))?.slice(8) ?? 'a';
assert(/^[a-z0-9]+$/.test(label));
const out = path.join(root, `.cache/nwn71/incremental-scene-cull-${label}`);
const relative = 'servers/rendering/renderer_scene_cull.cpp';
const source = path.join(parent.source, relative);
const before = fs.readFileSync(source);
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const hashFile = file => hash(fs.readFileSync(file));
function replaceOnce(input, oldText, newText) {
  const i = input.indexOf(oldText);
  assert(i >= 0 && input.indexOf(oldText, i + oldText.length) < 0, `Missing or ambiguous marker: ${oldText.slice(0, 80)}`);
  return input.slice(0, i) + newText + input.slice(i + oldText.length);
}
assert(!fs.existsSync(out));
for (const pin of [...parent.engineTrackedSources, parent.python, ...parent.protectedInputs, ...parent.headerClosure]) assert.equal(hashFile(pin.file), pin.sha256, pin.file);
for (const pin of parent.profilingPrepopulate) assert.equal(hashFile(pin.reconstructedFile), pin.sha256, pin.reconstructedFile);
for (const change of parent.changes) { assert.equal(hashFile(change.file), change.beforeSha256); assert.equal(hashFile(change.afterFile), change.afterSha256); }
const nl = before.includes(Buffer.from('\r\n')) ? '\r\n' : '\n';
let after = before.toString('utf8');
after = replaceOnce(after,
  `#include "core/object/worker_thread_pool.h"${nl}`,
  `#include "core/object/worker_thread_pool.h"${nl}#include "core/profiling/profiling.h"${nl}`);
function zone(oldText, name, ident) {
  after = replaceOnce(after, oldText, `{${nl}#if defined(GODOT_USE_TRACY)${nl}\tZoneNamedN(${ident}, "NWN71/SceneCull/${name}", true);${nl}#endif${nl}${oldText}${nl}}`);
}
zone('\tRendererSceneOcclusionCull::get_singleton()->buffer_update(p_viewport, camera_data.main_transform, camera_data.main_projection, camera_data.is_orthogonal);', 'occlusion_update', 'nwn71_occlusion_update');
zone('\t_render_scene(&camera_data, p_render_buffers, environment, camera->attributes, compositor, camera->visible_layers, p_scenario, p_viewport, p_shadow_atlas, RID(), -1, p_screen_mesh_lod_threshold, p_window_output_max_value, true, r_render_info);', 'scene_cull_and_render', 'nwn71_scene_cull_and_render');
zone('\tscene_render->render_scene(p_render_buffers, p_camera_data, prev_camera_data, scene_cull_result.geometry_instances, scene_cull_result.light_instances, scene_cull_result.reflections, scene_cull_result.voxel_gi_instances, scene_cull_result.decals, scene_cull_result.lightmaps, scene_cull_result.fog_volumes, p_environment, camera_attributes, p_compositor, p_shadow_atlas, occluders_tex, p_reflection_probe.is_valid() ? RID() : scenario->reflection_atlas, p_reflection_probe, p_reflection_probe_pass, p_screen_mesh_lod_threshold, render_shadow_data, max_shadows_used, render_sdfgi_data, cull.sdfgi.region_count, p_window_output_max_value, &sdfgi_update_data, r_render_info);', 'render_scene_rd', 'nwn71_render_scene_rd');
const afterBytes = Buffer.from(after, 'utf8');
assert.notEqual(hash(before), hash(afterBytes));
const beforeFile = path.join(out, 'before', relative);
const afterFile = path.join(out, 'after', relative);
fs.mkdirSync(path.dirname(beforeFile), {recursive:true});
fs.mkdirSync(path.dirname(afterFile), {recursive:true});
fs.writeFileSync(beforeFile, before, {flag:'wx'});
fs.writeFileSync(afterFile, afterBytes, {flag:'wx'});
const change = {file:source, relative, beforeSha256:hash(before), afterFile, afterSha256:hash(afterBytes)};
const protectedInputs = [...parent.protectedInputs];
for (const name of ['Godot_nwn71_group_labels_win64.exe', 'godot.windows.template_release.x86_64.pdb']) {
  const file=path.join(parent.output,name); protectedInputs.push({file,bytes:fs.statSync(file).size,sha256:hashFile(file)});
}
const plan={...parent,createdUtc:new Date().toISOString(),output:out,parentBuild:{file:parentFile,sha256:hashFile(parentFile)},changes:[...parent.changes,change],protectedInputs,expectedCompiles:[relative],maxSeconds:600,compiled:false,patch:{file:afterFile,sha256:change.afterSha256},scope:'Private Tracy-only SceneCull call sites; exactly one rendering translation unit recompiles. The viewport trace object is reused. No scheduling or accepted-client change.',rollback:'Transaction runner restores source and protects accepted and prior diagnostic binaries by hash.'};
fs.copyFileSync(parent.runner.file,path.join(out,'build-private-diagnostic.ps1'),fs.constants.COPYFILE_EXCL);
const planFile=path.join(out,'build-plan.json');
fs.writeFileSync(planFile,JSON.stringify(plan,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({plan:planFile,sha256:hashFile(planFile),change,expectedCompiles:plan.expectedCompiles}));
