'use strict';
// Feasibility only: no replay modification, launch, movement, or camera command.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '../../..');
const pin = relative => {
  const bytes = fs.readFileSync(path.join(root, relative));
  return { relative, bytes: bytes.length, sha256: crypto.createHash('sha256').update(bytes).digest('hex') };
};
const report = {
  version: 1, createdUtc: new Date().toISOString(), kind: 'fully-loaded-motion-measurement-feasibility',
  conclusion: 'Current recorded-input FPS is an earlier phase than object_visuals_complete and the later steady window. It measures recorded movement/prediction plus loading/warmup in that phase, not isolated fully-loaded movement render cost. Do not relabel historical medians.',
  currentOrder: [
    'pump() consumes one sequence-ordered interleaved timeline: world frames, acknowledgements, movement inputs/samples, network packet evidence and views.',
    'MovementReplayClock preserves row.at gaps and shifts only at late catalog-ready/area-ready acknowledgements.',
    'The original input section finishes before timelineDelivered. Only after timeline delivery and object_visuals_complete does the driver start its settle period and request begin-performance-window.',
    'Native begin-performance-window accepts only offline replay/current connection via accept_connection, exact generation/area, ready_for_control and object_visuals_complete. It clears numeric frame samples and sends performance-window-ready.',
  ],
  delayedRecordedMovement: {
    disposition: 'Do not implement by holding/replaying only movement rows.',
    barriers: [
      'Blocking at an early movement row can prevent delivery of later world/resource/lifecycle rows needed for object_visuals_complete, causing a readiness deadlock.',
      'Delivering later rows first changes reliable movement/drive acknowledgements, snapshots, lifetime, visibility and animation event order.',
      'After the timeline the actor is at terminal authority state, not the original input start. Replaying old requests fails keyboard.request_serial monotonicity and may refer to retired lifetime/scope.',
      'Rekeying requests or forcing old actor positions invents a new prediction/authority history and is not the original recorded movement test.',
      'A warm-cache second launch does not guarantee the world is fully built before its input section and therefore does not solve this measurement question.',
    ],
    properFutureRoute: 'Record a separate fully-loaded input segment with initial authoritative state and complete ordered server replies, or construct a new owned local-authority scenario with fresh monotonic requests. That requires route-specific acceptance, not an input-delay switch.',
  },
  boundedAlternative: {
    name: 'Post-load camera-motion render/admission diagnostic',
    publicConnections: 0, actorInput: false, actorAuthorityTest: false,
    existingHook: 'native_session_world.gd replay-view accepts only --offline-replay=true after outer accept_connection; camera_state yaw/pitch/distance update controller.follow_state. CameraController.follow_frame applies the normal camera update. No actor position, request ID, lifetime or server snapshot is changed.',
    minimalDriverSeam: 'After pump() has timelineDelivered and observed object_visuals_complete plus existing settle interval, run a private camera prewarm path; restore terminal view; verify scope and readiness remain stable; then use the existing begin-performance-window/performance-window-ready barrier before starting a bounded camera command schedule.',
    suggestedSchedule: {
      durationMs: 20000, rateHz: 60, maximumCommands: 1202,
      yaw: 'Recorded terminal yaw +20degrees*sin(2*pi*t/5s), four cycles; retain recorded pitch/distance/mode and preference FOV. End at the exact terminal yaw.',
      control: 'Same command count/rate/fields, yaw fixed at terminal value; all other settings identical. This controls driver/protocol/observation overhead.',
      prewarm: 'Run the same path before the measured window in BOTH cases; wait for no pending object/material/preparation work before reset. A changed view can reveal first-use shaders/resources despite object_visuals_complete; retain any residual work and classify honestly.',
      caveat: 'This is60Hz protocol-driven camera pose motion, not mouse/key input and not a claim that every rendered frame has a new camera pose.',
    },
    nativeEvidenceGap: 'Current replay-view has NO acknowledgement or camera trajectory readback. Existing periodic observed does not include camera data with profiling OFF. Matching terminal begin/end camera poses alone cannot prove interior motion.',
    minimumPrivateObservationProposal: [
      'Add a private offline-only diagnostic request serial to camera-view handling and bounded cold camera observations after normal follow_frame has applied it; do not enable detailed profiling or recording banner.',
      'For example retain <=256 observations at10Hz: request serial, native process frame/ticks, actual global camera pose/follow inputs, current connection/generation/area and controlled actor/lifetime/received/render/idle state. No resources/world copying.',
      'Check finite input, monotonic serial, exact selected current connection/generation/area, bounded rate/count and private flag. Use the same observation requests in control and moving cases.',
      'Require actual changed yaw/global pose in moving case and stable camera in control; retain ordered observations and exact source hashes. This small source overlay needs no engine rebuild but must be separately tested and frozen.',
      'Restore terminal yaw and observe actual terminal pose/unchanged actor before normal finish. Report the performance window explicitly as camera-motion diagnostic; do not call it quiet steady or actor prediction acceptance.',
    ],
    acceptance: [
      'Exact engine/native/resource process/module proof and normal profileOFF/separate-RT/settings policy remain required.',
      'No pending world transition, stable entity/scope/lifetime and object_visuals_complete throughout measurement.',
      'Captured movement input section and original prediction receipt verification remain untouched; no additional replay-movement-input commands after it.',
      'Dedicated camera-mode verifier must validate its interior path and terminal restoration; preserve original quiet camera verifier without waivers for other runs.',
      'Same prewarm path, command/observation overhead and measurement duration; natural clean exit and image/state proof. One pair is diagnostic, not repeated optimization acceptance.',
    ],
    status: 'Viable bounded hook, but the required private observation/frozen-driver acceptance does not exist yet. No implementation or run is claimed by this audit.',
  },
  existingSourceBarriers: {
    connection: 'native_session_world.accept_connection validates finite integer connection and rejects stale/cancelled sessions; new connections require lobby/reset.',
    movement: 'replay-movement-input additionally requires offline + movement-timing and exact generation/area. movement_timing.replay checks controlled actor/lifetime and requestId>keyboard.request_serial, then calls ordinary preview/end_prediction; captured positions never overwrite authority.',
    camera: 'replay-view updates finite camera input fields but currently has no generation/area subguard or request receipt beyond outer connection. A scheduled private diagnostic must retain/validate world scope and stop on transitions rather than assume the camera message itself checks epoch.',
    finalVerifier: 'verifyReplayCameraEvidence currently checks captured terminal actor authority/idle state and equal begin/end camera pose. It is not an interior-motion verifier.',
  },
  sourcePins: [
    'tools/replay-native-loading.mjs', 'tools/native-movement-recording.mjs', 'tools/native-replay-camera-evidence.mjs',
    'native_session_world.gd', 'native_live_world.gd', 'systems/native_data/movement_timing.gd',
    'systems/camera_controller.gd', 'systems/native_render/camera_observation.gd',
  ].map(pin),
  implementedChanges: [], testsRun: [], clientsLaunched: [],
};
const output = '.cache/native-render-gap/original/warm-motion-feasibility-a.json';
fs.writeFileSync(path.join(root, output), JSON.stringify(report, null, 2) + '\n');
console.log(JSON.stringify(pin(output)));
