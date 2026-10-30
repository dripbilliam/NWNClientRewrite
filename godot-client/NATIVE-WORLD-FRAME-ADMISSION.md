# Native world poses and further join/frame evidence

Original target: immutable NWN:EE89.8193.37-17 x64 nwmain.exe, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
This is an incremental investigation, not full join/culling reconstruction.

## Original boundaries

- ClientArea receiver14076d910 calls LoadArea1407dba70 at14076e315. Its complete
  40089 UTF-16-unit pseudocode was retrieved in two pages from retained evidence
  `ev_1c2b055d5f6d0625b26aae8d99d65ccc6dd62f141dda8d5c5d2be4fe437811a9`.
  It unloads prior area state, reads entry position/facing and checks overflow,
  loads the area, then on success applies the controlled object's area/position/
  facing if present. Failure follows its own load-panel/app cleanup path.
  Scope guards and instrumentation do not prove where AreaReady is sent.
- Module Update1407cffc0..1407d0466 checks area/camera availability, sets camera
  clipping/follow parameters and advances the area's frame owner at1407d031b
  ->1407e7da0. Its final camera virtual+10 call is1407d03ae. Lower indirect
  targets and complete draw/culling rules need separate mapping.
- Area frame1407e7da0..1407e90ad updates weather/light/fade state, calls
  140878240 at1407e9041 and its scene virtual+20 at1407e9054. This does not
  establish that all static transform work is absent deeper in the scene.
- Item receive14079fe30..1407a02ab reads item state and calls constructor
  140769130 at1407a01a8, then handles canonical/scene ownership and active-item
  state. This is an item path, not a general creature/placeable constructor.

Derived selected dossiers: `backups/animations/rea-world-area-frame-v1.json`,
`rea-world-module-frame-v1.json`, `rea-world-item-receive-v1.json`; complete
receiver text: `native-world-area-receiver-rea-v1.txt`. Selected views exclude
duplicated raw results and high-pcode, with that scope declared. They preserve
complete function pseudocode/assembly and relationship limitations where available.
`scripts/inspect-native-world-frame-boundaries.py` independently verifies six
original call instructions and rejects an unexpected executable hash. It does
not execute these complete functions or resolve the virtual calls.

## Native correction

Our live world previously recomputed every admitted object's world pose every
frame. Only creatures have native motion integration. Ground items, placeables
and doors now apply their raw transforms on snapshot receipt and initial model
admission; creature poses still update every frame. An object that moves while
its model prepares is published at the latest received transform immediately,
before `instance_ready`. Appearance-key replacement and deletion stay intact.
Static model animation/reference/particle owners keep their independent ticks.

This is our adapter optimization consistent with separate received state and
native frame owners. It is not a claim to have reconstructed the original dirty
flags. The protocol host still sends the full registry at5 Hz; snapshot signature
work and missing-model planning scans remain. No JS rendering work was added.
Counters `pose_evaluations` and `static_pose_evaluations` expose the saved work.

## Scoped verification

- `native-static-pose-v1`: eight checks using the actual live world and authored
  snapshots with stub render owners.602 noncreatures receive initial poses;
  180 frames evaluate only the creature, adding zero static pose evaluations.
  Tests later position/orientation changes, moving-creature continuity, late
  admission at the newest pose, deletion and owner retirement. No network/GPU
  scene or dense-world frame-rate claim comes from this fixture.
- `native-session-static-pose-v1`: actual default launcher against owned local
  Prelude. Player ready1460.393 ms with1/19 entities and two background owners;
  native/server movement is observed while18/20 entities and two batches remain.
  Final20 entities/nine tiles, server/native walk distance1.500033 m, workers0,
  finish acknowledged and clean exit. This is a warm small-room regression.
  Existing missing cloud bitmap and unsupported chunk-particle warnings remain;
  clean gameplay admission does not establish complete particle presentation.

Both checks use normal-heap CDB with four traps, unchanged runtime sources and
no trapped native or engine/lifetime error. No public connections were made.
These checks establish correctness within their scopes, not a causal FPS gain,
cold/warm dense-world acceptance or resolution of all historical native faults.
Complete effects, moving protocol replay, repeated transitions/reconnects and
the broader ordered goal remain open. Continue BINARY-WORLD-STREAMING-GOAL.md.
