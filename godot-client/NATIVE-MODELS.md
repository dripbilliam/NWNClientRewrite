# Native model animation milestone

Status: **partial model migration, not complete gameplay or rendering parity**.
The normal client is preserved. Owned local Prelude and authored fixtures
are the live validation targets; no Arelith connection is used.

Follow-up: [NATIVE-WORLD-LIFECYCLE.md](NATIVE-WORLD-LIFECYCLE.md) records live
spawn, shape/clothing replacement and removal, including atomic native adoption,
cleanup, local server evidence and remaining loading costs. Historical checks
below concern the initial animation milestone.

The local staging bundle transfers original physical node hierarchy, poses,
animation controllers, skin vertices, UVs, weights, sparse bone slots and
inverse references alongside the external GLB. Existing body/robe/equipment
assembly is retained. Clip data is shared by source asset; rest overrides
remain per instance. Meshes/textures are not replaced with proxy assets.

`tools/export-rigs.mjs` reads those owners once during staging.
`systems/model_rigs.gd` builds native nodes, AnimationPlayers and Skeleton3D/Skin
resources. Godot owns playback and GPU deformation. The hidden Three frame
loop stops after transfer. JS sends authoritative object poses and animation
codes, not per-frame deformed vertices.

Position/quaternion/scale channels preserve source basis conversion. Bezier
knots and relative handles use native Bezier tracks with one-third interval
time handles; they are not resampled. Constant keys reset channels missing
from a subsequent clip, matching the source animator's reset behavior.
These APIs are described in [Godot Animation](https://docs.godotengine.org/en/stable/classes/class_animation.html).

Held/worn roots copy their anchor's global position/quaternion while keeping
their own scale. This preserves the source's scene-sibling attachment behavior.
Body and robe followers receive replicated locomotion; independent item clips
keep their own clocks. Clip names and loop categories reuse existing NWN rules.

Skins retain sparse slot order, second-root termination, repeated inverse
composition, ignored nonpositive weights, unnormalized totals and zero-weight
vertex fallback. Node scale stays outside the rigid bone palette, matching
the existing native-derived source implementation. A separate identity bind
implements only the unweighted fallback. Godot's packed weights introduce
small precision differences. Individual positive weights above one still
need an adapter and fail explicitly instead of being silently normalized.

Rigid picking geometry follows its node. Removal/reappearance also disables
and restores nested colliders after reparenting. Skinned picking triangles
remain at the captured pose; precise animated bounds are pending. Rendering
uses a conservative skin AABB to avoid clipping normal motion.

## Validation

- **33 Node checks pass**, including eight new rig/dispatch cases plus existing
  asset transfer, framing, lobby and stale-input regressions.
- `reports/model-rigs-gpu-v4.json`: **64 passing native checks** against a
  separate oracle using the existing JS pose/native skin arithmetic. Authored
  triangle/box data only. Covers sparse/zero/nonunit skin weights, quaternion
  basis, ignored bone scale, original Bezier position/scale curves, clip resets,
  held-item scale, and nested-collider removal/reappearance. Maximum GPU skin
  position error: `0.0000169094765`; maximum rigid error: `0.000000357628`.
- `reports/native-model-rigs-local-v2.json`: actual Prelude with 375 meshes,
  3 rigged entities, 243 nodes, 5 animation players, 528 source clips, 33 rigid
  meshes and a 1,428-vertex robe skin. Observed native import/setup: 883.528 ms;
  one functional run, not a repeated loading benchmark. The failed first
  scene-sibling attachment transfer remains in `native-model-rigs-local-v1.json`.
- `reports/native-model-rigs-local-v3.json`: server code 4 requests `run` and
  both controlled body and robe actually play `run`. The NPC plays `pause1`.
  Missing requested clips: zero in this check.
- `reports/native-model-rigs-lifecycle-v2.json`: final source build passes two
  real admissions with export/save/read-back/reconnect/close. Both sessions
  change 72 local parts; robe-local GPU vertex deltas are 0.391/0.393 units,
  independently of whole-character translation. Saved BIC read-back matches.
  Native exit 0, explicit disconnect, no renderer errors or missing requested
  clips. Uses a separate external test vault.
- `reports/native-model-rigs-local-v4.json`: the original-handle Bezier build
  passes native movement/chat/camera/skin checks. Its final pose has returned
  to `pause1`; v3 is the evidence for an active during-movement `run` clip.

GPU bake/read-back is confined to explicit regression probes. Production
animation performs none. The probe method stalls the renderer, as documented
by [Godot MeshInstance3D](https://docs.godotengine.org/en/stable/classes/class_meshinstance3d.html#class-meshinstance3d-method-bake-mesh-from-current-skeleton-pose).
Probe timings/FPS cannot establish performance acceptance.

The final data build is `.cache/local-bridge/v8`, launched by `join-local.ps1`.
`run.ps1`'s older offline GLBs remain the frozen import path and do not prove
animated captured-room acceptance.

## Remaining work

Animation events, combat queues/blends, alpha/self-illumination/light/emitter
controllers, particles, moving model lights, specialized reference behavior,
exact skin picking/bounds and uncommon weight/transform cases are incomplete.
Missing inherited clip targets which the source animator also ignores remain
explicit diagnostics rather than invented physical nodes.

Late spawns and same-area equipment/shape replacement need native content
lifecycle updates. Area changes currently rebuild the transferred world.
Mounted/custom forms are not accepted merely because their original assembly
is retained. Full moving captured-world fidelity/performance and remaining
multiplayer/gameplay interfaces still require migration.
