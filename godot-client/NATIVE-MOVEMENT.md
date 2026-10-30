# Native multiplayer movement

Current direct-native entry: see
[NATIVE-DRIVE-PREDICTION.md](NATIVE-DRIVE-PREDICTION.md). The sections below
describe the earlier adapter-based migration and its historical receipts. The
later request-only native driver lost local prediction; that regression is now
repaired with native Godot planning/collision and scoped protocol replies.

Status: **native motion, original drive protocol and reused exact collision
planning are implemented and locally verified**. Full movement/gameplay and
performance acceptance remain incomplete. No Arelith connection was used.

## Ownership and behavior

Godot now advances received paths and local drive previews every frame. It no
longer approximates held WASD by sending a new click-to-walk destination every
150 ms. `systems/network_motion.gd` ports the existing finite-vector movement,
acceleration, correction, facing, action-sequence and gait rules. Server proxy
state remains authoritative and unchanged by native prediction.

Controls follow the existing base-client mapping: W/S forward/back, A/D turn,
Q/E strafe, Shift walk, with arrow equivalents for W/S/A/D. Turn-only input
uses its original orientation request. Local preview refreshes at 250 ms and
ordinary wire drive refresh at 500 ms, with original partial-path timing and
repeated-key admission. A local tick can advance the input sequence without
transmitting, matching the established stale-acknowledgement rules. Release,
text focus, focus loss, click movement, actor lifetime changes and world
retirement invalidate held-input ownership.

`systems/keyboard_drive.gd` owns input in Godot. Open menu rectangles do not
block movement keys; text entry does. UI arrow-key focus remains available for
buttons/ranges/lists. Middle-mouse camera control and world click handling keep
their independent existing owners.

`tools/drive-staging.mjs` reuses the proven WOK/PWK/DWK and creature collision
queries, direct bisection and angular slide planner, and received-path repair.
It borrows immutable source resource owners and supplies a private projection
of native displayed creature poses. It does not write canonical objects or
source motion state and does not restart Three's animation/render loop. Godot
consumes short plans and integrates them natively; per-frame rendered poses or
deformed vertices are not sent to Three for rendering.

Collision IO is scoped by world, actor, appearance and input lifetime. Native
results must still match their pose/input owner. Each input preview permits at
most three collision attempts. Collision-only retries neither send a drive
packet nor advance the wire/input sequence. Native motion advances before
periodic geometry requests, allowing a reply to install before the next frame
changes the sampled pose. This avoids retrying every moving frame across IPC.

Received path repair retains original 1/64 acknowledgement radius/height and
no-creature policy. Native admission rechecks the newest record, motion pose,
path, script state, action sequence and lifetime after asynchronous work. A
late acknowledgement cannot replace newer driving. Native source-geometry
height sampling uses a conservative cell index and the original barycentric
calculation, closest-reference selection and face tie order. Original ground
triangles stay in the external runtime bundle. Shape/equipment replacement
updates stride/model parameters without discarding continuing motion.

Lost local transport now revokes admission, clears prediction/scene owners and
leaves the window closable without waiting for a dead networking backend.

## Evidence

- `reports/native-motion-oracle-v3.json`: **47,421 scalar comparisons pass**
  against retained original-binary observations: 3,933 movement/correction,
  1,272 facing (including long frames), and 2,916 gait cases. Maximum absolute
  error is 0.0000000596046448864129. These are bounded retained observations,
  not a claim that every original movement/animation branch is reconstructed.
  Their target hash is
  `3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
  Existing fixture limits identify original movement 8114d0, waypoint 811fc0 /
  804bf0, correction 804840, facing 807690 and the UI/drive owners. No original
  binary/process was patched or called live for these checks.
- `reports/native-keyboard-oracle-v3.json`: **778 checks pass**, including all
  192 retained original input schedules and native authored repeated key-down,
  opposite held keys, strafe/walk bits, turn-only input, two movable menus,
  text-focus abort, focus recovery and late released-preview rejection.
- `reports/native-movement-safety-v2.json`: **1,830 checks pass**. Actual retained
  short/matching/stale acknowledgement completion frames, preserved input data,
  reset prediction lifetimes, 1,500 authored exact ground-height queries,
  teardown and a late asynchronous sequence replacement check are included.
- `reports/world-scope-movement-regression-v3.json`: **17 native world-scope
  checks pass**, now including transport-loss cleanup of motion/admission.
  `reports/content-native-motion-regression-v1.json`: all **28** authored native
  model ownership/recreation checks remain green.
- **58 isolated Node cases pass**, including native-pose query isolation,
  actor/area/appearance retirement, interruption/disable handling, original
  acknowledgement repair and bounded drive/retry envelopes. **26** existing
  source native-derived preview/slide/timing/collision/geometry cases also pass.
- `reports/native-motion-click-local-v1.json`: actual owned Prelude click
  navigation, server path repair, native movement/camera and body/robe `run`
  animation pass; 1.5 metres server movement and no renderer errors.
- **`reports/native-keyboard-local-v4.json`**: actual owned native server runs
  the authored `GodotMovement` module, references original chest appearance 7
  and its real PWK footprint, and admits original installed wizard assets.
  Godot drives held forward, strafe, forward+turn, walking and release phases,
  with two menus open and a text-focus stop. Server displacement is 8.24 metres.
  Collision returns both partial paths and slide factors. Forward-facing span
  through the chest bump is below 2e-16 radians. There are 26 logical operations,
  15 sent operations including stops, 25 geometry queries, three bounded retries
  and 21 applied previews. The native rendered probe changes 52 local parts and
  actual skin vertices, with a maximum local delta 0.414. Renderer errors empty,
  native exit 0 and explicit disconnect. No synthetic server movement or fake
  collision answers are injected in this live test.
- `reports/native-movement-transitions-v1.json`: real A–B–A still passes with
  the motion owner, pending old-area content rejection, restored model/equipment
  and all 12 retired native owners freed. No renderer errors.
- `reports/native-movement-reconnect-v1.json`: owned Prelude export/save/rejoin
  using the saved BIC passes. Connections 1/3 both load 375 meshes and pass
  native path movement/skin/camera/chat; three versions share one temporary-vault
  ID, prior-save hashes are read for preview/upload, save-on-close succeeds,
  exit 0 and explicit disconnect. The application vault is preserved.

Authored movement module SHA-256:
`650c3e19838d14020796a332f7c7115b245df9663c1a875f2e2009f26aa4e09d`.
Fixture source is `tools/create-movement-server.mjs`, derived only from the
verified authored lifecycle module. Installed assets are referenced by resref.
The isolated source staging build is **v12**; normal main/dist remain unchanged.

The first live run functioned but performed 653 collision queries in its bounded
phases. Native scheduling/retry ownership was corrected; the final run performs
25. This is a functional work-count observation, not a controlled FPS speedup.
The first keyboard authored run had an incorrect empty-path assertion following
a prior turn; it is retained as failed. The first integrated world-scope run
logged a reserved-Node-property compile error despite a reported exit 0; it is
not accepted. The corrected v2/v3 native reports run without those errors.

## Limits and next work

This does **not** complete migration or the 60 FPS objective. The project editor
was preserved during functional checks, and diagnostic screenshots read GPU
data back. No steady-state benchmark follows from their frame sample counts.
The collision service still crosses local IPC; the first resource query and
native area import add loading latency. Full captured moving-world acceptance,
more actors and geometry, long/high-latency play, devices and OS-focus behavior
need broader checks. Native completion can briefly restore idle at a blocked
short-path endpoint; the finite completion rules intentionally follow the
retained original observations. Human movement-feel acceptance remains open.

Full animation combat/correction blends, sound/cue ownership, uncommon model
and control flags, mounts/shape coverage, per-part visual changes and other
replicated gameplay remain incomplete. Exact animated skin picking is still
pending. Interactions, rich chat/dialog/examine, combat/spells/feats, native
player windows and full NUI remain on the migration checklist.

The owned server is restored to **Prelude on UDP 5121** and stays running.
The user's project editor is preserved. For the bounded authored movement
fixture, use an unused report name after loading `GodotMovement`:

```powershell
.\godot-client\join-local.ps1 -MovementSmoke -Report keyboard-check-new.json
```
