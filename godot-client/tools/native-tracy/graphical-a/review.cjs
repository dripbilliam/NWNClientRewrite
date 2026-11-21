'use strict';
// Read-only review of CLOSED headless evidence and current graphical test source.
// This script never launches Godot, capture/export tools, network or compilers.
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const assert = require('assert/strict');
const root = path.resolve(__dirname, '../../..');
const file = p => path.join(root, p);
const read = p => fs.readFileSync(file(p));
const json = p => JSON.parse(read(p));
const sha = p => crypto.createHash('sha256').update(read(p)).digest('hex');
const pin = p => ({file: file(p), sha256: sha(p), bytes: read(p).length});
const checks = [];
function check(ok, label) { assert(ok, label); checks.push(label); }
const acceptancePath = '.cache/native-tracy/captures/headless-wire-b/trace-acceptance.json';
const proofPath = '.cache/native-tracy/smoke/wire-b/process-proof.json';
const reportPath = '.cache/native-tracy/smoke/wire-b/report.json';
const acceptance = json(acceptancePath), proof = json(proofPath), report = json(reportPath);
check(acceptance.success && proof.success && report.success, 'All three actual closed evidence reports pass');
check(proof.engineExit === 0 && proof.captureExit === 0 && proof.forced === false, 'Natural clean engine/capture closure');
check(proof.pid === acceptance.client.pid && proof.creationFileTimeUtc === acceptance.client.creationFileTimeUtc, 'Exact client PID and creation time agree');
check(sha(reportPath) === proof.report.sha256, 'Actual result hash agrees with process proof');
check(acceptance.trace.sha256 === sha('.cache/native-tracy/captures/headless-wire-b/capture.tracy'), 'Actual saved binary trace hash agrees');
check(acceptance.cpu.rows === 24705 && acceptance.cpu.completedEvents === 24705 && acceptance.cpu.incompleteEvents === 0, 'All 24705 exported CPU events complete');
check(acceptance.frames === 493 && acceptance.cpu.spanNs === '8150092788', '493 frame markers and actual 8.150092788-second CPU span');
check(acceptance.client.connectionObserved && acceptance.client.aliveThroughCapture && acceptance.client.lifetimeSamples >= 2, 'Owned client observed connected through capture');
check(acceptance.gpu.completedEvents === 0 && acceptance.gpu.required === false, 'No unearned GPU event claim');
for (const name of ['Main::iteration', 'smoke_main_tick', 'NWNCapture/Worker/task_scope', 'smoke_worker_task', 'NWNCapture/Particles/frame', 'NWNCapture/Particles/advance_batch', 'NWNCapture/Particles/geometry_batch']) {
  check(acceptance.cpu.zones[name]?.positiveEvents > 0, 'Actual positive CPU events: ' + name);
}
const mainThreads = acceptance.cpu.zones['Main::iteration'].threadIds;
check(acceptance.cpu.zones['NWNCapture/Worker/task_scope'].threadIds.every(id => !mainThreads.includes(id)), 'Worker events have distinct captured Tracy thread identifiers');
check(report.submitted === report.completed && report.remaining_task === -1 && report.main_frames === report.native_frames, 'Worker work joined and each main tick submitted native empty frame');
check(report.final_bridge.bound && report.final_bridge.begun === report.final_bridge.ended && report.final_bridge.live_scopes === 0 && report.final_bridge.invalid_token === 0 && report.final_bridge.overflow === 0, 'Bridge final scope/token/overflow balance');
const testPath = 'tests/native_particle_stream_scene_test.gd';
const source = read(testPath).toString('utf8');
check(sha(testPath) === 'a7a7df95a6dc9f212668f1ec42eefe0befb6c273211c2e97c2d505a85647db46', 'Graphical test exact reviewed source');
check(source.includes('for frame in 40: await process_frame') && source.includes('for frame in 260:'), '300 bounded graphical process frames');
check(source.includes('environment.compositor=null; effect.close(); presentation.call("dispatch",5,{})'), 'Compositor detached and native paths closed before scene release');
check(source.includes('scene.free();') && source.includes('quit(0 if failures.is_empty() else 1)'), 'Scene release and natural result-dependent exit');
check(source.includes('pixels>1000 if count==1506 else pixels>0'), 'Count64 requires actual positive visible pixel difference');
const install = path.resolve(root, '../../FullDecomp/NwnRootInstall');
check(fs.statSync(path.join(install, 'data/nwn_base.key')).isFile(), 'Exact sibling original install KEY exists');
const expectationPath = 'tools/native-tracy/graphical-a/expectations-stream.json';
const out = file('.cache/native-tracy/wire-review-b');
fs.mkdirSync(out, {recursive: true});
const receipt = {
  version: 1, kind: 'independent-closed-tracy-wire-b-and-graphical-source-review', checkedUtc: new Date().toISOString(),
  success: true, checks, nativeProcessesLaunched: 0, compilersLaunched: 0,
  wireEvidence: [acceptancePath, proofPath, reportPath, '.cache/native-tracy/captures/headless-wire-b/capture.tracy'].map(pin),
  wire: {frames: acceptance.frames, completedCPUEvents: acceptance.cpu.completedEvents, spanNs: acceptance.cpu.spanNs, capturedTracyThreadIds: acceptance.cpu.threadIds, bridgeScopes: report.final_bridge.begun, gpuEvents: 0},
  graphical: {
    status: 'SOURCE_REVIEW_ONLY_NOT_EXECUTED_BY_REVIEWER', install,
    files: [testPath, 'tests/native_particle_many_scene_test.gd', 'tests/native_particle_schedule_test.gd', 'systems/native_render/particle_stream_effect.gd', 'systems/native_data/resource_catalog.gd', 'systems/native_data/archive_index.gd', 'systems/client_api/rest_options.gd', expectationPath].map(pin),
    recommendedEngineArguments: ['--path', '<PRIVATE_PROJECT>', '--render-thread', 'separate', '--max-fps', '20', '--script', 'res://tests/native_particle_stream_scene_test.gd', '--', '<EXACT_16_NORMAL_FUNCTIONAL_FLAGS>', '--install=' + install, '--report=<FRESH_ABSOLUTE_JSON>', '--count=64', '--entity-api-rest=false'],
    anchors: {startup: 'tests/native_particle_schedule_test.gd:94', camera: 'tests/native_particle_stream_scene_test.gd:29', driverMainThread: 'tests/native_particle_stream_scene_test.gd:10', fixedFrames: 'tests/native_particle_stream_scene_test.gd:43', pixelReadback: 'tests/native_particle_stream_scene_test.gd:58', close: 'tests/native_particle_stream_scene_test.gd:83', renderThread: 'systems/native_render/particle_stream_effect.gd:15', installReadOnly: 'systems/native_data/archive_index.gd:28'},
    limitations: [
      '300 capped process frames require at least about15 seconds plus startup/readback/cleanup; an exact-owned outer watchdog is required because the test has no internal wall deadline or readiness marker.',
      'Attaching at process age2s can include imports/mount/first shader compilation. Require actual positive named render events and pixel/result gates; do not call this a settled performance window.',
      'Fixture exercises original-texture stream rendering, not ordinary rigs, history lighting or a full game area. All16 flags can be carried but need not show use in this limited fixture.',
      'No GPU Tracy integration is present. Render draw zones are CPU submission work; GPU export is optional and expected empty.',
      'network_connections0 is literal fixture metadata. CLI RESTfalse prevents inherited REST-autoload enablement; external runtime socket observation remains a separate parent gate.',
      'Keep ForwardPlus and existing MSAA settings. Do not select Compatibility; compositor uses RenderingDevice attachments. Omit gpu-timing/readback/no-depth/reference options for this proof.'
    ]
  },
  interpretation: [
    'CSV thread IDs are Tracy0.13 compressed thread identifiers, not OS thread IDs or proof of simultaneous core occupancy.',
    'GDScript caller/callee scopes may share a function zone name. Disambiguate by source file/line and self time; doubled name count is not duplicate script execution.',
    'The capped smoke Main::iteration includes frame-delay scope. No clean FPS, actual game bottleneck, or speedup claim follows from this integration proof.'
  ],
  reviewerSource: pin('tools/native-tracy/graphical-a/review.cjs')
};
const target = path.join(out, 'receipt.json');
fs.writeFileSync(target, JSON.stringify(receipt, null, 2) + '\n', {flag: 'wx'});
console.log(JSON.stringify({file: target, sha256: crypto.createHash('sha256').update(fs.readFileSync(target)).digest('hex'), checks: checks.length, expectation: pin(expectationPath)}));
