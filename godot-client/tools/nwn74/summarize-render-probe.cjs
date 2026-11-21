'use strict';

// Read the existing replay profiler's JSONL without loading the capture into memory.
// Every duration below is a separate elapsed wall span. Nested spans overlap.
const fs = require('fs');
const readline = require('readline');

const input = process.argv[2];
const args = Object.fromEntries(process.argv.slice(3).map(raw => {
  const match = /^--([a-z-]+)=(.*)$/.exec(raw);
  if (!match) throw Error(`Unexpected argument: ${raw}`);
  return [match[1], match[2]];
}));
if (!input || !fs.existsSync(input)) throw Error('Provide a replay .performance.jsonl file');
const minFrames = Number(args['min-frames'] ?? 30);
const fromMs = Number(args['from-ms'] ?? 0);
const toMs = Number(args['to-ms'] ?? Number.POSITIVE_INFINITY);
const maxWindows = Number(args['max-windows'] ?? 64);
if (![minFrames, fromMs, toMs, maxWindows].every(x => !Number.isNaN(x)) || minFrames < 1 || maxWindows < 1) throw Error('Invalid bounds');

const durations = {
  frame: 'rt_frame_wall_us',
  viewport: 'rt_viewport_draw_us',
  cameraScene: 'rt_camera_scene_total_us',
  visibilityCull: 'rt_visibility_cull_us',
  geometryCull: 'rt_geometry_cull_us',
  meshInstanceUpdate: 'rt_mesh_instance_update_us',
  shadowPreparation: 'rt_shadow_prep_us',
  rdScene: 'rt_rd_scene_total_us',
  forward: 'rt_forward_total_us',
  forwardListFill: 'rt_forward_fill_us',
  forwardDrawList: 'rt_forward_draw_list_us',
  forwardRenderList: 'rt_forward_render_list_us',
  forwardPreOpaque: 'rt_forward_pre_opaque_us',
};
const counts = {
  sceneInstances: 'rt_scene_instance_count',
  visibleGeometry: 'rt_visible_geometry_count',
  visibleLights: 'rt_visible_light_count',
  sceneShadows: 'rt_scene_shadow_count',
};

function metric(metrics, key, scale) {
  const value = metrics[key];
  if (!value || typeof value.mean !== 'number') return null;
  return {
    // FrameProfile pads absent completed-render samples with zero. Its
    // when_present_mean is the correct completed-render-frame denominator.
    mean: (value.when_present_mean ?? value.mean) / scale,
    mainRowMean: value.mean / scale,
    p95: typeof value.p95 === 'number' ? value.p95 / scale : null,
    max: typeof value.max === 'number' ? value.max / scale : null,
    samples: value.samples ?? null,
    observedFrames: value.active_samples ?? value.samples ?? null,
  };
}

async function main() {
  const stream = readline.createInterface({ input: fs.createReadStream(input), crlfDelay: Infinity });
  const windows = [];
  let lines = 0;
  let eligible = 0;
  let missingProbe = 0;
  for await (const line of stream) {
    if (!line.trim()) continue;
    ++lines;
    const record = JSON.parse(line);
    const elapsedMs = Number(record.elapsedMs);
    const profile = record.frame_profile;
    if (!(elapsedMs >= fromMs && elapsedMs < toMs) || !profile?.enabled || profile.frames < minFrames) continue;
    if (args.phase && record.inputWindowPhase !== args.phase) continue;
    if (args.area && String(record.areaId) !== args.area) continue;
    ++eligible;
    const metrics = profile.metrics ?? {};
    if (!metric(metrics, durations.cameraScene, 1000)) {
      ++missingProbe;
      continue;
    }
    if (windows.length >= maxWindows) throw Error(`More than ${maxWindows} matching windows; narrow --from-ms, --to-ms, --phase, or --area`);
    windows.push({
      elapsedMs,
      areaId: record.areaId ?? null,
      phase: record.inputWindowPhase ?? null,
      profilerFrames: profile.frames,
      durationsMs: Object.fromEntries(Object.entries(durations).map(([label, key]) => [label, metric(metrics, key, 1000)])),
      countsPerScenePass: Object.fromEntries(Object.entries(counts).map(([label, key]) => [label, metric(metrics, key, 1)])),
    });
  }
  const output = {
    input,
    lines,
    eligible,
    missingProbe,
    available: windows.length > 0,
    semantics: 'Mean uses only main rows with a newly completed render frame; mainRowMean includes zero padding for skipped/repeated render frames. p95 can include zero padding. Elapsed owner render-thread wall spans include waits on workers; nested durations overlap and must not be added. Worker-only work is not directly counted. Counts are summed over rendered scene/pass calls, including repeat shadow or secondary passes; they are not unique objects.',
    windows,
  };
  const serialized = JSON.stringify(output, null, 2) + '\n';
  if (args.out) fs.writeFileSync(args.out, serialized, { flag: 'wx' });
  else process.stdout.write(serialized);
  if (!output.available) process.exitCode = 2;
}
main().catch(error => { console.error(error.stack); process.exitCode = 1; });
