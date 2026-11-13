'use strict';
// Read-only, source-pinned census of the existing dense-scene replay. No client launch.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');

const root = path.resolve(__dirname, '../..');
const pins = {
  'reports/nwn74-forward-census-d.performance.jsonl': '77884899f548d24b237611f08ebb639b25731fe007994ef88ce869babe0fd9c4',
  '.cache/native-tracy/engine-msvc-a/source/servers/rendering/renderer_scene_cull.cpp': '394acdb359c229239c5b4f12b2e5d7055a972bff1402646eac33ef012bd4355d',
  '.cache/native-tracy/engine-msvc-a/source/servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp': 'fe8b102c6742d12f8a51a7312bfa8b72596277ee7d2f429fce5c97d6e03846dd',
  '.cache/native-tracy/engine-msvc-a/source/servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.h': '173db11744b7cf8cfac758d93d5f024b4275e38ccb662d3d4389845e3b0acf0a',
  '.cache/native-tracy/engine-msvc-a/source/servers/rendering/rendering_device.cpp': 'cb319128c2650189dc3ebff5aad7e70ac73b0bd4c4d0c58993f06d4d002ddc62',
  '.cache/native-tracy/engine-msvc-a/source/servers/rendering/rendering_device_driver.cpp': 'e33892c5c721d008dd277e19848dce62bec84754d99bf3ea342df0939fa41f91',
  '.cache/native-tracy/engine-msvc-a/source/drivers/vulkan/rendering_device_driver_vulkan.cpp': '7e97f993d3467254c0766b9cf8c7533398dd65c932c1794f2cd85a99f6751d15',
};
const sha256 = b => crypto.createHash('sha256').update(b).digest('hex');
const source = {};
for (const [name, pin] of Object.entries(pins)) {
  const data = fs.readFileSync(path.join(root, name));
  assert.equal(sha256(data), pin, `Source/capture changed: ${name}`);
  source[name] = data.toString();
}
const cull = source[Object.keys(pins).find(x => x.endsWith('/renderer_scene_cull.cpp'))];
const forward = source[Object.keys(pins).find(x => x.endsWith('/render_forward_clustered.cpp'))];
const header = source[Object.keys(pins).find(x => x.endsWith('/render_forward_clustered.h'))];
const rd = source[Object.keys(pins).find(x => x.endsWith('/rendering_device.cpp'))];
const driver = source[Object.keys(pins).find(x => x.endsWith('/rendering_device_driver.cpp'))];
const vulkan = source[Object.keys(pins).find(x => x.endsWith('/rendering_device_driver_vulkan.cpp'))];
assert(cull.includes('NwnFrameMetrics::Scope nwn74_geometry_cull(NwnFrameMetrics::GEOMETRY_CULL_US)'));
assert(cull.includes('NwnFrameMetrics::Scope nwn74_shadow_prep(NwnFrameMetrics::SHADOW_PREP_US)'));
assert(cull.includes('if (scenario->instance_visibility.get_bin_count() > 0)'));
assert(cull.includes('NwnFrameMetrics::add(NwnFrameMetrics::SCENE_SHADOW_COUNT, max_shadows_used)'));
assert(forward.includes('push_constant.base_index = i + p_params->element_offset'));
assert(forward.includes('RD::get_singleton()->draw_list_set_push_constant(draw_list, &push_constant, push_constant_size)'));
assert(forward.includes('RD::get_singleton()->draw_list_draw(draw_list, index_array_rd.is_valid(), instance_count)'));
assert(header.includes('MATERIAL_UNIFORM_SET = 3'));
const draw = rd.split('void RenderingDevice::draw_list_draw(')[1].split('void RenderingDevice::draw_list_draw_indirect(')[0];
assert(draw.includes('for (uint32_t i = 0; i < draw_list.state.set_count; i++)'));
assert(draw.includes('driver->api_trait_get(RDD::API_TRAIT_HONORS_PIPELINE_BARRIERS)'));
assert(draw.includes('draw_graph.add_draw_list_draw(to_draw, p_instances)'));
assert(driver.includes('case API_TRAIT_HONORS_PIPELINE_BARRIERS:\n\t\t\treturn 1;'));
assert(vulkan.includes('uint64_t RenderingDeviceDriverVulkan::api_trait_get(ApiTrait p_trait)'));
assert(!vulkan.split('uint64_t RenderingDeviceDriverVulkan::api_trait_get(ApiTrait p_trait)')[1].split('RenderingDeviceDriver::api_trait_get(p_trait)')[0].includes('API_TRAIT_HONORS_PIPELINE_BARRIERS'));

const raw = source['reports/nwn74-forward-census-d.performance.jsonl'];
const windows = raw.trim().split(/\r?\n/).map(JSON.parse).filter(x => x.frame_profile?.frames === 240).slice(-3);
assert.equal(windows.length, 3);
const fields = [
  'rt_scene_instance_count', 'rt_visible_geometry_count', 'rt_visible_light_count',
  'rt_scene_shadow_count', 'rt_shadow_prep_us', 'rt_geometry_cull_us',
  'rt_visibility_cull_us', 'rt_rd_scene_total_us', 'rt_forward_draw_calls',
  'rt_forward_color_draws', 'rt_forward_depth_draws', 'rt_forward_shadow_draws',
  'rt_forward_indirect_draws', 'rt_forward_pipeline_lookups',
  'rt_forward_pipeline_reuses', 'rt_forward_material_binds',
  'rt_forward_vertex_binds', 'rt_forward_xform_binds',
];
const counts = windows.map(w => {
  const metrics = w.frame_profile.metrics;
  const result = { elapsedMs: w.elapsedMs, frames: w.frame_profile.frames };
  for (const field of fields) {
    assert(metrics[field] && Number.isFinite(metrics[field].mean), `Missing ${field}`);
    result[field] = metrics[field].mean;
  }
  assert(Math.abs(result.rt_forward_color_draws + result.rt_forward_depth_draws + result.rt_forward_shadow_draws - result.rt_forward_draw_calls) < 0.03);
  return result;
});
const average = Object.fromEntries(fields.map(k => [k, counts.reduce((s, r) => s + r[k], 0) / counts.length]));
assert.equal(average.rt_visibility_cull_us, 0);
assert.equal(average.rt_forward_indirect_draws, 0);
const receipt = {
  issue: 'NWN-74',
  kind: 'read-only count census; no FPS run, no engine build, no production edit',
  pins,
  windows: counts,
  threeWindowMean: average,
  sourceFindings: {
    shadow: 'SCENE_SHADOW_COUNT is max_shadows_used, i.e. shadow passes, not distinct lights; 890 shadow draws are part of the 3,054 Forward+ draw total. The 0.60 ms shadow-preparation span contains projection/coverage, light dirtiness, atlas allocation and shadow-instance merging; these operations have changing camera/light/atlas state.',
    visibility: 'Visibility-range admission is skipped when instance_visibility has no nonzero bins; its measured span is 0 us in all three windows. Geometry culling still traverses registered instances and emits 1,437 visible geometry records.',
    submission: 'Forward+ emits one varying base_index push constant and draw command per drawn element. RenderingDevice processes descriptor state per draw, with bind flags and batch logic. The Vulkan device-constant HONORS_PIPELINE_BARRIERS trait is queried inside the per-set draw loop; it is redundant as a value but exact dynamic set count and isolated cost are absent from the saved counters.',
  },
  suspectedIdempotentCall: {
    operation: 'RenderingDevice::draw_list_draw -> driver->api_trait_get(API_TRAIT_HONORS_PIPELINE_BARRIERS)',
    sourceBound: 'Called once per active expected-format descriptor slot in each direct draw; Forward+ has 3,054 direct draws/frame and uses sets 0..3, but saved counters do not record each draw\'s set_count or expected-format mask.',
    exactDynamicCalls: null,
    isolatedCostUs: null,
    safeEditEstablished: false,
  },
  result: 'No substantial repeated idempotent operation with both measured invocation count and isolated cost is established. Do not change production on this census; a private per-draw descriptor-slot/trait-call counter would be the next gate if this path is prioritized.',
};
const out = path.join(root, '.cache/nwn74/inner-operation-census-a.json');
fs.mkdirSync(path.dirname(out), { recursive: true });
fs.writeFileSync(out, JSON.stringify(receipt, null, 2) + '\n');
console.log(JSON.stringify({ out, frames: counts.length * 240, shadows: average.rt_scene_shadow_count, instances: average.rt_scene_instance_count, visible: average.rt_visible_geometry_count, draws: average.rt_forward_draw_calls, shadowPrepUs: average.rt_shadow_prep_us, geometryCullUs: average.rt_geometry_cull_us, rdSceneUs: average.rt_rd_scene_total_us }));
