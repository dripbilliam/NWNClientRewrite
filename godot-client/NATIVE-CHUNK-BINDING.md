# Automatic native chunk assets and live model publication

Status: automatic binding and live publication implemented in the default native
path; scoped GPU/local/capture checks pass. Full effects, playability/performance
acceptance and the broader binary-guided goal remain incomplete.

## Original methods and limits

Immutable NWN:EE89.8193.37-17 x64 nwmain.exe SHA256:
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original binaries/assets/Ghidra are unchanged.

The110 bounded original chunk lifecycle/draw traces and explicit lower-provider
boundaries remain in NATIVE-PARTICLE-CHUNKS.md. Fresh complete
PartEmitter::Initialize140061d80..1400621ea confirms that a nonempty chunk name
selects RenderNothing, after the normal render-mode selection. It still loads
its Material separately; the name does not imply that a quad bitmap substitutes
for the chunk model. Derived complete views:
`backups/animations/rea-particle-chunk-dispatch-initialize-v1.json`.

FindModel140098cd0 has an explicit case-insensitive NULL early return without
model search/read. Existing full unchanged-function80-case oracle
`native-world-model-cache-v1.json` includes both NULL and null with empty call
traces and no model. A nonempty NULL chunk therefore still selects the chunk
simulation/render owner, with a null child model; it must not request null.mdl
or fabricate a quad. ChunkyParticle's mapped constructor/initialize tolerate
that null child. This is a general original model sentinel, not a server rule.

The asynchronous Godot bundle binding/readiness/cancellation policy below is our
adapter design around those boundaries. It is not a claimed reconstruction of
every original global resource/draw/scene scheduler.

## Native resource and model ownership

`chunk_models.gd` binds each emitter to the world's native reference resource
owner. `reference_assets.gd` now supports prepared-bundle listeners alongside
ordinary model references, sharing the existing native worker jobs and bounded
prepared-data cache. Particle allocation creates a private native Actor/rig,
using the unchanged prepared model, textures and immutable pooled meshes.
Original source names survive both PackedScene and actor/equipment assembly;
they participate in emitter-bearing template identities for cycle checks.

Native model services handle scene attach/detach, source scale, impact playback,
world position/orientation and destruction. Source retirement drops its bundle
reference without clearing a shared cached Dictionary. Native NULL bindings
perform no resource job and retain no child model. Missing actual resources and
resource cycles/depth remain explicit diagnostics, with no replacement geometry.
The16-level/cycle bound is an adapter limit, not proven original cycle policy.

No simulation births occur while the native bundle is pending. Chunk preparation
and references nested below chunk models are marked optional visual work for
player control; ordinary required model references retain their readiness gate.
Global completion still observes pending jobs/publications. Cancelling the last
unstarted listener removes its queued work. An in-flight job keeps its empty
listener set so a replacement can join it without a duplicate submission; only
current weak-reference/generation listeners receive publication. World retirement
still owns and joins the shared asset workers safely.

## Live admission lifetime correction

The old live stream path activated model emitters/references under a batch node,
then used in-tree `reparent` during world adoption. Actual Godot calls their
`_exit_tree`, retiring those runtime owners; `_ready` does not run again merely
because the model reenters. The captured-room path did not make that handoff,
which explains why its working particles did not establish live parity.

Live object and creature streams now accept a final `admission_parent`. They
attach hidden complete instances directly to the world, then ordinary adoption
applies the latest authoritative pose and reveals them without another tree
exit. Actor installation retains an in-tree parent for existing global held-part
pose operations. Batch completion transfers bookkeeping ownership; it cannot
retire an adopted model's effects. Standalone/captured streams retain their
existing parent behavior. Stale/failed pending instances are still retired.

## Scoped verification

- `native-chunk-binding-v4`:31 GPU checks using actual native workers and raw
  authored models. Two emitters share one chunk job, keep private rigs/poses,
  recycle two models each for12 impact plays/ten detaches across96 simulation
  steps. Nested references share one further job. Checks required versus optional
  readiness, cached-data isolation, actor route, native NULL, cycles/missing
  resources, pending publication cancel, unstarted cancel and a replacement
  listener while an actual worker is held at a declared read boundary.
- `native-world-publication-v3`:ten checks through actual static/actor stream
  publication and live-world adoption. Both effects remain active and allocate
  their private chunk model after batch close, with referenced models present.
  An actual in-tree reparent control reproduces the previous retirement. The
  actor plan/terrain readiness are authored boundaries in this fixture.
- `native-chunk-binding-final-owners-v1`:119 original-owner/coupled GPU checks;
  `...final-references-v1`:147 original/authored reference GPU checks;
  `...final-retirement-v1`:72 actual delayed-worker/overflow checks;
  `...final-templates-v1`:16 shared-template/private-instance GPU checks.
- `native-session-chunk-binding-v3`:actual default native launcher on owned local
  Prelude. Player ready1434.493 ms, authoritative/native movement while18/19
  entities and one batch remain, final20 entities/nine tiles, acknowledged finish,
  workers0 and clean exit. Two emitters have simulation frames;55 remain diagnosed
  failures (17 point-wind,32 scene-intersection,six integer-range). They were
  previously masked by immediate retirement. This is not complete live effects.
- `native-capture-chunk-binding-v2`:the original captured raw room prepares48
  tiles,889 static objects,eight animated creatures and one item with workers0.
  Native clocks/skin deltas advance; screenshot inspected. This is final snapshot
  plus native animation, not full moving protocol replay.1351 emitters retain
  1182 failures:472 point-wind,596 intersection,ten wind and104 cloud bitmap.
  No chunk bundle was requested in this room: its chunk sources require other
  scene services first. It validates compatibility, not live chunk activation.

Accepted runs use normal-heap CDB, four traps, unchanged sources and no trapped
native or engine/lifetime error. Initial binding v1 failed on an untyped report
variable; publication v1 failed because60 uncapped frames were too short for the
first scheduled birth. Retained failures, not promoted into passes. Final tests
observe actual births/ownership. Pre-publication-fix local and capture reports
are historical source pins, not final current runs.

Capture preparation11532 ms;179 settled intervals mean19.763 ms,p9520.643,
worst21.743 with no>50 ms samples. Loading852 intervals mean12.266 ms,p9526.509,
worst49.194. Editor1776 is preserved; this is not a controlled/cold-warm comparison
or complete-scene60 FPS acceptance. Captured particle CPU remains costly.
Follow-up: [NATIVE-PARTICLE-SPAWN-WORD.md](NATIVE-PARTICLE-SPAWN-WORD.md) corrects
the six Prelude unsigned-spawn-word failures with original-code evidence.
The measurements above retain their historical checkpoint/source scope.
No public connections occurred. Scene wind/intersections/point-wind, other
provider gaps, complete fade/tint/order, repeated real transitions/reconnects,
native culling/resource priorities, full JS migration and the final wiki remain
unfinished. Continue BINARY-WORLD-STREAMING-GOAL.md.
