# Isolated final-camera and primary-snapshot boundary

`camera_boundary.gd` and `camera_tangent_words.gd` are source-only helpers for
the future native BSP collector. Nothing imports them in production. They add
no process callback, scene signal, timer, native library, GPU work, world scan
or clock sample. The accepted CPU receipt is
`.cache/native-presentation-parity/loading-agent/native-camera-boundary-v7/run.json`
(SHA256 `f26cbb051241963575ecddea05ec81440787720ee6862fae528934e606978230`):
**353 checks, exit0, errors[], sourceChanged[], auditSourceChanged[]**.

## Native authority and exact inputs

The retained original executable is SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
[`NATIVE-TILE-FOG-COLLECTOR.md`](NATIVE-TILE-FOG-COLLECTOR.md) and
[`evidence/native-tile-fog-math-and-inputs-v1.json`](evidence/native-tile-fog-math-and-inputs-v1.json)
retain the actual decoded camera instructions and renderer DeltaT writer:

* `Camera::RenderScene14005a5d0`, plane construction `05a971..05aee5`,
  `ev_4393914dd018195bd1a10f8edf54a40ad4cff9b0c8d0e56fa03049d3137f7161`:
  position at camera+b0/b4/b8 is native XYZ; quaternion at+bc is WXYZ.
  Vertical angle+4c8, effective viewport aspect, near+4d0 and far+4d4 feed
  the six original planes. Camera-local ray axes are unchanged. The normals
  use original `NormalOf22d960`, normalization230920 and quaternion22ae90.
* Perspective half tangent is original `DegToRad22c210(f32(angle*.5))`, then
  original tanf`c7d790`. The retained instruction oracle explicitly selects
  its SSE branch. Neither host `tan`, Godot projection/frustum planes nor
  inverse projection coefficients replace that word.
* Main update1406db800 at`6db9b7..6db9d5`,
  `ev_ebe0767da57bdb42834b082707e5e4c0b0f45ce857de79fc09d8665593a959c4`,
  reads primary Client+50 timer snapshot difference through597050. It takes
  **signed low32**, converts that integer to f32, divides as f32 by1000000,
  and stores renderer DeltaT at14128e030. The high word is retained in the
  source lease but does not enter this conversion. Whole milliseconds,
  unsigned-low conversion, double division before f32, GUI T2, process delta
  and a new absolute-clock sample would be different operations.

`camera_tangent_words.gd` cold-loads only the immutable executed corpus
`native-collector-oracle-v4/corpus.json`, SHA256
`0787fb0f48d81743adaf79a526b4f44428f36d4063d8a334d99a364cea0c542d`,
and verifies its binary and oracle-source identity. Its10 perspective records
provide **45 and90 degrees only**. The lookup is keyed by the f32 angle word
and returns the original tangent word and explicit `original-sse` branch.
An80-degree setting, unrecorded angle or different CPU branch is unavailable.
The original live client's selected SSE/FMA branch is not established by this
CPU corpus; this isolated SSE fixture does not certify live branch dispatch.

## Present source owners and conventions

[`systems/camera_controller.gd`](../../../systems/camera_controller.gd)57..73
reads `GameCamera.state.position` as native XYZ and `state.quaternion` as
native WXYZ, then publishes:

```gdscript
position_godot = Vector3(native_x, native_z, -native_y)
basis_godot = Basis(Quaternion(Vector3.RIGHT, -PI/2)
    * Quaternion(native_qx, native_qy, native_qz, native_qw))
```

That camera-local convention is not an object-geometry quaternion axis swap.
The boundary preserves the native source values. It reconstructs this exact
presentation transform only to prove that no later camera writer superseded
them. It does not extract or renormalize the native quaternion from a Godot
basis. Native source q values therefore retain their original f32 bits.

The reviewed62f54 engine's Camera3D constructor enables `disable_scale`
(`scene/3d/camera_3d.cpp`871..878). Node3D normalizes the global basis when
resolving it (`node_3d.cpp`648..674); Camera3D normalizes once more in
`_get_adjusted_camera_transform` before render submission
(`camera_3d.cpp`265..279). The guard models these exact two operations, without
a tolerance. The earlier overly strict unnormalized guard and failed receipts
remain retained in v2..v4; v1 retains its test-alias parse failure.

[`camera_fov_binding.gd`](../ui/camera_fov_binding.gd) applies vertical
`KEEP_HEIGHT` on a new camera and explicit settings changes. A repeated bind
of the same Camera3D preserves later authored/script FOV. The boundary reads
the **current camera FOV**, never the saved preference or a repeated default.
The retained native default45-degree construction proof is in
[`ui/README.md`](../ui/README.md). Settings slider limits20..120 are client UI
policy; they do not make missing original tangent words available.

The engine's diagnostic `Camera3D.get_camera_projection()` uses visible_rect.
`Viewport.get_visible_rect()` can instead report a2D size override. Actual
`RendererSceneCull.render_camera` uses renderer `internal_size`
(`renderer_scene_cull.cpp`2696..2733), supplied by
`RendererViewport::_configure_3d_render_buffers`
(`renderer_viewport.cpp`224..279,332). The boundary accepts only the exact
common case: main Window or SubViewport, positive size≤16384 per dimension,
3D scale1, bilinear/nearest mode, identical physical/visible/texture sizes,
identity stretch, no TAA or XR. Aspect is f32(width/height) of that verified
effective size. This restriction avoids silently calling a stretched visible
rectangle the final raster aspect. No projection matrix or Godot frustum is
used as native math authority.

[`native_client_clock_runtime.gd`](../../../systems/native_client_clock_runtime.gd)109
delegates to actual `ClientClockServices.reveal_timing(current_frame)`.
[`client_clock_services.gd`](../../../systems/native_data/client_clock_services.gd)368
reads the existing primary world timer's `snapshot_difference()` and exposes
`snapshot_words:{hi,lo}` with source `native-primary-world-snapshot-v1`.
The boundary consumes that DTO, exact frame and scope; it neither accesses
private timer fields nor samples `NativeClockSource`. The test alone supplies
a controlled integer provider to the real clock services. It makes exactly
three constructor and three prefix reads; all boundary captures and
revalidations leave that count6 unchanged.

The existing timing API is also a fade carrier, so it explicitly rejects a
snapshot with high-word signbit set. Native renderer low32 math itself has no
such restriction. The boundary reports `primary_words` unavailable for that
case; future direct full-word source publication requires its own source-owner
change. No float cast or unsigned64 truncation repairs it here.

## Actual current frame order and recommended future hook

There is **no existing proven final-camera collector callback site**.

1. `NativeLiveWorld.run` connects `SceneTree.process_frame` to `tick` at131.
   The reviewed engine emits process_frame **before** Node `_process` callbacks
   (`scene_tree.cpp`713..719).
2. In `NativeLiveWorld._profile_tick`,424 calls native clock prefix, then
   protocol receive completes. At451 `native_clock_post_receive()` finishes
   clock AI; `NativeSessionWorld`60..62 also advances the current visibility
   runtime here. This is **before** camera follow.
3. The root calls `controller.follow_frame` at481 and records camera-after
   at483. It uses the currently published controlled actor presentation pose.
   Root `frame:end` at497 is still inside process_frame, before Node processing.
4. Normal World `_profile_process` later updates motion at
   `systems/native_render/live_world.gd`441 and applies adopted/presented state.
   Current follow is not moved or reordered by this helper.
5. `AreaEnvironment._profile_process`129..131 independently calls `advance`
   and weather. `advance` reads camera.near and current follow distance to
   compute fog range, then can write **camera.far** at175. This can invalidate
   a projection captured at root camera-after/frame:end. The child creation
   order is not an explicit enduring collection-phase contract.

Recommended next shared hook: a **world-owned frame-tail method**, invoked
only after the existing motion/presentation pass, the intended camera-follow
publication and one explicit environment/fog-range update have completed for
the admitted world/camera. Split out or own the existing environment callback
so its elapsed-time/weather update still executes exactly once; do not call
`advance` again merely to refresh camera.far. Call this adapter there,
synchronously, and call the native collector between its before/after guards.
The root's existing camera-after line483 is a useful source marker but becomes
an admissible site only after that environment/final-pose ownership is made
explicit. `native_clock_post_receive`451 is too early. No source hook is
installed by this checkpoint.

The future guard must certify the actual accepted connection/world object,
generation/area, nonclosing/nonretiring state, exact main physical camera and
the **owned collection occurrence**, not just Engine frame equality. A generic
process signal, `frame_pre_draw`, frame number or portrait-camera render does
not prove this native per-view collection occurrence. Multiple collections
within one frame require explicit occurrence identity; fog callbacks preserve
their multiplicity. Live original scheduling/viewport acceptance remains open.
The primary snapshot owner remains the existing prefix throughout; environment
or camera delta must never replace collector renderer DeltaT.

## Adapter interface and source lease

```gdscript
boundary.bind(camera, controller, native_clock_runtime,
    {"connection": connection, "generation": generation,
     "area_id": area_id, "world_id": world.get_instance_id()},
    owned_collection_guard, loaded_original_sse_tangents)

# Guard signature: (detached_scope, frame, collection_occurrence) -> bool
# Must close over the actual current source owner, not trust caller DTO facts.
var result = boundary.collect(scope, frame, collection_occurrence,
    bsp_adapter.collect_camera)
```

The collector gets exactly its frozen API:
`collect_camera(scope, camera, primary_words)`, where camera contains native
`position`, `quaternion_wxyz`, vertical `angle`, effective `aspect`, `near`,
`far`, `half_tangent_angle_word`, and `half_tangent_word`. No scene objects enter
the POD kernel. The boundary's `delta_t_word` receipt is diagnostic; the frozen
kernel performs the exact original low32 conversion itself from the words.

For separate capture/dispatch, `capture` returns a detached latest-only receipt
with camera/viewport/follow/clock/service identity, source scope, frame,
collection and revision. `current(receipt)` revalidates before and after the
collector; `collect` performs that sequence automatically. New captures/rebind,
reentrant calls, owner replacement, queued deletion, viewport reparent, FOV,
clip, pose, resize, primary snapshot replacement and reconnect invalidate old
receipts. Both snapshot words are fenced even if only high32 changes and the
renderer DeltaT is identical. Stale caller retirement cannot acquire a new
owner's source state. There is one retained receipt, with no frame history.

The guard is external authority; a fabricated always-true guard is not live
source acceptance. The same requirement already exists in the frozen
`bsp_collector_kernel.gd` scope guard. The visibility agent confirmed that no
additional stamp enters kernel math: the boundary lease stays outside its POD
arguments and surrounds its synchronous call.

## Explicit unavailable inputs and proof limits

* No exact owned final collection phase: boundary guard must reject.
* No native follow source, stale final transform, pending deletion, recreated
  controller/follow/camera/clock services or stale world scope: unavailable.
* Camera offset, physics interpolation, off-axis frustum, horizontal-FOV mode,
  scaled/overridden/stretched/temporal/XR viewport: unavailable. Their effective
  render pose/aspect needs a separately proved lower.
* Engine centered orthographic camera: unavailable. Native orthographic planes
  are anchored0..scale; native camera+4cc follows effective viewport height*.01.
  The frozen collector supports explicit native orthographic inputs, but this
  gameplay-camera source does not establish them by reading Camera3D.size.
* Missing45/90 original-SSE tangent authority or an unproved original FMA
  branch: unavailable for that branch/angle. The helper never computes tan.
* Disabled/unready native clocks, stale frame/phase/transport, malformed words
  or the current signed63 carrier limitation: unavailable.

The fixture exercises real CameraController/GameCamera, FOV Binding,
NativeClientClockRuntime and ClientClockServices with an explicitly authored
accepted scope and integer-clock source. It tests ten executed original-SSE
camera records through the unchanged math interface, native field preservation,
main Window/SubViewport, two resized aspects, same-frame reentry, source
recreation, late far changes and signed-low/high-word cases. Its collector
callback is an explicit detached-POD test sink, not a newly activated live BSP
collector. No original live client, final render scheduler, GPU output, server,
FPS or native build is exercised.

Run a new isolated receipt with:

```powershell
node tools/native_parity/visibility/camera_check.mjs native-camera-boundary-next stage
node tools/native_parity/visibility/camera_check.mjs native-camera-boundary-next run
```

Use a fresh lowercase label. The runner stages41 pinned source/corpus/config
files, pins13 read-only frame/native/engine source facts, and launches the
already-reviewed62f54 engine headlessly with isolated userdata. On this Windows
host that existing engine needs certificate-store read permission even for a
headless CPU check. Existing failed and successful receipts are preserved.
The original first version is backed up at
`loading-agent/camera-boundary-before-fix-v1`; every later staged version also
retains its exact before bytes. All new source/proof pins are in
`loading-agent/camera-boundary-source-pins-v1.json`.

Claddath highlight visual parity remains open. This camera work neither caps
its native rays nor changes highlight, alpha, source material or any capsule.
