const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '../..');
const tag = process.argv[2] || 'review';
if (!/^[a-z0-9-]+$/.test(tag)) throw new Error('Invalid review tag');
const digest = value => crypto.createHash('sha256').update(value).digest('hex');
const source = [
  'systems/native_data/asset_service.gd', 'systems/native_render/live_world.gd',
  'systems/native_render/resource_pool.gd', 'systems/native_render/model_template.gd',
  'systems/native_render/object_stream.gd', 'systems/native_render/area_stream.gd',
  'systems/native_render/creature_stream.gd', 'systems/native_render/actor_instance.gd',
  'systems/model_rigs.gd', 'systems/native_render/skeletal_rigs.gd',
  'systems/native_render/reference_graph.gd', 'systems/native_render/door_instance.gd',
  'systems/native_render/placeable_instance.gd', 'systems/native_render/rig_construction.gd',
  'systems/native_render/model_placement_job.gd',
  'systems/native_render/native_model_recipe.gd',
];
const tests = [
  'tests/nwn62_construction_test.gd', 'tests/nwn62_completion_budget_test.gd',
  'tests/nwn62_frame_gap_test.gd', 'tests/nwn62_animated_objects_test.gd',
  'tests/nwn62_actor_failures_test.gd', 'tests/nwn62_publication_benchmark.gd',
  'tests/nwn62_sparse_recipe_test.gd',
  'tests/nwn62_small_packed_test.gd',
  'tests/nwn62_entry_budget_test.gd',
];
const files = source.concat(tests).map(file => {
  const bytes = fs.readFileSync(path.join(root, file));
  const baseline = path.join(root, '.cache/nwn62/before', file);
  const before = fs.existsSync(baseline) ? digest(fs.readFileSync(baseline)) : null;
  const target = path.join(root, `.cache/nwn62/${tag}-source`, file);
  fs.mkdirSync(path.dirname(target), {recursive: true});
  fs.writeFileSync(target, bytes);
  return {file, bytes: bytes.length, sha256: digest(bytes), before_sha256: before};
});
const manifest = {
  ticket: 'NWN-62', phase: 'Frozen implementation for independent review and component timing',
  written_utc: new Date().toISOString(), files,
  correctness: [
    ['completions-d',18], ['animated-f',46], ['construction-native-a',1574],
    ['frame-gaps-f',179], ['fill-c',17], ['staged-c',190], ['world-staged-b',10],
    ['predelete-c',1106], ['actor-failures-c',27], ['polling-c',26], ['rig-idle-c',27],
    ['publication-preflight-c',8], ['small-packed-a',18],
    ['sparse-native-a',102], ['recipe-native-a',47], ['world-delegates-a',10],
    ['entry-budget-a',9], ['completions-entry-a',18], ['fill-entry-a',17], ['world-entry-a',10], ['entry-preflight-a',8],
  ].map(([label, checks]) => ({label, checks, log: `.cache/nwn62/checks/${label}.log`, report: fs.existsSync(path.join(root, `.cache/nwn62/checks/${label}.json`)) ? `.cache/nwn62/checks/${label}.json` : null})),
  benchmark: {
    command: "& '.tools/native-core/Godot_native_core_e_win64.exe' --headless --path . --log-file '.cache/nwn62/checks/publication-abba-a.engine.log' --script res://tests/nwn62_publication_benchmark.gd -- --report=res://.cache/nwn62/checks/publication-abba-a.json 2>&1 | Tee-Object -FilePath '.cache/nwn62/checks/publication-abba-a.log'",
    expected_seconds: 15,
    cases: ['Unmodified installed tcn01_a01_01 tile,24placements', 'Authored258part/257mesh template,8placements', 'Same authored graph as private actors,8actors'],
    ordering: 'ABBA per case; fresh resource pool per leg;3ms shared ledger;60Hz headless frame pacing; normal Core E engine; all completed placements retained until end',
    scope: 'First-ready/full-publication wall latency; actual per-callback and per-unit CPU including begin/finalization. No renderer/FPS claim. All live server entry is not measured.',
  },
  limitations: [
    'Budget is cooperative: one native resource upload, Animation/skin unit, fallback PackedScene pack/instantiate, final helper activation or external service callback cannot be preempted; individual overruns stay measured.',
    'Explicit optional terrain-batch/merged publication paths retain their existing indivisible engine group operations; standard scene/actor paths are subdivided.',
    'Known-node recipe CPU/load-latency tradeoff must pass component gate; no universal FPS or Arelith promotion is claimed.',
    'NWN61 thin wrappers are included; received_snapshot_commit helper and inherited adapters remain independently owned/reviewed under61.',
    'Private --publication-entry-budget-us=8000 is opt-in only, follows exact one-way native_entry_loading lifecycle mark, and leaves ordinary3ms policy unchanged; no entry allowance default is promoted.',
    'AssetService includes reviewed NWN70 digest handoff; worker/decode semantics remain unchanged by this ticket completion scheduler.',
  ],
};
const output = path.join(root, `.cache/nwn62/${tag}.json`);
fs.writeFileSync(output, JSON.stringify(manifest, null, 2) + '\n');
process.stdout.write(JSON.stringify({output, sha256: digest(fs.readFileSync(output)), source_files: source.length, tests: tests.length, checks: manifest.correctness.reduce((n,r)=>n+r.checks,0)}) + '\n');
