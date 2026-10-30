# Native movement cue playback

2026-10-27. Scoped correction playback is accepted; full locomotion/combat
and mixed-client parity remain open. See `NATIVE-UI-COMBAT-MIGRATION-GOAL.md`.

## Cause and implementation

Native motion already calculated idle position-correction requests24–27, type6,
but the live world did not deliver them to private combat/model playback. The
visual position therefore moved while the character could remain in idle.
The live motion producer also lacked feedback of the actual combat animation.

`native_data/movement_cue.gd` fits the original clip to the remaining WORD
correction timer using binary32 arithmetic. `combat_animation.gd` queues the
step through the existing private animation queue. `native_render/live_world.gd`
delivers correction and ordinary turn requests, and feeds the actual visual
animation back into motion. Replicated base animations and destinations remain
unchanged. Pending/active attacks or casts take priority; repeated frames do not
restart the correction. A movement path still selects its original gait.

## Original binary evidence

Pinned NWN EE89.8193.37-17 x64 SHA256:
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a.

- `backups/animations/rea-network-client-motion-correct.json`, FUN140804840:
  correction creates type6, supplies the owner+2cc timer, and calls the owner's
  PlayAnimation virtual at140804b48.
- Read-only creature vtable+150 resolves to1407fc7d0. Its type6 branch at
  1407fcb2d reads the WORD duration at1407fcb35, divides clip length by duration
  when positive, and queues a null-record animation at1407fcb71→1407635a0.
- `backups/animations/rea-movement-playanimation-owner.json` retains the
  decompilation. `native-network-correction-observations.json` retains208
  producer cases,48 of which queue a correction.

## Verification

Final debugger receipts, all source unchanged, no engine/lifetime errors:

| Run under reports/ | Checks | Scope |
| --- | ---: | --- |
| native-correction-final-oracle-v2 |516|208 correction observations,48 fitted cues, duration edge cases |
| native-correction-final-playback-v2 |32|Real private rigs/AnimationPlayers, four directions, geometry, queue priority and return to idle |
| native-correction-final-facing-v2 |15|World-to-rendered-pivot target facing |
| native-correction-final-motion-v2 |47421|Existing original movement oracle |
| native-correction-final-combat-v2 |4595|Existing selectors, queues and actual one-shot clocks/events |
| native-correction-final-playability-v1 |1314|Existing native playability regressions |
| native-correction-final-live-motion-v1 |141|Existing initialized live-world gait playback |

Total54034 checks. These are correctness observations, not FPS benchmarks.

`native-correction-actions-final-v1`:8 checks pass against the unchanged original
server binary on owned loopback5125, graphical Godot under normal-heap CDB.
The server executes an authored JumpToLocation script, shifting X by0.75m.
Both native test destinations are cross-checked against independently retained
incoming wire positions. Actual cwalkb advances two model clocks, changes53
local parts and deforms sampled skin vertices. Exactly one type6 cue plays,
then idle resumes and final correction error is0. Host/native success,
sourceUnchanged, zero public connections, no exceptions, finish acknowledged,
workersRemaining0. The fixture creates no synthetic movement packets or poses.

Retained failed receipts are not acceptance:

- Isolated-v2/v3 initially read movement destinations from the UI registry.
  Movement-only deltas use a separate stream and do not refresh that snapshot.
  The corrected probe reads settled motion state and cross-checks wire positions.
- Final-combat-v1 exposed an obsolete hand-built rig fixture missing
  manual_poses. The fixture now supplies that required field and explicit
  success; all original event assertions remain and pass in v2.
- The combined native-correction-actions-v1 failed blood-effect preparation:
  unarmed gore selection requested maximum HP that the server did not disclose.
  Isolated-v1 also failed the full combat blood pixel check. Those broader
  combat failures remain open; the dedicated correction fixture does not
  claim to resolve them or prove all combat effects ready.

## Remaining work

The observed sliding cause is fixed at this scope. Test broader moving-target
combat, shaped bodies, reactions, animation interruptions and paired original
client timing before claiming full parity. The movement-cue admission guard
preserves server combat priority; exact original per-frame scheduling remains
an acceptance gap. Native UI appearance, especially radial artwork/layout,
remains the next migration priority.
