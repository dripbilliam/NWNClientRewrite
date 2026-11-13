'use strict';
// Patch only the isolated private engine clone. No accepted or shared engine
// source, binary or client files are written by this preparation step.
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../..');
const stage = path.join(root, '.cache/nwn71/compositor-callback-a');
const source = path.join(stage, 'source');
const relative = 'servers/rendering/renderer_rd/renderer_scene_render_rd.cpp';
const target = path.join(source, relative);
const old = fs.readFileSync(target);
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const hashFile = file => hash(fs.readFileSync(file));
const original = old.toString('utf8');
assert.equal(hash(old), 'a39eb541966b8afd8a663390f679fb5ac4aa58ad44a6571b159bc581943bfc7c', 'Clone source identity changed');
const nl = original.includes('\r\n') ? '\r\n' : '\n';
function once(input, before, after) {
  assert.equal(input.split(before).length, 2, `Missing or ambiguous marker: ${before.slice(0, 80)}`);
  return input.replace(before, after);
}
let patched = once(original, `#include "renderer_scene_render_rd.h"${nl}`, `#include "renderer_scene_render_rd.h"${nl}#include "core/profiling/profiling.h"${nl}`);
patched = once(patched,
  `void RendererSceneRenderRD::_process_compositor_effects(RSE::CompositorEffectCallbackType p_callback_type, const RenderDataRD *p_render_data) {${nl}`,
  `void RendererSceneRenderRD::_process_compositor_effects(RSE::CompositorEffectCallbackType p_callback_type, const RenderDataRD *p_render_data) {${nl}#if defined(GODOT_USE_TRACY)${nl}\tZoneNamedN(nwn71_compositor_effects, "NWN71/RD/compositor_effects", true);${nl}#endif${nl}`);
const callback = [
  '\t\t{',
  '#if defined(GODOT_USE_TRACY)',
  '\t\t\tZoneNamedN(nwn71_compositor_callback, "NWN71/RD/compositor_callback", true);',
  '\t\t\tif (TracyIsConnected) {',
  '\t\t\t\tconst CharString nwn71_callback_name = String(callback).utf8();',
  '\t\t\t\tZoneTextVF(nwn71_compositor_callback, "type=%d;rid=%llu;callback=%s", int(p_callback_type), (unsigned long long)rid.get_id(), nwn71_callback_name.get_data());',
  '\t\t\t}',
  '#endif',
  '\t\t\tcallback.callv(arr);',
  '\t\t}',
].join(nl);
patched = once(patched, '\t\tcallback.callv(arr);', callback);
const next = Buffer.from(patched, 'utf8');
const beforeFile = path.join(stage, 'before', relative);
const afterFile = path.join(stage, 'after', relative);
assert(!fs.existsSync(beforeFile) && !fs.existsSync(afterFile) && !fs.existsSync(path.join(stage, 'plan.json')), 'Preserve prior private stage');
fs.mkdirSync(path.dirname(beforeFile), {recursive:true});
fs.mkdirSync(path.dirname(afterFile), {recursive:true});
fs.writeFileSync(beforeFile, old, {flag:'wx'});
fs.writeFileSync(afterFile, next, {flag:'wx'});
fs.writeFileSync(target, next);
assert.equal(hashFile(target), hash(next));
const prior = JSON.parse(fs.readFileSync(path.join(root, '.cache/nwn71/incremental-rd-inner-b/build-receipt.json'), 'utf8'));
assert(prior.success && hashFile(prior.binary.file) === prior.binary.sha256, 'Prior diagnostic identity changed');
const python = path.join(root, '.cache/native-140fps/render-agent/engine-build-tools-v1/python/python.exe');
const args = ['-m','SCons','platform=windows','target=template_release','arch=x86_64','use_mingw=no','msvc_version=14.5','disable_path_overrides=no','d3d12=no','debug_symbols=yes','optimize=speed','lto=none','profiler=tracy',`profiler_path=${path.join(root,'.cache/native-tracy/vendor/tracy-0.13.0')}`,'profiler_sample_callstack=no','profiler_track_memory=no','profiler_record_on_demand=yes','-j','2','bin/godot.windows.template_release.x86_64.exe'];
const plan = {
  schema:'nwn71-isolated-compositor-callback-v1',
  source, relative, before:{file:beforeFile,sha256:hash(old)}, after:{file:afterFile,sha256:hash(next)},
  target:{file:target,sha256:hash(next)},
  python:{file:python,sha256:hashFile(python)}, args,
  parentDiagnostic:{file:prior.binary.file,sha256:prior.binary.sha256},
  protectedAccepted:'All output and modified source remain within .cache/nwn71/compositor-callback-a; the shared scratch source and selected engine are not touched.',
  memoryCapBytes:6*1024*1024*1024,minimumFreeBytes:8*1024*1024*1024,
  maximumCompiles:25, maximumSeconds:2400,
  purpose:'Tracy-only exact per-compositor-effect callback identity and elapsed CPU zone; no renderer scheduling or behavior change.',
};
fs.writeFileSync(path.join(stage, 'plan.json'), JSON.stringify(plan,null,2)+'\n', {flag:'wx'});
console.log(JSON.stringify({plan:path.join(stage,'plan.json'), planSha256:hashFile(path.join(stage,'plan.json')), sourceBefore:hash(old), sourceAfter:hash(next), private:true}));
