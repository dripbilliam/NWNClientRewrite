# Creature relocation and stalled-movement recovery

Target: NWN:EE89.8193.37-17, original `../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`,
SHA256 `3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Read-only Ghidra/full-instruction inspection and isolated Unicorn execution;
no original binary, asset or Ghidra edits.

## Observed owners and source

- AIActionJumpToObject1403c1a60..1403c2a8b and
  AIActionJumpToPoint1403c2a90..1403c37da map to `src/jump_actions.js`.
  Dead/dying must equal1 to reject; missing path rejects. A client creature
  temporarily outside an area with pending destination+4f4 waits with result1.
  Native point/object slots are raw DWORDs regardless of type tags. Point argc
  thresholds4/5/6/7 select straight/range/facing; the seventh argument enables
  reading BOTH facing slots. Both default safe-location range20. Point coerces
  straight to a Boolean; object passes the raw INT.
- Point removes limbo membership before destination validation. Target area
  must be canonical type4. Object resolves AsNWSObject, with waypoint-facing,
  door action-point/opposite-side radius offsets, and pending creature area/
  position branches. The ordinary object's native subtraction yields zero for
  a normal identity cast; native normalization yields facing+X. Do not replace
  this with an inferred face-the-target rule.
- Native call sites1403c25b6/25c2/25d2 and1403c32c1/32cd/32e4 reset intertile/
  grid state and SetAnimation1, then set path+24 to actorID. ComputeSafeLocation
  sites1403c2624/3357 require return exactly1. Failure resets interarea state
  and returns3 without relocation. Success closes panels and cuts waypoints.
- Object sets orientation before placement; point normalizes planar facing
  after placement. Same-area calls SetPosition then jump subareas. Cross-area
  PC subareas first uses OBJECT_INVALID, then AddToArea and action60 in the
  original group. NPC AddToArea precedes destination subareas. NPC associates
  receive front jump48 in newly allocated groups, preserving original straight
  parameter. Finally actor receives front check4 in original group, sets+8f8=1,
  and returns2. The common RunActions cadence already stops after5/48.
- UpdateSubareasOnJumpPosition1403db4a0..1403db6fc maps to `subareas.js`.
  Endpoint-only membership; old count is captured before point query and
  attached-AoE callbacks. The live following list permits mutation, retains
  canonical stale-ID handling and duplicate suppression beyond16 IDs. State
  changes use no crossed list and transitionFlag0. Copy only after oldCount>0
  or endpoint-found, and HandleChanges returns exactly1. Assembly1403db6d3/6e2
  returns1 after copying, otherwise0; decompiler free returns are misleading.
- Attached AoE JumpToPoint1404f7a70..1404f7b90 maps to `area_effect.js`.
  Canonical anchor and identical area gate movement. Remove anchor membership,
  queue old-volume exits through RemoveFromSubAreas0, SetPosition, restore
  anchor membership if absent, then update endpoint subareas. Cross-area
  ownership remains the separately proven creature RemoveFromArea/AddToArea.
- CutWaypointPath14038a500..14038a58e writes scalar route/cut cells; it does
  not demand a waypoint allocation. `path_walk.js` now permits a first-ever
  jump with null route storage. Walking retains its allocation checks.
- ClearAction1403870b0 shared tail is valid for4/5/48/60. Added to the existing
  bounded native cancellation comparison and live ClearAllActions dispatch.
  Interruptibility, lock cleanup and head==1 time reset remain shared.

## Integration and validation

`combat_runtime.js` dispatches queued5/48 and real forced-move timeout18
through these owners. The existing cancellation==1/type1 timeout gate and
temporary node disposal are unchanged. `module_session.js` exposes native+4f4
and+4f8 as aliases of movement's existing pending destination; these are one
owner, with native/render coordinate conversion at the boundary. Session jump
subarea changes enqueue normal script events and keep the preview cache aligned.

- `inspect-native-jump-actions.py`: **1,980** original executions, comparison
  of return, ordered lower calls, action groups/slots, path owner and+8f8.
  Finite synthetic cases include default/partial argc, raw flags, invalid
  destinations, exact result gates, all target branches, pending area, clients,
  cross-area transfer and associate/stale IDs. Normalization executes unchanged.
- `inspect-native-jump-subareas.py`: **420** owner executions. Point query,
  HandleChanges, AoE removal/updates and list allocation are captured boundaries;
  gates, callback order, live list traversal, old-count snapshot and copy execute.
- `inspect-native-cut-path.py`: **18** full original executions without lower
  replacements, null route pointer and sequence rollover included.
- Existing force-follow fixture now has756 observations: **96 additional**
  cancellation cases for4/5/48/60. Native jump tests plus all existing tests:
  **1,382 pass**. Production build passes. Reports `jump-all-tests-v2.txt`,
  `jump-build-v1.txt`, `jump-native-tests-v3.txt`, `jump-cut-regression-v1.txt`.
- `probe-live-jump-actions.mjs`/`live-jump-actions-v3.txt,json`: installed Prelude
  objects and collision data exercise queued point/object, attached installed
  vfx row0, both forced timeout receivers, NPC cross-area spatial removal/add,
  unchanged object identity, same-area player jump, and shared pending cells.
  No new unavailable engine actions. The known absent installed `plc_w02.pwk`
  remains explicitly logged through the proven empty-mesh fallback. It is the
  one expected error diagnostic; this is **not** an errors0 run.
- `jump-associate-regression-v1.txt`: real installed summon Follow/Stand/Guard/
  AttackNearest/Heal conversation-script path still passes with no errors.

## Remaining work and limits

This is not full spell, combat, campaign, multiplayer or native jump completion.
Registry/geometry/client transfer/subarea-event/list helper boundaries in the
owner oracle do not establish those helpers' internals or wire serialization.
The installed probe disables startup/general AI and uses explicit engine
fixtures; it is not a campaign quest, rendered visual comparison or native
process playthrough.

Door GetNearestActionPoint140420360 is captured, but its live exact owner is
still diagnosed as unavailable. PC cross-area ClientArea/automap and limbo
membership/removal remain unavailable. The legacy session JumpToObject/
ActionJumpToObject script/transition adapter remains separate; do not claim it
uses these native action owners yet. Next trace door GetActionPoint/DWK state
selection, then command wrappers and PC/limbo ownership before replacing that
adapter. `ghidra-native-door-action-point.txt` and jump assembly are captured.

Checkpoint: `backups/jump-actions-1382-20261015.zip`, verified report
`backups/animations/jump-checkpoint.txt`. Goal remains active.
