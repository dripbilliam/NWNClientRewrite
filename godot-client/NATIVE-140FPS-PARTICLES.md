# Particle work for the 140 FPS goal

This investigation owns private particle experiments. **No candidate described
here is promoted to the ordinary renderer, and no new FPS result is claimed.**
The actual simulation is a small part of the most recent dense room's particle
callback. Existing detailed timings put that callback near 5.2 ms, with actual
simulation below 1 ms. Eligibility, controls, clock callbacks and pose work
around it remain substantial. See
[the overall performance goal](NATIVE-140FPS-PERFORMANCE-GOAL.md) and
[ordinary pose conversion reuse](NATIVE-PARTICLE-POSE-REUSE.md).

## Synchronous pose read sharing candidate

`frame-pose-epochs-v2` shares the pose read for a full 64-bit engine ObjectID
only inside one synchronous presentation call, between arbitrary callback
boundaries. The existing emitter owners still own their simulation and their
individual conversion caches. The presentation owner holds small detached
pose values; it holds no additional live Node pointers.

Every pose request still resolves and type-checks the live ObjectID. A cache
hit avoids the repeated engine Transform3D getter and conversion. A new native
presentation call advances the epoch even if it occurs in the same Godot
frame. Every arbitrary external service, readiness, clock and fallback callback
suspends sharing and invalidates both before and after its invocation, including
exception unwinding. Native-only arithmetic/services do not invalidate it.
Thus a callback cannot move, reparent or remove a source and leave a stale pose
for a later emitter. Cache entries contain finite converted poses only.

Entry removal evicts its pose/source IDs; closing the presentation owner clears
all entries, including after a failed frame. Full engine lifetime IDs are
retained rather than truncating them. The new `reuseFramePose:false` native
owner configuration preserves the ordinary per-owner path as a same-DLL
oracle. It does not select a different renderer. Cold presentation inspection
adds `frame_pose_reuse` hit/read/invalidation/retained counts. Existing individual
conversion diagnostics naturally count fewer conversions under sharing.

The invariant depends on the existing main-thread SceneTree ownership: the
scene cannot change concurrently during a callback-free native interval. It
does not cache visibility, eligibility or data across presentation calls. It
does not skip simulation, effects, RNG draws, culling, lifetime checks, lighting
or geometry, and introduces no thread.

## Correctness and isolation

The private DLL compiled with MSVC 14.50.35717, `/O2 /fp:strict /W4 /WX`.
The pure C++ cache test passed **160,018 checks**. The isolated Godot 4.7.2
headless suite passed **27,300 checks**, with clean exits and logs:

| Native suite | Checks |
| --- | ---: |
| Synchronous pose sharing SceneTree oracle | 4,613 |
| Existing per-owner conversion cache | 1,809 |
| Existing typed pose/state/geometry | 1,927 |
| Existing presentation/state/geometry | 6,871 |
| Existing presentation lifecycle | 12,080 |

The new SceneTree oracle has real scheduled owners before and after particle
presentation. It changes local and parent transforms, reparents sources, tests
nonuniform/reflected scale, hides/shows ancestors, disables processing, mutates
the shared source from random/fallback/readiness/clock callbacks, removes a
source during a clock callback and checks close retirement. It runs two complete
presentation calls within one engine frame with another owner's mutation
between them. Both modes produce byte-identical geometry, native particle
state, admission/counts and RNG ordering. It observes 1,142 shared reads from
3,708 total requests in this deliberately mutation-heavy fixture. This ratio
does not predict live-room savings.

An earlier sandboxed headless run passed its 2,331 checks but its log reported
failure to read Windows' root certificate store. Its receipt remains failed;
the final isolated rerun outside that sandbox has clean logs. No server, game
session or graphical test was used. Ordinary native output guards stayed
unchanged, as did all frozen candidate and copied regression sources.

## Reproduction and handoff

Everything below is relative to `godot-client/`:

- Frozen baseline/candidate, prebuild pins, build logs and finalized pins:
  `.cache/native-140fps/particles-agent/frame-pose-epochs-v2/`
- Regression result and individually sealed test/log outputs:
  `.cache/native-140fps/particles-agent/checks/frame-pose-regression-v2/`
- Reusable tools and the standalone source cache helper:
  `tools/perf140/particles/`
- Dedicated SceneTree test:
  `tests/native_perf140_particle_frame_pose_test.gd`
- Reviewable source changes against the frozen parent:
  `.cache/native-140fps/particles-agent/frame-pose-epochs-v2/candidate-corrected.patch`

Final private DLL SHA-256:
`73ad152f06727b5f6e621a47f9513d2e17ba3e20708773ff74eefe46f3548bc7`.
Finalized source receipt SHA-256:
`0030c11533abd5ad5d9a4d68a3c9fb10f5b6c2a82c79a1d273360299a3d6b9f6`.
Its 2,599 pins include the pre-existing unpromoted light-input v3 candidate;
compare against the paired baseline, not an unrelated ordinary build.
The parent renderer and all overrides/hashes are recorded in that receipt.
The corrected patch SHA-256 is
`45cf3c448bb64bcc992709a8d1ad0802d12d1fe2dccc8b6666b67016946b536b`.
Applying it to a separate baseline copy with
`git -c core.autocrlf=false -c core.eol=lf apply` reproduces all four overridden
source byte hashes exactly (`patch-readback-lf.json`). A prior readback using
the workspace's default CRLF conversion is retained separately; its text
matches but its byte hashes differ. The earlier `candidate.patch` export is
superseded by `candidate-corrected.patch`.

For a fresh frozen candidate, run from the workspace root:

```powershell
node godot-client/tools/perf140/particles/prepare.mjs <fresh-label> <pinned-overlay-json>
& ./godot-client/tools/perf140/particles/build.ps1 -Label <fresh-label>
node godot-client/tools/perf140/particles/finalize.mjs <fresh-label>
node godot-client/tools/perf140/particles/check.mjs <fresh-label> <fresh-test-label>
node godot-client/tools/perf140/particles/make_patch.mjs <fresh-label>
```

Tools preserve existing experiment labels, verify sources before copying and
compiling, retain failed evidence, and build only private DLLs. The headless
runner copies the frozen candidate, replaces its project configuration with a
minimal no-autoload test project, uses isolated user-data directories and waits
for process closure. It does not start a graphical or server session.

Root schedules captured-scene graphics comparisons and local gameplay
acceptance. A material stable frame-time gain, unchanged view/workload and
unchanged effects are still required before integration. This candidate alone
is not expected to reach 140 FPS.

## Further duplicated work identified

The native presentation residual still includes a full emitter identity lookup,
type check and three eligibility engine calls, a separate source validity
lookup, repeated common `animating` dictionary access, per-entry controls and
EngineVar copies, and another ordered lookup during counter publication.
Only animated actor emitters use `ModelRigs.playback_state` callbacks; static
emitters already use native elapsed clocks. Do not attribute all residual work
to clocks. Per-emitter RNG requests still cross to the shared GDScript visual
stream, and cosine services can cross to GDScript. Replacing that shared owner
would require preserving the exact global draw stream across both native and
fallback emitters; a private per-emitter generator would change effects.

Godot 4.7's [Node3D.is_visible_in_tree documentation](https://docs.godotengine.org/en/4.7/classes/class_node3d.html#class-node3d-method-is-visible-in-tree)
describes tree membership, but the inspected
[pinned ed1daf0bf source implementation](https://raw.githubusercontent.com/godotengine/godot/ed1daf0bf/scene/3d/node_3d.cpp)
only walks visible ancestors. **Keep the separate `is_inside_tree` gate.**
The earlier suggestion that it was redundant was based on documentation and
is withdrawn; the exact pinned source also lacks the membership test. Retaining
eligibility from a prior frame is much riskier because ancestor visibility and
processing can change without particle membership changes. A future retained
admission design needs observed invalidation hooks and the same mutation oracle;
it should not infer room occlusion or omit required effects.

## Independent intermediate Controls copy candidate

`controls-copy-v1` starts from the same frozen light-input v3 baseline and
changes only `native/particle_presentation.hpp`. It does **not** include
synchronous pose sharing. The existing loop copies `Entry.controls` into a
temporary, and then `Step.advance` copies that temporary into its own retained
`Step.controls`. The candidate references `Entry.controls` for the first stage,
keeping the second, pre-clear copy exactly where it was. All transient fields
are assigned before use on every attempted step. Pending patch and detonation
are still cleared only after successful advance; callbacks cannot change
presentation controls while a frame is running.

For an independent same-DLL oracle, `reuse_controls:false` registration/control
keeps the old temporary via `std::optional<Controls>`. The default path does not
construct it. Cold `entry_info` reports the chosen mode so the test cannot
silently compare the same branch twice. No per-frame diagnostic walk or
additional hot counters are introduced. The retained `Step.controls` continues
to own its strings and EngineVar patch after the entry's pending patch clears.

The focused `native_perf140_particle_controls_test.gd` passes **6,221 checks**;
the four existing native suites add **22,687**, totaling **28,908 clean checks**.
They cover positive/zero/negative/large deltas, mutable common input from a
fallback callback, callback observations of pending fields, static/actor clocks,
clock removal/restoration, malformed-clock failure/retry, failure after patch
application at the allocation guard, detonation, disable/re-enable, animation
and draw gates, exact native state/geometry/RNG and original reentrant mutation
rejection. The first fixture run lacked `addPointSourceWind`; its failed receipt
is preserved. The corrected fixture rerun is clean. No FPS result is claimed.

Artifacts:

- `.cache/native-140fps/particles-agent/controls-copy-v1/`
- `.cache/native-140fps/particles-agent/checks/controls-regression-v2/`
- Source: `b374b0beec4bd7327ec190472a535150aeb9551e3e7e367cb446eb8b69f09ba7`
- DLL: `bbcdc2e4059b996fc34aa2a9bc49f4d9e320b1121af3a28e2f503a4fc6e9b9e6`
- Finalized receipt:
  `d1bd5af6973ec8556ddb8ada820d91f4b27066a64299969a47411041c44b3e72`
- `candidate.patch`:
  `f2c2816a559d57851c3bd84059f26947ff33706251010585ce392727062e44d5`

Patch application to a separate private baseline copy reproduces the source
bytes exactly (`patch-readback-lf.json`). This experiment uses no shared native
outputs and has not been combined with or substituted for the pose candidate.

## Live typed-object proof audit

Godot's
[GDExtension implementation](https://raw.githubusercontent.com/godotengine/godot/4.7-stable/core/extension/gdextension_interface.cpp)
delegates full-ID resolution to ObjectDB, while the deprecated cast entry point
separately checks the native class ancestry. Its
[ObjectDB implementation](https://raw.githubusercontent.com/godotengine/godot/4.7-stable/core/object/object.h)
validates a slot plus 39-bit validator under a spinlock. This suggests a
separate optimization: retain a successful Node3D type proof keyed by full ID
and the numeric live wrapper address, but perform ObjectDB resolution on every
use. Reconfigure, null resolution or an address mismatch must invalidate or
recast the proof. Never dereference a saved address. Script replacement,
transform and parent/visibility changes do not change C++ Node3D ancestry.
The independently tested private candidate below implements this type proof;
the ordinary renderer still performs its existing casts.

Another avoidable boundary is the outer `::has` helper: it copies a Dictionary
Variant and dynamically invokes `has` through a temporary StringName and vector
of argument pointers. The per-entry `common.animating` check uses it every time.
A live keyed presence probe could remove this dispatch while still observing
same-frame callback changes. Hoisting that value out of the loop would miss
the existing mutable-input behavior tested above, so it is a separate change
with a different contract.

## Independent live common-input probe

`live-common-input-v1` replaces the per-entry dynamic `Dictionary.has` call plus
keyed read with one live keyed read of `common.animating`. The value is still
sampled separately for each entry: a fallback or clock callback can mutate the
shared input while presentation is running. `direct_animating:false` retains
the ordinary has/get path in the same DLL, and cold entry inspection confirms
the selected mode. There is no change to Controls copying, pose reuse, clock
advance, native truth conversion or missing-value behavior.

The paired live-input oracle passes **6,221 checks**, including absent values,
bool/integer/float truth conversion, same-call fallback mutation, clock and
allocation-guard failure/retry, pending patch/detonation observations, exact
state/geometry/RNG and rejected reentrant controls. The existing four native
suites add **22,687**, totaling **28,908 clean checks**. The refactored shared
fixture was also rerun independently against frozen `controls-copy-v1` and
still passes its 6,221 checks. Candidate sources, test copies and ordinary
native output guards remained unchanged.

Artifacts:

- `.cache/native-140fps/particles-agent/live-common-input-v1/`
- `.cache/native-140fps/particles-agent/checks/common-input-regression-v1/`
- Source: `c66ef7c878e3207891401cab751923038d37c14645149048577a4d40b22bdf99`
- DLL: `8a4791bc2c3020f075f9608388105d9f3afcc4ecf1943f3a8d8548cb81b4da75`
- Finalized receipt:
  `daf72d791f31af84f7a7e99ef212f235204095c1a84e308cf8eae8c1b5208481`
- Patch: `fb8c746a408eccca08a82e8319f26581c9a77a3b39543561af96a19e281af9b4`

Its patch reproduces the source bytes in a separate private baseline copy.
Graphics/FPS acceptance remains root-owned and pending.

## New captured-scene attribution and clock boundary

Root's clean instrumented common baseline
`reports/native-perf140-profile-a1.json` has 1,918 entities, 225 tiles and 240
settled profile samples. Mean particle callback is 4.820 ms, with 4.636 ms in
native presentation. Its measured native means are eligibility/setup/clocks
1.532 ms, pose 0.799, controls 0.453, admission 0.222, simulation 0.816, geometry
0.436, packing/sort 0.068 and counter/summary publication 0.258. These are
instrumented intervals, not unprofiled gains; the residual still includes
several operations rather than isolating clocks alone.

For static emitters, `Entry.elapsed` advances only after enabled, live tree
eligibility, source presence and readiness gates. Frustum rejection happens
later and still advances that clock. Hidden, disabled or paused entries do not
advance it. Separate part readiness, creation times and visibility can make
clocks diverge even when emitters share a model source. Replacing those clocks
with one source clock would therefore change the current flow unless those
conditions are represented explicitly. No source-clock grouping is implemented.

## Combined candidate correctness

`combined-particles-v1` combines the three independently validated reductions.
It passes **46,879 clean native checks**: 7,137 all-off/all-on comparisons,
4,613 scheduled SceneTree pose/callback/lifetime checks, 6,221 intermediate
Controls checks, 6,221 live-common input checks and 22,687 existing regressions.
The full ordinary oracle disables all three reductions together in the same
DLL, and the candidate must actually exercise source sharing. This tests
interaction between the changes rather than inferring joint correctness from
independent results. All independent parents remain frozen.

Artifacts:

- `.cache/native-140fps/particles-agent/combined-particles-v1/`
- `.cache/native-140fps/particles-agent/checks/combined-particles-regression-v1/`
- DLL: `7014b6cdaf51ad448a9f22d9a3201335c379f909f11129e71948bb925be06047`
- Finalized receipt:
  `6c89052f05db3a60e695858ba5937f4d7de1571bb60b29c93935018c30106a6d`
- Patch: `07c29b7f7b1a3363f33e3f6d2dfed56759363298900eb41daf70d20dc97f9311`

Patch application in a separate private baseline copy reproduces all four
overridden source hashes exactly. Ordinary native outputs stayed unchanged.
This is a correctness result; graphical performance and original-local gameplay
acceptance still belong to root and remain pending.

## Profile-only census derivative

`combined-particle-census-v1` adds profile-only counters to the existing native
entry walk. It passes **56,141 clean native checks**, including 9,262 census
partition/all-off-on checks and the preceding 46,879 checks. The counters split
registered/disabled/ineligible/eligible entries, missing sources/readiness,
actor and bounded/unbounded static clocks, empty/nonempty emitters, zero
birth/lifetime, paused/chunk/wind owners and geometry-producing emitters. They
also expose actual synchronous pose-cache hits, live reads and invalidations.
No extra world scan, admission rule, clock or simulation skip is added.

Values appear in profiled frame `phases` as `count_particle_native_*`. They are
diagnostic counts, not timings, and should be used to choose further work.

- Directory: `.cache/native-140fps/particles-agent/combined-particle-census-v1/`
- Tests: `.cache/native-140fps/particles-agent/checks/particle-census-regression-v1/`
- DLL: `a14e8bffaee9d22824a6c64440c13941e1f1d55a5a864d02cf6df48a6341a39a`
- Finalized receipt:
  `8e0733ad9680a8b1c3238e5eb1291e8582d49be0b2c783f9dce4df28cb184dae`
- Patch: `4f8c90e8fac3ac554f4526c85a93df660590a114e46549911472fe07a07b2210`

All four overridden source hashes reproduce exactly through private patch
readback. Root's subsequent clean instrumented capture is
`reports/native-perf140-particle-census-b1.json`: 1,829 eligible entries, no
disabled/ineligible/missing-source/readiness entries, 1,695 empty before and
after simulation, 134 nonempty and 103 geometry-producing owners. It records
7 actor clocks, 173 bounded static clocks, 1,649 unbounded clocks, 670 chunk
owners, 172 zero-birth, 140 zero-lifetime and 41 wind owners. Actual synchronous
sharing is about 866 hits versus 2,792 live reads with 363 invalidations/frame.
This makes actor-only reuse a narrow subset, not a credible cure for this room.

The native REA investigation separately found no zero-birth/empty-list shortcut
in the observed BSP collection or AnimateParticles wrapper: the wrapper still
updates transform/history before invoking the schedule. Consequently this
census does not authorize skipping empty emitters. Origins, schedules, selected
channels and admission need a cold classification first.

## Retained visibility boundary still requires proof

The pinned Node3D implementation signals a parent's visibility change before
recursing into descendants. A presentation called by an earlier parent-signal
listener can therefore run before a leaf's notification updates its retained
cache. Leaf `visibility_changed` alone is insufficient for universal exact
reuse. Tree lifecycle timing is another reason to retain the live membership
test, and processing eligibility should remain live until pause/process-mode
invalidation is independently established.

A possible limited design keeps live full-ID resolution, `is_inside_tree` and
`can_process`, retaining ancestor visibility only at a proven settled owner
boundary and falling back to live visibility during arbitrary callbacks and
reentrant execution. It needs a scheduled oracle that invokes presentation
inside visibility/tree signal propagation, not only after ordinary hide/show
calls return. No retained eligibility or empty-emitter skip is enabled.

The actual pinned 4.7.2 engine confirms both hazards in the six-check
`native_perf140_particle_notification_boundary_test.gd`: a detached Node3D can
return true for `is_visible_in_tree`, and parent hide/show listeners observe a
leaf's live visibility before its retained leaf signal cache updates. Proof is
retained in `checks/typed-object-proof-regression-v2/` below. No membership gate
was removed and no retained visibility was enabled.

## Independent typed-object proof candidate

`typed-object-proof-v1` retains every full-ID lookup and every tree-membership,
visibility, processing and pose read. It changes repeated native ancestry
checks after a successful matching full-ID/numeric-address proof. Saved numeric
addresses are compared only and never dereferenced. Failed/null validation
invalidates the witness; changed addresses or identities recast. The original
one-shot Owner.configure rejection and immediate initial type validation stay
intact. A failed initial configure can retry as in the original flow.

It passes **20,016 pure checks** and **29,124 clean native checks**, including
6,431 focused exact state/geometry/RNG and lifetime checks, the six engine
notification-boundary checks and the four existing suites. The focused oracle
also changes scripts/reparents, rejects a wrong native Node, tests rejected
reconfiguration and failed-initial-config retry, and frees a source before both
presentation and direct pose reads. The first oracle left type reuse enabled on
its fallback; that failed receipt is preserved. Corrected mode selection passes
and explicitly proves that the ordinary side performs no witness reuse.

Artifacts:

- Directory: `.cache/native-140fps/particles-agent/typed-object-proof-v1/`
- Tests: `.cache/native-140fps/particles-agent/checks/typed-object-proof-regression-v2/`
- DLL: `b643c84b088273943dd5cae4476278009621cf6091eac6bc1a5bff2770a47cfc`
- Finalized receipt:
  `0c2af9bb7ec277f77ec4edf2f6e96fbe85861da5f4687e165bee44decae0f889`
- Patch: `b90b962f2973e4f9a6e4e7513fdf634630095f6a08372da27f60580484268371`

All five source overrides reproduce byte-for-byte in private patch readback.
The ordinary native outputs and frozen candidates remain unchanged. No graphics
or FPS result is claimed, and this independent candidate is not combined with
the preceding three reductions.

## Explicit cold origin/classification export

`cold-particle-census-v2` adds an explicit `ParticleStreamGroup.cold_particle_census()`
method and native dispatch 13. It returns detached compact scalar rows and
joins origin resource, physical part and paths from existing weak members once.
It exports no particle pools and introduces no timer, automatic export, file
polling or per-frame scan. The root driver chooses invocation and serialization
outside acceptance windows:

```gdscript
var group = scope_root.get_meta("native_particle_stream_group")
var dump: Dictionary = group.cold_particle_census()
```

Rows distinguish native/fallback ownership, kind, flags, chunk name, current
birth/lifetime/detonation, active/free counts, clip totals and selected constant
channels, clock validity, pose/source IDs and last-step admission. Last-step
fields are explicitly labeled because disabled/unprepared entries may retain a
previous step. Unavailable weak metadata and never-prepared selected channels
remain null. Native reentrant mutation is guarded while the cold export runs.

It passes **43,753 clean native/GD checks**, including 9,316 cold export and
partition checks plus combined/scheduled/standard regressions. Exported row
mutation cannot change the native state, and snapshotting leaves RNG/state
unchanged. V1's tab/space parse failure is retained; V2 fixes the wrapper and
passes with clean logs. No graphical result is claimed for this derivative.

A later focused run adds explicit reentrancy assertions and passes **9,320
checks** (`checks/cold-particle-census-guard-v3/`). Calling the native export
from an in-progress clock callback is rejected without disturbing that frame;
the GD wrapper also rejects an export while running. The frozen candidate
source and DLL are unchanged by these additional tests.

- Directory: `.cache/native-140fps/particles-agent/cold-particle-census-v2/`
- Tests: `.cache/native-140fps/particles-agent/checks/cold-particle-census-regression-v2/`
- DLL: `870a58283fbb1ebb786582c6584783300d6d7fb7ce38e94427347eb73433fb8a`
- Finalized receipt:
  `4d3c1d3d9140b49aed6ce54e7eb9a6330a5ef66a647a40db3ffe84417b26e6eb`
- Patch: `4e77c3d25cb311c84ec87000d68a2a1f8be614a4248ae5295fb5dfa283c1e72d`

All five overrides reproduce exactly through private patch readback. Shared
native sources/outputs and the frozen parent experiments remain unchanged.

## Static constant-write design, awaiting cold evidence

The constant cache currently avoids interpolation but still copies a temporary
resident Var into parameter and state mirrors and performs generic compact
field application each time. A candidate could bind exact constant writes once:

- Keep first evaluation and validation on the existing path. After generic
  application succeeds, capture the exact finite typed member bytes and its
  stable compact Emitter destination. No new float arithmetic is required.
- On a cached constant, preserve finite-time checking, channel order and
  constant-hit accounting. Restore parameter/state mirrors if their exact
  scalar value or private cached-array identity differs. Restore compact bytes
  every time, including detonation consumed by simulation.
- Apply queued parameter/explicit patches and detonation in the original order.
  Switching clips restores that clip's own constants before later overrides.
- Dynamic, Bezier, malformed/nonfinite and unsupported field bindings retain the
  existing generic path. Do not infer unchanged compact state from its mirrored
  Var: compact detonation and other simulation fields can change without hot
  mirroring.
- Keep one native owner as the data owner. Bindings contain small constant bytes
  and addresses into that owner's stable private fields, not Nodes or another
  world/pose store. The original copy/apply path remains the paired oracle.

Tests would need scalar/vector/byte constants, clip switches, repeated fields,
signed zero/nonfinite fallback, dynamic channels, patches, consumed detonation,
failure/retry and exact state/geometry/RNG. This is **not implemented**. Cold
selected-channel counts may show that it is too small a subset to matter.

Actor controller reuse remains a separate parity investigation. Source building
uses the same original controller-node storage for native model Part plans and
for actor emitterTracks; the shared particle path samples channels again.
Only a matching native pose owner/part/clock/weight/offset witness could replace
that second sampling. Seven actor clocks in this captured room limit its value
as an FPS fix. Static pause/default, inherited/ASCII and blended ownership need
fallback until equivalence is established. No model_pose_storage.hpp change was
made here; root owns its independent publication experiment.

## Chunk admission: native evidence and remaining binding

The render/culling agent recovered `PartEmitter::CalculateRadius` at
`0x140061710`; full selected pseudocode, assembly and provenance are retained
in `tools/perf140/render/evidence/native-chunk-emitter-radius.json`.
`MdlNodeEmitter::InternalControl` runs the generic controller update before
calling this Part method.

The native radius first returns 1000 when the source model flag contains bit 1.
Otherwise it handles a target or computes the known lifetime, velocity, wind,
mass and sprite bound. It then walks the **current active particle list**: a
null particle view terminates the loop, and each available child Gob contributes
its current position's distance from the emitter plus its current radius.
Consequently an authored chunk mesh AABB alone is not a complete bound for
nonempty chunks. Our chunk bridge retains child ownership but has no direct
current child-Gob sphere binding; nonempty chunk culling stays on the existing
fallback.

An empty active chunk list contributes no child spheres, so the base radius is
complete for that case. This is a possible native-backed admission subset,
**not an empty-simulation shortcut**. It still needs exact source classification,
controller ordering, wind/scale/target handling and measured frustum rejection
counts. Cold origin summaries now distinguish empty chunks with a forced
1000-unit radius, other known source flags and unavailable source flags. No
chunk admission change is implemented or enabled.

The offline `summarize_cold.mjs` helper passes 35 synthetic partition checks in
`checks/cold-summary-oracle-1793882613736/checks.json`. They distinguish missing
values from zero, preserve different source flags within one origin and count
tile index 0 correctly. Tile instances created through `ModelTemplate.create()`
use an outer `Placement`; an emitter's source resolves to the inner packed root,
while `native_tile_index` lives on that root's parent. The optional cold join's
`source_parent_tile_index` therefore contributes to source classification. This
classification is evidence of placement, not proof of an immutable pose lease.

## Actual cold room and native shared visual RNG

Root exported `reports/native-perf140-cold-monitor-a1.observational-census.json`
outside the measured interval. Its post-measurement optional metadata reads
logged errors; root does **not** accept that run as a clean FPS benchmark. The
detached 1,829 native rows still give an explicitly observational classification:

- 1,695 empty / 134 nonempty emitters; 1,490 are dormant explosion emitters with
  zero active particles, zero detonation and no selected channels.
- All 670 chunk emitters are empty. None of the 1,829 source classifications
  forces the native 1000-unit bound. Their source flags are known.
- Only 150 entries, across 57 source roots, have direct Placement-parent tile
  metadata. Tile-only pose retention covers about 8 percent of this room.
- 1,772 have no selected channels; 33 have constant-only selected channels and
  24 have dynamic selected channels. Constant writes are not the main target.
- 1,656 have source classification 4 and no actor clock. Source inspection
  identifies a larger managed static-Placement opportunity, but metadata alone
  has not been promoted to an immutability claim.

The exact summary is retained in
`cold-summaries/actual-room-cold-v1.json` under the particle private cache. No
empty-emitter simulation shortcut was enabled. A source-only managed-Placement
lease plan and 23-case fixture are in
`tools/perf140/particles/managed_tile_pose_lease_plan.md` and
`tests/native_perf140_particle_tile_pose_lease_cases.gd`; that lease is not built.
Opaque actor clock callbacks would invalidate cross-frame reuse, so their typed
publication boundary remains an independent investigation.

`native-shared-random-v2` instead moves the existing world visual CRT stream
into `NwnVisualRandom`, selected **only** with `--particle-random=native` or
`NWN_PARTICLE_RANDOM=native`. `state`, `draws`, `seed_value()` and `next()` retain
the existing contract, including wind's seed/draw reconciliation. GD fallback
emitters and projectiles consume the same owner; no second stream or new seed
is introduced. Ordinary `ParticleRandom.new()` remains the script oracle.

Native simulation bypasses dispatch only for a registered live native RNG
object's exact standard `next` callable, with a fixed nonvirtual
`Object.get_script()` check returning null **on every draw**. A lambda, bound or
replaced callable, a different method, a dead object, or any attached script
keeps the existing opaque call/error/mutation barrier. No script method is
whitelisted as pure. Profile counters distinguish native draws and opaque calls.

The corrected candidate passes 788 focused checks and 371 checks using three
installed original MDLs (`it_torch_000`, `plc_cndl01`, `plc_x0_drt`), including
six real emitter/controller families. The installed-model run matches 2,340
shared draws with 1,305 direct native draws, exact private states and CPU geometry.
The gates include actual wind handoff, GD fallback interleave, all three update
kinds, detonations, same-call provider replacement, attached script override and
removal, integer wrapping, detached snapshots and fresh-world reset. Chunk scene
services are deterministic boundary stand-ins; textures/child-Gob visuals and a
graphical game session are not validated by these checks.

V1's uninitialized StringName return storage caused a private headless crash;
its DLL and failed receipt are preserved. V2 constructs that return slot before
use. Earlier fixture omissions of a wind service and required frame fields are
also retained in failed receipts. V2 logs are clean, without leaked instances.

- Candidate: `.cache/native-140fps/particles-agent/native-shared-random-v2/`
- DLL: `6bdf3d1749e4f92722ec0c67259bdbe11b6d7ee3d5f7d30e788d66a579a36bcc`
- Receipt: `da8146fc8eba12a8017a035e89df6c15d8268c6f6161579bb8b51569d67fe8e9`
- Patch: `031f3f297ffbad4bc30fb92b9f8dc12bf6bca0cb68db0eb7dae3bbe93979e558`
- Focused tests: `checks/native-shared-random-focused-v5/`
- Installed-model tests: `checks/native-shared-random-models-v1/`

All nine override hashes reproduce exactly through private patch readback.
Shared sources and native outputs remain untouched. Root must compare the same
DLL/project with the native RNG flag off/on before any promotion; this candidate
inherits the frozen all3/cold-census parent. No FPS gain is claimed here.

## Explicit owned-model clock publication

`native-owned-clock-v3` adds a separate `--particle-clocks=native` /
`NWN_PARTICLE_CLOCKS=native` choice. It does not enable native RNG or a pose
lease. `ModelRigs` remains the clock owner: a lazy per-model `NwnParticleClock`
slot mirrors the existing `clip`, **double** `last_time`, and `play_serial`.
It does not advance time, choose an animation or read a renderer's float clock.
The native Part pose time can represent a different blended run and is not used.

Canonical publications occur at the existing writes: `_native_clock`, the
AnimationPlayer `last_time` assignment, `_play`'s intermediate serial update
before player callbacks, and its final clock values. Static producer methods
bind/publish/disable these fields so an attached consumer script cannot intercept
publication. There is no added clock synchronization or changed callback order.
Only models with emitter consumers allocate a slot.

The emitter retains its original GD provider for reference/GD fallback use.
Native shared registration selects a typed sample only while that provider is
unchanged. The native reader checks its live exact slot callable and rejects any
attached script or custom/replaced handler to the existing opaque path. Producer
identity is weak and live-validated. Slots also retain their original bound
callback as an explicit fallback; disable occurs **before** model replacement,
forget/close or adoption callbacks. This preserves live-empty/unavailable data,
malformed responses, and the freed-producer invalid-callable/static-clock branch.
Shared/adopted dictionaries conservatively stay opaque. No model pose header was
changed and dynamic actor/door/reference poses are not cached by this work.

This contract covers canonical renderer ownership. Mutating renderer-private
model dictionaries or hot-reloading producer code outside its lifecycle hooks
requires disabling/rebinding, as with prepared model control plans. It is not a
claim that arbitrary script code is pure. Consumer scripts and provider
replacement are exercised as real opaque callbacks.

V3 passes **1,428 focused checks** across the clock/RNG and installed-model gates:
raw signed-zero/double time, detached and unavailable samples, exact particle
state/geometry/RNG, malformed/freed/disabled sources, actual script handlers,
AnimationPlayer start reentrancy, native model events, replacement, forget and
adoption. Installed `it_torch_000` exercises native runs/events; `plc_cndl01`
retains its actual AnimationPlayer route. The fixture's earlier assumption that
both provided native run playback is retained as a failed receipt. All five
existing pose/presentation/lifetime/scheduled-mutation suites also pass cleanly.
These are correctness gates, not CPU/GPU timing measurements.

V1 constructed temporary clock/sample Variants even for entries without a clock.
V3 only constructs typed sampling after a live callable exists. V2's const-pointer
compile error is retained; the corrected V3 does not change clock semantics.

- Candidate: `.cache/native-140fps/particles-agent/native-owned-clock-v3/`
- DLL: `2ae75745b8b88166a0303303aa9a06ba4afc125829b65cd2c0472e2489e2ee9c`
- Receipt: `5615a2aed7a90c9f9e9b58e877e5b3178a1067376ab36bdf62bf8d4e41421449`
- Patch: `3d7a4c8ae6d5611528adbe59e2711b08571bb0b3cd2f3d40c37b14294b593b7f`
- Focused gates: `checks/native-owned-clock-v3-focused/`
- Existing regressions: `checks/native-owned-clock-v3-regression/`

All 13 override hashes reproduce exactly through private patch readback. The
profile-only `count_particle_native_clock_direct`, `_opaque`, and `_fallback`
fields show actual coverage; existing pose invalidation/read counters remain.
Root must measure those barriers and compare matched same-DLL flag off/on before
promotion. No FPS gain or live-client validation is claimed for this candidate.

## Managed static Placement pose retention

The root's independent detailed capture with native RNG and clocks reported
seven direct/zero opaque model clocks, 131 direct/zero opaque random calls and
**zero pose invalidations**. Ordinary pose reads remained around 2,782 per frame.
Cosine was not an active barrier there, so the proposed cosine service remains
unimplemented. This evidence justified a separate managed pose candidate.

`managed-pose-leases-v1` is opt-in with `--particle-pose-leases=managed` or
`NWN_PARTICLE_POSE_LEASES=managed`, independently of clocks/RNG. Canonical static
`ModelTemplate.Placement` owners grant a small native token after final placement.
Tiles grant after initial lights and before publication listeners. Non-door
objects grant after attachment; changed server poses revoke before the original
Godot setters and regrant afterward. Placement reference attachment, exit and
retirement revoke first. World retirement/close revoke its entire scope before
hide/process/close callbacks. Unchanged pose applications do not rebuild tokens.

The existing native presentation pose rows hold their existing exact converted
output plus a lifetime/revision/callback witness. No second pose/world store is
created. Every endpoint use retains live ObjectID/Node3D validation, and the
existing per-entry tree/visibility/process gates remain live. Weak Placement
owners are validated once per presentation call, and the weak world owner once
per scope/call. Opaque callbacks suspend sharing and advance a persistent
mutation revision on entry/exit, including failures. The next read refreshes;
changed parent chains permanently retire that grant. Missing/nonfinite data
cannot establish a retained witness. Counter saturation disables reuse.

Actors, doors, referenced models, spawned chunk models and ungranted owners use
their existing live path. An authored chunk emitter in a proven static Placement
may retain its unchanged parent Part/source pose; chunk simulation, bounds,
child movement and callback ordering are unchanged. Parameter controllers and
elapsed/modulo clocks still run normally. There is no empty-emitter, simulation,
controller or eligibility shortcut.

This is an explicit renderer ownership contract. Any supported between-frame
writer to private Placement/root/Part transforms must revoke first. A callback
that installs a new ongoing private writer also must revoke before installing
it; immediate callback moves/reparents/frees are handled, but a revision cannot
prove arbitrary future script purity. The read-only entity API exposes no Nodes.
The canonical grant does not come from copied metadata alone.

The candidate privately compiles and passes **29,669 clean checks** across eleven
headless suites. The two new suites contribute 941 checks: real canonical
Placement grant/revoke, early/late scheduled owners and two calls in one engine
frame, reflection/nonuniform transforms, ordinary same-call mutation and failed
service retry, source reparent/free, scope replacement, exact state/geometry/RNG,
and installed torch/candle/debris fields/controller pools. All existing clock,
RNG, pose, presentation and lifetime suites still pass. Installed-model chunk
services remain deterministic boundary stand-ins, not child-Gob visual tests.
The first fixture failure omitted its wind service; that receipt is preserved.

- Candidate: `.cache/native-140fps/particles-agent/managed-pose-leases-v1/`
- DLL: `672bd24ae23f0be06bb209bc40ec5083fbe8ac14e92b2dd6b10f836255a840ea`
- Receipt: `20fab7baae2500eb4e45a95e77da68a2f4f913b52fe252666e1f2fa81a1afd14`
- Patch: `6f9a3b296bf39b453488673bdd61ef94ad4c7b1e32f120cee8080a7e9e6e2bc5`
- Tests: `checks/managed-pose-leases-v1-regression/`

All nineteen source override hashes reproduce exactly through private patch
readback. A separate pure C++ gate adds **45 checks against the actual frozen
FramePoseCache/policy headers**, covering retained row boundaries, callback
suspension, nonfinite rejection, failed conversion/retry and revision saturation.
Its first fixture compiled the same policy from two physical paths and failed;
the corrected single pinned-header fixture and both receipts are retained under
`checks/managed-pose-leases-v1-pure-2/` and the preceding failed directory.

The profile-only `count_particle_native_pose_managed_hits` and `_refreshes`, plus
the matching `frame_pose_reuse` fields, expose actual coverage. Root must measure
the same DLL/project with leases off/on, including cold entry and settled room
coverage, before any promotion. No graphical/FPS acceptance is claimed here.

## Presentation-local common input reuse

`retained-common-input-v1` is independent of managed leases and inherits the
frozen clock v3 tree. `--particle-common=retained` / `NWN_PARTICLE_COMMON=retained`
selects it; the ordinary per-entry lookup remains default. The flag is resolved
once per GD stream group. It retains only the converted `common.animating` bool
inside one synchronous native presentation call, keyed to the existing opaque
callback epoch. It does not retain the Dictionary, cache entity eligibility,
advance clocks, or skip controllers/simulation.

Every real callback barrier invalidates the value on entry/exit. Missing values,
integer/float/bool truth semantics and conversion failures remain the existing
engine lookup/conversion. An error publishes no cache value; retries start a
fresh call. A sticky current-call wrap guard disables reuse if the callback
epoch wraps, even if the pose cache has already cleared its normal wrap marker.
The next presentation call creates a new cache. Closed frames reject before any
common lookup, as before.

The private DLL compiles and passes **31,288 headless checks**: 6,296 focused
mutable-common checks plus the clock/RNG, scheduled mutation, geometry and
lifetime suites. Tests exercise an actual avoided engine read, callback changes,
missing/numeric values, malformed truth conversion after an earlier valid read,
failure/retry and closed/no-RNG behavior. A separate **31-check pure gate** uses
the actual frozen cache/epoch headers for nesting, exception invalidation,
per-entry off mode, new-call isolation, disabled diagnostics and wrap rejection.
The first forced-callback fixture was culled, so its expected error never ran;
that failed receipt is retained and the fixture explicitly admits that emitter.

- Candidate: `.cache/native-140fps/particles-agent/retained-common-input-v1/`
- DLL: `953b7e0a43d147d836f90a96ed06fcba39bbd6739f8f8d517ed57e620e813f2e`
- Receipt: `5bc48e209678dcd7d4cecb9950e02fe337dcf308244d421d05cf0577237eb9e3`
- Patch: `925abbf4763a85c2d3c613dffe11bb82db6990d02a7396cde9b84cd2e9ee4d8d`
- Native tests: `checks/retained-common-input-v1-focused-3/`
- Pure gate: `checks/retained-common-input-v1-pure/`

All fourteen override hashes reproduce through private patch readback. The
profile-only `count_particle_native_common_reads` and `_hits` show actual lookup
coverage. Root must compare the same project/DLL with this flag off/on before
promotion. A lower engine-read count alone is not an FPS improvement.

Root's first matched full-room test measured common reuse off at 9.172190 ms
and on at 9.187030 ms, with identical reported draw/triangle counts. It showed
no FPS gain, so this candidate is not being combined or promoted without a new
active coverage reason.

## Optional builtin scene snapshot experiment

`tools/perf140/particles/bulk_scene_snapshot_plan.md` describes the next private
architectural experiment. Source now includes a small optional engine module,
shared fixed byte ABI and native consumer. One main-thread public-getter batch
can supply current eligibility/full IDs and optionally exact transforms inside
one callback-free presentation scope. Missing/wrong-type/detached/unsupported
data is explicit and retains the ordinary fallback/error boundary. The first
opaque callback invalidates the batch for the rest of that call. This is not
cross-frame reuse or an empty-emitter skip.

The consumer has separate off/eligibility/full modes. Eligibility mode avoids
re-fetching static leased TRS; full mode also snapshots current transforms.
Membership boundaries maintain unique ID/role slots, and no Node pointer crosses
the ABI. The source also includes an explicit scalar last-frame diagnostic and
separate batch timing so reported eligibility gains cannot hide the batch cost.

The frozen v4 extension and v3 engine module passed 30,129 isolated headless
checks, including packet/public-getter parity, scheduled mutation callbacks,
managed poses, installed models, clocks/RNG, geometry and lifetime. A separate
official-engine gate passed 26,106 checks with explicit unavailable-module
fallback. Source review corrected the contract/fixture to distinguish C++ Basis
row-major storage from GDScript's column indexing before the engine build. The
engine loop already emitted the intended raw row words. Failed preparer,
declaration-order and fixture receipts remain preserved.

Root's actual matched room test **regressed** from 9.3024 ms with the snapshot
off to 11.0371 ms with eligibility batching on. Both requested and actual mode
were proven; the batch had 4,651 rows and supplied 1,829 eligibility uses plus
5,487 validation uses. This original candidate is not promoted. The source
audit found process-owner ancestry memo/temporary-vector work on all live rows,
even validation-only rows, plus repeated consumer hash lookups and packet-row
decoding. Validate-only rows did not call visibility/process/global-transform
getters; that more specific suspected duplication was disproved.

### Corrected preflight and direct slots (private, awaiting graphics comparison)

The new engine follow-up uses one C++-only public Node accessor for the already
cached effective process-thread owner. It adds no fields, virtual methods or
script API. Inside-tree thread-group changes are main-thread-only and update
descendant cached owners synchronously before public property-list callbacks.
The module now skips the ownership preflight entirely for identity/type-only
roles; eligibility/TRS roles still explicitly reject sub-thread writers. The
ordinary getters remain the exact source of eligibility and transform values.
Public thread readability alone was rejected as an alternative because it does
not prove the absence of a concurrent sub-thread writer.

The independently frozen `scene-snapshot-direct-slots-v1` extension derives
from frozen v4 and **does not include the separate unbuilt capability-observer
draft**. It validates each immutable packet row once, then uses scalar
Plan-ID/full-object-ID/slot handles. Every use retains current callback epoch,
mutation revision, Plan identity and slot/full-ID checks. Opaque callbacks still
invalidate the whole snapshot for the rest of that call. Handles contain no
Node pointers. Membership changes publish handles at existing boundaries;
shared owners used in another Plan refresh their endpoint handles explicitly.

The corrected engine and extension passed **30,331 clean headless checks in 14
suites**. The 33 engine gates include immediate SUB/MAIN changes, descendant
ownership as seen within property-list callbacks, reparenting, explicit child
override/inheritance, outside-tree semantics, and validation-only sub-thread
roles. Another 193 checks prove once-validation, direct-path counters, removal
and new full-ID slot reuse, reorder, shared-owner multi-Plan refresh and Plan
retirement. The existing 4,854 scheduled mutation checks and full native
state/geometry/lifetime suites also pass. All shared-output guards stayed
unchanged. The first direct-slot fixture disabled a scope constructor it used;
the fixture was corrected and that failed receipt is preserved. A mistyped
suite filename aborted one staging attempt before an engine ran; it is retained.

- Candidate receipt: `.cache/native-140fps/particles-agent/scene-snapshot-direct-slots-v1/candidate-built-sources.json`
- Receipt SHA256: `41b57604b7810b216483e88def4d2268d28ce6eb8a7c015248b3ad45eba1262f`
- DLL SHA256: `e27d0aaf9d0c4d474f32db08a62592cfabec4e1e7d700047ede8fb3fb79bac8a`
- Patch SHA256: `f582665b951c667a9b709e5fa545ad388d4590ce82d50a12ad62dcc57db83daa`
- Corrected engine SHA256: `0dc2e0b64af4b401684dc35b25a5c63e8cb667994ae2c877db88acf9659c8015`
- Engine module/Node patch manifest: `scene-snapshot-thread-preflight-v1/engine-module-sources.json`, SHA256 `baaec9dd9e0513d0b651bacde1a20d203430e3b725a8d9550290033a9612126f`
- Test receipt: `checks/scene-snapshot-direct-slots-thread-regression-3/checks.json`

All 22 source override hashes reproduce through private patch readback. In the
three-emitter fixture each seven-row packet validates exactly seven rows, then
12 uses take retained slots with zero steady ID-map lookups. Switching a shared
owner between Plans correctly produces refresh lookups. These counters prove
the intended code path, not an FPS gain. Root must run the matched same-DLL
off/eligibility comparison on the corrected engine before any promotion. Full
mode's speculative managed-TRS capability draft remains separate and unbuilt.

## Entry-owned provider reference (independent private candidate)

`provider-reference-v1` derives from frozen managed-pose-leases-v1, without the
optional builtin snapshot or capability-observer draft. It removes one repeated
Godot Dictionary Variant destroy/new-copy pair for each admitted Entry's Step.
The old copied Dictionary and new reference both observe live mutations to the
same Dictionary; the feature changes ownership bookkeeping, not callback
contents or simulation.

The complete native source has one Step advance call site, on the Step embedded
inside an Entry, with the services argument exactly Entry.providers. The Entry
retains that Dictionary through simulation and geometry. Its add/remove/control/
reorder/close operations reject while the presentation is running; the GD group
queues callback-triggered removals for the next frame boundary. The borrowed
reference cannot outlive that embedded Step or its Entry. A distinct explicit
`advance_entry` method selects this borrow. Ordinary `Step.advance` still takes
the original owned copy for any future temporary or standalone services caller.

The mode is off by default; `--particle-providers=borrowed` or
`NWN_PARTICLE_PROVIDERS=borrowed` publishes `borrow_providers` at the existing
registration boundary. Native detached entry inspection reports the actual
mode. The same DLL can compare original owned and borrowed paths.

The candidate compiled cleanly and passed **35,987 headless checks in 12
suites**. Its strengthened **6,320-check focused fixture** separately confirms
four callback replacements and 1,319 subsequent replacement invocations in
each ownership mode. The focused checks include replacing callbacks in the shared
provider Dictionary during random callbacks, complete state/geometry/RNG parity,
failed callbacks and retries, and attempts to remove/re-add/close/reenter/control
the presentation while running. A weak provider member stays alive after the
external Dictionary reference is dropped and expires at boundary removal in
both paths. The full clock/RNG/managed-pose/installed-model/scheduled-mutation/
geometry/dense-lifetime suites also pass. The first fixture required an explicit
WeakRef annotation; its rejected parse receipt is preserved.

- Receipt: `.cache/native-140fps/particles-agent/provider-reference-v1/candidate-built-sources.json`
- Receipt SHA256: `a63abd5528c33a37a265b461ef3d631cd8f9f21de56b75ea032fb1cb5b6778a1`
- DLL SHA256: `87937d61a7acc9cfe5c4530ffb051f4be118dfae3969cffb714329f4873a0f6c`
- Patch SHA256: `1d5e7f8457eab30056e73ce262448aa3ca7c0b71cce321432f84a028fc3dc0d6`
- Test receipt: `checks/provider-reference-v1-regression/checks.json`
- Explicit replacement-consumption receipt: `checks/provider-reference-v1-consumption-4/checks.json`

All 19 source override hashes reproduce through private patch readback, and all
shared outputs remain unchanged. This is a bounded removal of repeated work;
it has no graphics/FPS result and is not promoted. Root schedules that separate
comparison before combining it with other candidates.

## Explicit static Placement eligibility ownership (private)

`managed-static-eligibility-v3` is another independent managed-pose-v1
derivative. It adds a **separate** eligibility capability and scope; a pose
grant does not imply eligibility ownership. For static descendants explicitly
published as locally visible and process/thread-group INHERIT, the current
Placement's inside/visibility/process result is read once in each synchronous
presentation call. Each leaf still performs live full-ObjectID and Node3D type
validation. Local mode/visibility or topology outside that explicit ownership
proof uses the original live getters.

The canonical tile and non-door object publishers issue the grant. Actors,
doors, references and spawned chunk child Gobs receive no such publication.
Actual particle preference setters revoke before visibility/process setters and
regrant afterward; a batch preference change refreshes each touched Placement
once. Retirement, reference topology changes and world scope retirement revoke
before supported writes. Pause, ancestor visibility and ancestor process mode
are read from current engine state every call. The first opaque callback,
including a failed last callback, abandons shared eligibility for the rest of
that call. The next call checks captured local/structural dependencies if the
callback revision changed. There is no empty-emitter or simulation-wrapper skip,
per-frame world scan, live Node exposure or world-anchor broadening.

The corrected candidate passes **30,592 clean headless checks in 13 suites**.
Its 515 focused checks use actual production preference/retire methods, early
visibility reentry, hidden/ALWAYS/sub-thread local exclusions, paused ancestors,
retire/reinstall during reparenting, freed full IDs, stale scope generations,
opaque mutation and failed callback recovery. Three canonical members prove
three live leaf validations and one current ancestor read per call, even when
many calls occur in the same engine frame. Six actual emitters from installed
torch/candle/fire models pass 408 exact state/geometry/RNG/service-order checks,
with 170 actual eligibility hits. Chunk callbacks in that fixture are
deterministic stand-ins, not a child-Gob visual validation.

**V1 and V2 are rejected, even though functional tests passed.** Their new enum
getter destinations were int32, but Godot ptrcall encodes enum returns as int64.
The ABI source audit caught this before graphics staging. V3 uses GDExtensionInt
and guards the actual cold getter slots with neighboring canaries. The focused
test records 457 enum calls, eight-byte outputs and zero canary failures. The
bounded audit of the ordinary frozen kernel found no corresponding old error;
it does not attribute the unrelated chooser startup access violation to this
new, unpromoted prototype. Failed fixture assumptions about real emitter
retirement and registration order are also preserved with their receipts.

- Receipt: `.cache/native-140fps/particles-agent/managed-static-eligibility-v3/candidate-built-sources.json`
- Receipt SHA256: `25ef717cfac80258b72deb98af5f90982a08b20f3c0c330a1d7e6b2c1ad03961`
- DLL SHA256: `ffa1acd4f97bac5e03714d3ab47d1de3e224921de20672311a91195740752ecd`
- Patch SHA256: `e75979152f6c28eeac3f342b987a4d9fd86e5fce67a5b2b60705690bd7aed712`
- Tests: `checks/managed-static-eligibility-v3-regression/checks.json`
- ABI investigation: `tools/perf140/particles/ptrcall_return_audit.md`

All 22 override hashes reproduce through private patch readback and shared
outputs remain unchanged. `--particle-eligibility=managed` selects the prototype;
native entry inspection reports the actual `managed_eligibility` flag, and
presentation dispatch15 reports attempts, hits, anchor reads, leaf validations,
structural rechecks, fallbacks and callback invalidation. Root must measure the
same-DLL off/on result and actual room coverage. No graphical/FPS gain or
promotion is claimed. Direct mutation of renderer-private Nodes outside the
explicit revoke/regrant contract remains unsupported.

## Persistent typed input boundary, private v2

The independent `typed-boundary-v2` experiment rewrites only the presentation
setup boundary on the proven managed-pose-v1 parent. It keeps one synchronous
simulation/geometry execution body, the original owned Step fallback, all
current emitter wrappers, clocks, readiness, live callback dictionaries,
admission and immutable output packet ownership. EntryConfig holds rare typed
settings; one Owner-owned FrameInput is borrowed during the running call;
optional PendingCommands avoid the absent-patch Variant work; StepResult keeps
cold diagnostics and the original consumed-patch resource lifetime. One shared
active/generation witness invalidates all borrows on exceptional or normal exit.
There is no extra all-member cleanup scan.

Explicit mode: `--particle-inputs=typed` / `NWN_PARTICLE_INPUTS=typed` before
registration. Ordinary is the default; changing a registered Entry's mode
rejects at the frame boundary. Dispatch10 exposes `typed_boundary`; cold
post-window dispatch16 exposes selected/advanced entries, shared-frame and
Entry-provider borrows, retained patch snapshots and inactive frame witness.

Correctness: 7,807 dedicated focused/installed-model/native-clock checks plus
42,111 existing regression checks, all clean. Tests cover malformed patch
failure/retry and embedded RefCounted snapshot retention, same-frame provider
replacement, common/readiness mutations, reentry/re-add/remove/close guards,
installed MDL fields/controllers, exact state/geometry/RNG and typed native,
fallback and custom clocks. No new ptrcalls were introduced; the corrected
source audit retains 44 existing call sites in 38 pinned native files.

Frozen receipt:
`.cache/native-140fps/particles-agent/typed-boundary-v2/candidate-built-sources.json`
SHA `074fe64b820e215b5f5a3f289390ffb828c40767b1ff585df0782f56dd92bc43`.
DLL `ec56dee5300b2f95b2120091d06716491e7513834dd089b42966838af70ad1eb`.
Patch `3e2f4d6fd97bd748c4467c89893d92c3a4df41205b5539a0c5775fbf09e2d5ca`
read back all inherited override pins exactly. Only the presentation header and
stream registration literal differ from this exact parent. The candidate does
not bundle independent eligibility/provider/bulk-snapshot/manual-suppression
experiments. Shared production outputs are unchanged.

Initial failed compile/fixture receipts are preserved. This is functional
validation only: no graphical or FPS gain is claimed. Root's live user test
continues using its prior benchmarked candidate; this experiment stays private.
The exact contract and source-backed broader plan are under
`tools/perf140/particles/typed_boundary_contract.md` and
`tools/perf140/particles/typed_persistent_particle_plan.md`.

## Generated-light manual publication, separate private GDS v3

The exact room identity join resolved all56 rigs: all34 manual-only owners are
fx_placeable01 generated lamps (31 static/3 dynamic); two truly idle rigs are
C_BoatHack. That is a coverage ceiling, not an enrollment/performance result.
A separate GDS-only prototype explicitly enrolls canonical exclusive identity
Root Parts, keeps immediate P/Q and two matching ORIGINAL P/Q/S publications,
and only then omits later repeated commands. General quaternion, negative or
nonuniform scale, native/animated/player/attachment/skin/reference states stay
original. Canonical manual/playback/configure/adopt/forget/attachment/orientation
and lifetime mutations revoke before writes. Every owner clock/update and all
ancestor following remain unchanged. Published matrices alone are not treated
as a generic hidden-cache proof.

Final focused102 and actual installed-model65 checks passed cleanly; the latter
uses production preparation/base tables and proves both a static/dynamic lamp
armed, with32 omitted publications in the final revisions and exact local,
global, actual model-light/palette and particle-pose inputs. Existing clock149
and lifetime12080 gates also passed. Initial uppercase-resource and null graph
placeholder false rejections remain preserved in v1/v2 receipts. There is no
native rebuild: v3 source/DLL is the exact unchanged managed parent672.

Manifest `.cache/native-140fps/particles-agent/generated-light-manual-v3/candidate-built-sources.json`
SHA `5ad2be7256c6220736b3291e512f9dc4a675b35c33c6d4b0ccb288aee0d848f6`.
Patch `852bd92ab8dc80aad7524fb68094f2717d7e5876a20d3571c79ec8c2fcf1fa26`
reads back22 inherited overrides; parent-relative changes are only the new
helper plus ModelRigs, EffectModel and PlaceableLights hooks. Select with
`--generated-light-manual=retained` / `NWN_GENERATED_LIGHT_MANUAL=retained` before
creation. Post-window `rig.generated_manual_snapshot()` reports real coverage.
No GPU/FPS gain, full-room34 coverage, or promotion is claimed. The typed
boundary and eligibility experiments remain separate.

The related source-only upstream collection audit is
`tools/perf140/particles/upstream_admission_audit.md`: current Step admission is
pre-simulation, but after costly per-member setup. It does not yet implement the
original camera-volume collector before the emitter bucket, and chunk/unknown
wind bounds retain complete fallback. No new admission gate was added.

The final generated-light artifact is now private **v4**, adding an exact
standard-ModelRigs script ownership guard. Experimental SkeletalRigs overrides
writers, so it and custom rigs cannot acquire this lease merely by inheriting
the public method. All four gates repeated cleanly:12,396 checks. V3 remains
frozen as prior evidence. V4 manifest SHA
`e10a24cb0b9a2b7f401c2e389ee29d1e0a84d7b7db99ad44e0662eb373e8d1be`;
patch `ee99314e3c417c5e0a4d1f58418cca00e255a6c572b800e824aa94e92edda5ab`
reads back22 inherited overrides exactly; native DLL672 is unchanged.
No timing or new native build followed these gates.

Source-only Object instance-binding lifetime investigation is recorded in
`tools/perf140/particles/instance_binding_liveness_audit.md`. It is not an
implemented feature. At most it could avoid some repeated ID lookups under a
proved canonical main-thread lifetime contract; it cannot replace tree,
visibility, process, topology, pose or scope checks. The pinned engine's free
callback is late in Object destruction, binding callbacks run under a mutex,
and arbitrary tokens have no automatic library-unload cleanup. Current tested
candidates are measured before deciding whether that complexity is worthwhile.

## Later private outcomes and next source audit

Root confirmed actual typed-mode readback:1,829 selected entries versus zero in
ordinary. The first ordinary run was anomalously slow and failed the strict
camera comparison, so it is not evidence of a large gain. The later matched
ordinary A2 measured105.88 FPS; typed B1/B2 measured108.37/107.49 FPS. B1 had one
55 ms hitch; B2 completed without a>50 ms hitch. This is a possible modest
1.5–2.3% improvement, kept private and unpromoted.

Generated-light **V5** separately avoids revision Dictionary writes for entries
that have never acquired a publication token. Cold enrollment reads actual
current manual/owner/node state, so no historical observer is lost. Acquired,
stale and already-revoked token invalidation is preserved. Its expanded
no-write/current-state/reentrant fixture plus installed models/clock/lifetime
passed12,424 headless checks cleanly. V4 remains frozen; native sources/DLL672
are unchanged with zero native builds. V5 manifest
`f752f49e7d2cd095fb22dedf37e7f4d452967cb2985b704d289bed8bf7f35312`,
patch `033c23c0dc2c66c67150631bd4a904d400963dfaf2eb77e64403fe3b4e1b667e`.
No graphical/full-room coverage or FPS validation is claimed for V5.

The remaining audit is recorded in
`tools/perf140/particles/typed_endpoint_slot_plan.md`. The cold census contains
only57 selected-channel rows out of1,829; another constant-channel compiler
would have little room-wide coverage. The larger remaining setup cohorts are
live eligibility and2,782 distinct pose/source endpoints. A bounded endpoint
slot design may remove internal native hash/index/copy work while retaining
the existing full-ID/type, scope, topology and opaque-callback checks. An
isolated optional **endpoint-slots-v2** prototype now passes28,302 pure/native
headless checks, including a2,782-endpoint storage cohort and actual scheduled
SceneTree/installed-model oracles. It does not skip identity reads or bundle
typed/manual/eligibility changes. Ordinary remains the default. Manifest
`4f91c8f3381b75cf4365dc2bbbe7d24dfaa05a4a129bb7d1baf7de265d791c1d`,
DLL `0918c68b02360c35d14bc75b2e3ba11e1835ce7bce1c1a6a13f6c8b34c29ff1d`,
patch `261e8a37eb2b3e07dbc671479027942cc70ecc66015c61a110c3cdbe720c0d62`
reads back20 inherited override pins. Shared outputs are unchanged; no graphical
or FPS acceptance is claimed. Mode is `--particle-pose-slots=indexed`, with cold
native dispatch17 proving mode, current rows/direct hits/lookups and footprint.

Root's first endpoint off/on graphics pair completed cleanly with zero>50 ms
hitches and the same5,968 scene draws/353,308 triangles. Ordinary110.23 FPS versus
indexed109.53 FPS, with a tiny strict-camera mismatch5.5e-5 world units, does
not establish a gain. Actual indexed readback had3,658 direct hits, zero map
lookups and2,782 sole-store rows; the intended work removal was active but did
not demonstrate a meaningful frame improvement. The candidate stays private,
unpromoted, and is excluded from the user's next live build.

The larger upstream cohort study remains source-only in
`tools/perf140/particles/upstream_preadmission_plan.md`. Render corrected the
cold join:444 checked finite-nonchunk rejections, including23 selected-channel
rows containing347 of709 channels;421 rejected rows have no selected channels.
The old1,649 unbounded label described clocks, not effect/radius bounds. Neither
old radius0 sentinels nor previous controller/wind/child bounds establish a
current conservative collector. No pre-admission or empty-owner skip was added.

The current publication audit is
`tools/perf140/particles/current_particle_publication_audit.md`. The finished
ordinary snapshot's103 owner ranges merge into65 actual RD draws/28,020
vertices. One shared672,480B vertex upload plus a32B fog uniform update serves
the warmed packet; there is no per-owner Mesh/Material publication on this
native-surface sprite path. Zero alternate scene_batches is expected. Actual
unique texture/pipeline-bind counts are not exposed and must not be inferred
from65 draw runs. No further draw-batching gain is claimed from source counts.
