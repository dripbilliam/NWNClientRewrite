# Area-layer retirement candidate — written, not executed

2026-10-27. No production import, default rendering/loading change or performance
acceptance. User is recording gameplay in `native-session-1793144729828`; do not
run this probe or another competing renderer until that session is available.

## Why this candidate

The completed native report for the earlier manual session
`native-session-1793142869178.native.json` records seven retired worlds, zero
forced drains, no retained worlds/workers, max begin19.141ms, max hide15.490ms
and max processing-disable3.344ms. Maxima may come from different transitions;
do not add them as one measured frame. These are a new session, not a matched
before/after against the earlier35–36ms dense-scene combined boundary.

Its native completion succeeds, but the protocol-host report correctly fails
`sourceUnchanged` because the authorized next-build inspector/type fix changed
disk sources while the old process still used loaded scripts. Preserve that
failure; it is historical evidence from the launched checkpoint, not acceptance
of the edited current source. No automated public connection was performed.

Installed engine hash ed1daf0bf001b61586d9930840f2f1394092c079:

- Node3D::hide/set_visible invokes `_propagate_visibility_changed`, which visits
  visible Node3D descendants. It is not one constant-cost area visibility bit.
  [Matched node_3d.cpp](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/scene/3d/node_3d.cpp#L1004)
- Node::set_process_mode propagates owner/paused/disabled notifications through
  inherited children. The candidate keeps this synchronous path, which existing
  physics regressions require to remove old bodies before another frame.
  [Matched node.cpp](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/scene/main/node.cpp#L624)
- Camera cull-mask assignment changes a camera field. Main culling checks visual
  layers for geometry/positional lights and separately for directional lights.
  Shadow candidates also intersect camera and shadow-caster masks. Geometry-light
  membership has its own light mask: camera filtering alone is not a complete
  guarantee that retained old lights cannot affect new geometry.
  [Matched renderer_scene_cull.cpp](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/renderer_scene_cull.cpp#L116)
  [Culling and light membership](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/renderer_scene_cull.cpp#L2656)
  [Shadow membership](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/renderer_scene_cull.cpp#L2212)

This supports an experiment, not a measured win. Original NWN's saved area
cleanup dossier `../backups/animations/rea-world-area-retirement-v1.json`
(FUN_1407e7770..0x1407e7cf1, pinned nwmain SHA256
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a)
enumerates objects and calls deletion/cleanup helpers. It does not establish
constant-time native teardown, identify GPU waits, or prove this layer method
is what the original uses. Do not label the candidate native-method parity.

## Written prototype

`experiments/area_layer_scope.gd` remaps the two known original geometry layers
into a private two-bit lane per area. It also remaps light inclusion and shadow
caster masks, preserves the caller's separately retained original camera mask,
and stores reversible private property bindings. Bind/admit validates the whole
requested branch before mutation and rejects unknown layers or visual types.
Late visuals require explicit admission. There is no automatic production hook.

Once prepared, an active-camera mask switch can exclude the old area without
calling its root hide. Processing disable still happens synchronously. Shared
mesh/material resources and original geometry/textures are not changed; only
per-instance properties are experimental. Scope lifetime/lane reuse must remain
bounded until all old visuals are actually destroyed. This prototype does not
yet implement a production lane allocator or cancellation/worker ownership.

`experiments/area_layer_scope_probe.gd` is a **graphical test queued for later**:

- Exact authored pixels: baseline old-root hide versus retained old geometry,
  old green light, new light and old/new shadow casters with area masks.
- Preserve an original layer2 mesh, layer-restricted light and camera exclusion
  of layer2, rather than merging both original layers into one membership bit.
- Keep old physics removed immediately through inherited processing disable.
- Verify late admission, reject an unsupported original layer without mutation,
  and restore private geometry/light/processing state.
- Record the initial full-tree mask setup separately from transition operations;
  readback/correctness screenshots are not steady-frame performance samples.
  A wrapper-heavy authored hierarchy is not representative captured content.

No execution receipt exists yet. Before any run, review parser/API assumptions
and exact default-mask values against the installed build. Fix failures rather
than weakening pixel/physics assertions. A successful authored fixture would
only justify an opt-in captured-world integration, not default promotion.

## Remaining acceptance and risks

Retained visible-but-layer-excluded instances remain in engine scene/spatial
structures until retirement frees them. The saved hide call may be traded for
more culling/shadow-query work during the following frames. Measure transition
wall time and the entire bounded retirement interval; do not accept one quicker
setter while p95/p99 or steady costs get worse. Include first setup/admission,
memory and shader/pipeline changes in cold/warm comparisons.

Production would need every publication path (tiles, actors, private parts,
references, effects/particles, lights and late attachments), selection behavior,
all active camera policies and original layer semantics covered. Unsupported
instances, custom ignore-all-culling flags, GI/probes/decals, shaders reading
layer masks and unregistered late descendants require compatible handling.
No required object may disappear to make the comparison pass. Old audio/input,
registry isolation, queued worker rejection and exact lifetime joins must remain.

After authored correctness, use same-source/pinned-runtime captured areas and
owned Prelude transitions with matched views/settings, focused/unfocused policy,
repeated/order-reversed runs and no competing game. Preserve full error gates.
If a drastic default candidate earns acceptance, prepare a verified rollback,
reviewable comparisons and limitations and **ask the user before promotion**.

Production remains at `native-entity-inspector-body-flags-v1.zip` for the current
live test. The unrun candidate must not be represented as an improvement already
included in that client.
