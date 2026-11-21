'use strict';
const fs=require('node:fs'),path=require('node:path');
const project=path.resolve(__dirname,'../..'),root=path.join(project,'.cache/native-presentation-parity/root/fps-max-v1/movement-native-review-a'),file=path.join(project,'NATIVE-FPS-MAX-GOAL.md');
const installed=JSON.parse(fs.readFileSync(path.join(root,'sparse-pending-v8/promotion/installed.json')));
if(!installed.success||require('../native-feature-manifest.cjs').sourceIdentity(project).sha256!==installed.sourceAfter)throw Error('Installed checkpoint differs');
const marker='## Current movement checkpoint';let doc=fs.readFileSync(file,'utf8');if(doc.includes(marker))throw Error('Current checkpoint already recorded');
const boundary=doc.indexOf('\n\nThe goal began at');if(boundary<0)throw Error('Expected goal document boundary missing');
const current=`

${marker}

The user released the PC for visual testing and asked whether the prototype was worth an Arelith test. The reviewed changes are now installed in the normal launcher: application identity ${installed.sourceAfter}. Exact before bytes, acceptance and installed-source proof are in \`fps-max-v1/movement-native-review-a/sparse-pending-v8/promotion/\`. Runtime/default/quality flags and native libraries are unchanged.

Pending appearance IDs now avoid revisiting installed objects during active model preparation. The existing support/quiescent chain and canonical readiness, priority, retry, sorting and owner-limit policy remain authoritative. Explicit invalidation, nested writers, publication and retirement are covered. The base planner filters installed/inflight/exact-failed rows before pure classification and adds the missing motion/priority/planning/owner timers. The separately verified immutable light-palette upload fix retains exact GPU bytes and synchronous callback changes.

The final combined build reaches89 sampled input-section FPS versus77 for the exact-current control, with97 quiet FPS in both. Geometry/counts/settings/camera,360 recorded movement operations, DLL provenance and cleanup gates pass. Final quiet frame means are9.566ms control and9.623ms candidate; no material quiet gain or Arelith guarantee is claimed. Earlier private v5 ABBA gives68->85 and72->83 input FPS. Baseline variation68-77 and the earlier cross-batch final control remain explicit limits; its driver/configuration/runtime are byte-identical to v8.

Seven v7 planner/receiver/publication/retirement cases pass570 checks. The unchanged planner is rechecked in v8, along with real publication and six worker-retirement cycles. Palette checks add202 CPU and99 actual GPU assertions; the original palette deterministically fails the GPU pixel ownership negative control. A failed v7 run with an empty64512-byte texture upload is retained and excluded. The final combined v8 replay is clean and its saved view was compared with the control. See \`movement-native-review-a/RESULTS.md\` for receipts and limits.

All owned test clients are closed; no public login/play was automated. The normal launcher is ready for manual Arelith validation of both movement modes and the new timers. Keep extra graphical workloads held during that manual window and continue light research. The broader FPS/pause/parity goal remains active.

## Historical checkpoints`;
let history=doc.slice(boundary).replace('makes the current installed application identity45b','made that historical installed application identity45b').replace('Live handoff2026-11-08:','Historical handoff2026-11-08:').replace('is open on secondary2','was open on secondary2').replace('Current steering:','Historical restricted-PC steering:');
fs.writeFileSync(file,doc.slice(0,boundary)+current+history);
const results=`# Movement planner and light-palette checkpoint

Installed application: \`${installed.sourceAfter}\`. Before: \`${installed.sourceBefore}\`. The full research goal remains active.

| Source cohort | Control input FPS | Candidate input FPS | Control/candidate quiet FPS |
| --- | ---: | ---: | --- |
| v5 first pair |68 |85 |95 /94 |
| v5 reversed pair |72 |83 |97 /97 |
| Production-path v7 |77 |86 |97 /97 |
| Final combined v8 |77 |89 |97 /97 |

These are medians of ready rolling Engine FPS observations during the same recorded input section, not independent frame-time means or a pure movement-versus-idle causal experiment. v8 uses the earlier v7 exact-current control, with identical driver bytes, settings, runtime, generation2/360 inputs and source-control identity. Baseline variation68-77 is material. The last ten-second quiet interval mean is9.565707ms control and9.623354ms v8, so no useful quiet-frame gain is claimed. No loading or general Arelith gain is established.

All accepted cases preserve1918 entities,44208 nodes,2234 draws,183381 triangles and235 shared particle failures. Camera/FOV45, viewport, quality/effects, recorded motion/terminal authority, current secondary display/unfocused state, source/runtime pins, actual sparse-planner use and clean shutdown gates pass. Saved final control/v8 views were inspected: matching framing, geometry, avatar, UI and lighting with expected live flame variation. This is bounded inspection, not exhaustive native visual parity.

The planner retains unresolved integer IDs only. Canonical rows remain on World, existing policy still constructs plans, and the support/quiescent chain remains selected. Covered writers are full/delta receive, desired replacement/removal and instance retirement; publication prunes current installed keys, nested planning uses live desired, and explicit invalidation between boundaries refreshes equal-size owner edits. Raw same-size dictionary mutation outside the owner/invalidation contract remains unsupported, as with settled planning. Seven v7 focused cases pass570 checks. v8 retains byte-identical planner sources and rechecks131 planner assertions plus real publication and78 retirement assertions.

The v7 candidate A is rejected for an empty64512-byte texture update; its receipts are unchanged. This exactly matches2*2016*16 bytes in the light palette. The retained immutable-upload fix matches the exact old palette source hash2485df8c and yields6d4fac94. It snapshots initial creation and updates, preserves the GPU texture/RID, and retains dirty if a synchronous changed callback advances revision. Current-engine tests pass202 CPU and99 separate-render-thread GPU checks. The otherwise identical old-palette negative control fails expected pixel ownership assertions. This confirms a palette ownership bug; identifying the one observed empty upload with that bug remains a strong size/source inference without an instrumented texture RID stack. The final combined world run has no engine/lifetime errors.

The older name-signature fixture also failed identically against unchanged current and candidate sources. Its obsolete expected tuple omitted the already-established lifetime/animated-placeable prefix. The old bytes and both identical failing reports remain in v7; the corrected fixture passes72 assertions on each. Production signature logic is unchanged.

Acceptance: \`sparse-pending-v8/promotion/acceptance.json\`. Installed-source proof and exact backups: \`sparse-pending-v8/promotion/\`. Final run: \`fps-movement-a-v8-a-candidate-a\`; control: \`fps-movement-a-v7-a-control-a\`. Other private failures, the initial sandbox rejection and all frozen stages are preserved. Particle DLLb8c31441 and resource DLLf2ac66d9 are unchanged. No public server was contacted. All owned tests are closed. Manual Arelith evaluation and other speedups remain open.
`;
fs.writeFileSync(path.join(root,'RESULTS.md'),results,{flag:'wx'});console.log(JSON.stringify({goalDocument:file,results:path.join(root,'RESULTS.md'),installed:installed.sourceAfter,goalComplete:false}));
