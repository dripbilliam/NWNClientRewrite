# Native loading optimization goal

Latest user-directed change: compact scenery is restored as a persistent native
Options → Graphics toggle, default off and applying at the next area load.
See `NATIVE-COMPACT-SCENERY.md`; no new overall FPS improvement is claimed.

Earlier structural experiment: compact render-leaf physical Parts preserved exact
original pixels/queries and removed about23% of scene nodes, but two complete-area
comparisons did not improve steady rendering. It was initially archived and
removed; the user requested retaining it as an opt-in choice. See
`NATIVE-COMPACT-STATIC-PARTS-REJECTED.md` for those historical measurements.

Latest profiling checkpoint: `NATIVE-LOADING-FINE-STREAM-TIMING.md` documents
separate message, object-attachment and scene-hide/disable boundaries. Complete
offline area and two authoritative local reconnects pass. This is attribution
work, not an additional performance acceptance claim; the earlier measured
large-room spikes remain open. Runtime still defaults to opt-in ready capture.

Current update (2026-10-27, 21:08 UTC): automatic ready screenshots are opt-in
instead of freezing normal gameplay during PNG encoding. Empty collision models
retain their null fallback without repeated missing-metadata engine errors.
Current scoped audit: `reports/native-loading-optin-preview-audit-v1.json` verifies
900 collision checks, complete 630-entity frozen replay with capture off/on, and
the owned local Prelude load. All pinned sources match; no public connection.
See `NATIVE-LOADING-MANUAL-HANDOFF.md` and
`reports/native-loading-manual-fps-review-v1.md` for remaining measured stalls.
The older 6,236-check full suite below is historical after this small update;
the current audit deliberately claims only the relevant new regression scope.
Transition scene disable (35–36 ms), object publication and unassigned outside-
callback waits remain open; overall FPS/original-client parity is not accepted.

Current handoff (2026-10-27, 20:46 UTC): material/shader prewarming is enabled by
default for graphical startup. The audited current build passes 6,236 checks in
44 cases, complete 630-entity offline loading, and the owned local Prelude check.
Receipt: `reports/native-loading-material-prewarm-audit-v1.json`.
See `NATIVE-MATERIAL-PREWARM.md` for exact measurements, rejected alternatives,
and limits. First-use binding on three tested original models fell from about
23–24 ms to 0.05–0.13 ms; this is not proof of overall FPS or original-client parity.
The user has returned and wants to test manually on Arelith. Stop additional
automatic GPU experiments and runtime edits during that test. No automated public
connection is authorized. The broader goal remains active and unproven complete.

Previous checkpoint (2026-10-27, 20:02 UTC): six loading stages are implemented;
the extra optimization phase has exceeded two hours and work continues until the
user returns. The latest default also prepares one small nearby scenery wave
alongside the player's already-started request. Read the final section for current
receipts and tradeoffs. Bounded ancestor decoding now also shortens cold player
preparation. Compiled exact-pixel conversion/shared palettes now reduce tile and
background-object preparation; player readiness remains around 3.2 seconds in
the latest isolated cold areas. **12–13 second baselines below are older Godot builds,
not original-NWN executable loading measurements.** Original binary methods were
researched read-only; direct original-vs-replacement timing parity is unproven.

Current default moves exact mesh upload/collision derivatives to workers and
retains a bounded set of private GUI models to avoid immediate post-bake teardown.
Direct typed ASCII key writes reduce boxed allocation, and replaced raw UI maps
now leave the presentation thread through the bounded disposal owner. Immutable
MDL persistence uses a bounded native writer and per-destination publication
gates, retaining verified cache bytes outside the asset-completion path. The new
6,204-check/41-case suite, complete-area/default/local checks and receipt audit
pass. The full timeline remains explicitly incomplete for missing captured bytes.
Current source/receipt audit: `reports/native-loading-clips-audit-v1.json`, reproduced
with `tools/audit-native-loading-six-stages.mjs --phase=clips` (the new default).
Shared worker clip indices and on-demand private metadata lower animation installation
work; cold player readiness is still about3 seconds. Earlier skin/cache/typed/transition/mesh/raster audits are historical. Actor installation, template
publication and indivisible loading hitches remain measured targets. All phase
sections below retain their historical scope/date.

The pre-control actor experiment is archived and removed from production. Its
final 30-check actual-worker fixture passed, but the 2 m-bound/high-priority
counterbalanced pair showed no useful readiness improvement (details below).
The exact restored inherited-retirement source passed
`reports/native-loading-transition-audit-v2.json` before the newer accepted changes.
No public connection has been made.

The current default also includes inherited-physics retirement. The earlier
16:10 audit belongs to
verified checkpoint `native-loading-worker-mesh-gui-reuse-v1.zip`
(SHA256 `cf1c0b9a3a9ab540133b9b44e751de5ab7852b1079a1fd3e9434ff92c64208b3`),
not to later edited source hashes. `--retirement-physics=scan` retains the prior
recursive scan. Actual physics-ray fixtures pass for both paths.

Started 2026-10-27 at the user's request. Active; no completion or performance
acceptance is claimed. Original binary SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.

Research each of the following against the read-only original binary; document
exact functions/call sites and evidence, adopt its approach when best, otherwise
implement and measure a compatible improvement:

1. Stage timings: lookup, reads, decompression, worker waits, model/rig/texture
   preparation, scene publication and asynchronous rendering observations.
2. Session-resolved direct resource lookup preserving server/mod precedence.
3. Parallel/batched native reads removing shared-reader serialization.
4. Persistent verified decompressed bytes with content identity/invalidation.
5. Deduplicated immutable model/texture preparation with private live instances.
6. Bounded player-centric scene/GPU publication.

After all six stages are implemented and validated, spend a couple of additional
hours optimizing the measured paths, pop-in and the terrain-to-controlled-player/
camera delay. Do not equate those hours with overall time before the six pass.
Continue until the user returns, retaining honest open work and failures.

Use the sealed private `capture-pUQlR4` five-area recording and owned localhost
Prelude server. No automated public/Arelith connections. Never embed proprietary
asset bytes in source checkpoints. Back up significant changes; preserve original
software, editor, credentials and unrelated processes. Graphical tests open on a
secondary monitor without activation or mouse capture.

Baseline checkpoint: `backups/native-loading-six-stage-baseline-v1.zip`, verified
SHA256 `4f07d63443e3b305cf62ebf9ff1ddd70e54c8ab85fad3104c31d76e22f613cac`.
The original paced replay has a fresh prepared cache but bypasses original
archive/NWSync storage and live protocol work/recording writes. Faster playback
does not by itself establish network/server latency or complete resource coverage.

## Initial observations

`CExoResMan::GetKeyEntry` 0x14018ffb0 searches ordered tables and calls
`CExoKeyTable::FindKey` 0x14018ad70. `Demand` 0x14018ef90 checks resident bytes and
services only nonresident resources; cache reuse is explicit. `ServiceFromManifest`
0x140193520 calls native `NWSync::CNWSync::GetResrefData`; original Tracy spans
cover Demand and manifest servicing. Retained complete dossiers are in
`../backups/animations/rea-loading-six-stage-*-v1.json`. This is partial subsystem
evidence, not a complete original scheduler/performance claim.

## Six implemented stages and original-method comparison

Implementation checkpoint `native-loading-six-stages-v1.zip` predates the further
parser and lifecycle changes below. All changes are native Godot/data helpers;
the replay's JS driver delivers frozen protocol frames only. No JS model decoding,
geometry generation, texture preparation or rendering is introduced.

| Stage | Observed original evidence | Native implementation / decision |
| --- | --- | --- |
| Timings | `Demand` 0x14018ef90 and `Update` 0x1401957f0 contain original Tracy/instrumentation scopes. | Measure queue wait, lookup, storage/helper wait, decompression, source decode/cache, rig, raster, publication, actor admission and camera separately. Render timings are asynchronous and nested spans overlap. |
| Resource index | `GetKeyEntry` 0x14018ffb0 calls override lookup at 0x14018fff1 and key lookup at 0x14019001a; `FindKey` 0x14018ad70 uses hashed probing. Ordered tables select the first winner. | Compile ordered mounted layers into a session winner map once. Forks retain immutable bindings; a new mount invalidates the new context. Preserve resource/type and raster format/storage precedence. |
| Parallel reads | `ServiceFromManifest` 0x140193520 calls `GetResrefData` 0x1401b1860; internal 0x1401c3560 reaches the checked SQLite closure at 0x1401c3692. Implementation 0x1401be0e0 queries manifest/resref/type. This does **not** prove the original reader pool topology. | Four bounded lazy native helper readers, each with its own SQLite connection, replace one serialized helper. Shared source residency coalesces simultaneous reads. This pool is a tested adaptation, not a claimed exact copy of NWN's scheduler. |
| Persistent bytes | `Demand` explicitly reuses resident bytes. Native NWSync lookup binds the resref to a SHA1 content identity. Whole original decompression/retention policy remains partially unknown. | Verified content-addressed raw bytes outside source, keyed by authoritative SHA1, atomically published, corrupt entries fall back to canonical mounted local content. Bounded disk retention; no name-only cross-server cache. |
| Shared preparation | `FindModel` 0x140098cd0 calls `BinarySearchModel` at 0x140098e8e; only a miss reaches `ReadSync` at 0x140098ecf. Deserializer 0x140079f90 resolves/refcounts supermodels and inserts model residency. | Shared coalesced immutable decoded sources, separate bounded appearance cache, shared GPU/template resources and private live actors. Keep original keys packed until needed instead of constructing every frame Dictionary repeatedly. |
| Player-centric publication | Original area loader 0x1407dba70 iterates terrain rows, yields to screen/connection work; held-player resource priority differs from remote actors. See `NATIVE-PLAYER-CENTERED-STREAMING.md` for call sites. | User-requested nearest-ready terrain/scenery and controlled-actor-first work. Shared 3 ms / 16 unit publication allowance, plus one controlled actor reservation. Indivisible model publication can exceed the allowance. Anchor the camera to the server entry pose before the actor's geometry completes; never fabricate authority/control readiness. |

Full derived function dossiers are retained under
`../backups/animations/rea-loading-six-stage-*-v1.json`. They pin the original
artifact identity and analysis evidence. Decompiled pseudocode is evidence of
these paths, not proof of complete subsystem parity or original executable timing.

`CExoResMan::Release` 0x140191220 distinguishes refcount release from final freeing:
on a normal final release it links the resource to a free list, while flagged
paths can free immediately. Our bounded deferred data disposal follows the same
useful separation of logical ownership and expensive cleanup, adapted to Godot's
main-thread scene/GPU ownership. It is not the same eviction implementation.

## Additional optimization phase

Started **2026-10-27 10:21:32 UTC**, after the six-stage implementation and focused
checks/local loading checks. Continue for at least a couple of additional hours;
this phase is still active. Its work includes:

* Separate decoded-source and complete-appearance residency, avoiding destructive
  cache thrashing between large animation parents and small prepared pieces.
* Retain exact binary32 animation controller pools; expand only selected channels
  into Godot animation keys. Preserve clips, events, interpolation and scaling.
  ASCII controllers now use typed double-precision key/time arrays too, preserving
  exact decimal conversion and existing axis-angle output without quantization.
* Native bulk tokenization for unquoted 2DA/ASCII rows, leaving quoted/fallback
  paths intact. Skip numeric animation lines in geometry-only ASCII passes.
* Publish immutable 2DA data to waiting render readers before expensive private
  caller copies. Mutable consumers still receive private data.
* Move detached CPU-only model/table graphs to bounded worker disposal; keep scene
  nodes, collision query Objects and GPU resources on the main thread. Hold the
  last source references across queued scene deletion before disposing them.
* Attribute automatic diagnostic screenshots separately from gameplay loading.
* Avoid expanded generic disk persistence for 2DA tables: original bytes remain
  cached and decoded tables remain shared in the session. In the captured case,
  appearance text is 2,804,006 bytes versus 40,773,400 serialized Variant bytes;
  direct parse measured 302 ms versus 460 ms verified generic reload. Five exact
  tables and all row/cell views are compared in the economics fixture. This policy
  does not remove model/raster persistence or any table fields.

### Measured receipts as of 11:36 UTC

All fresh-cache comparisons use frozen inputs, the same Godot/Vulkan path and
unchanged pinned authored sources per run. OS, driver and shader caches are not
flushed; the preserved editor remains open. These are functional loading
comparisons, not clean original-vs-replacement FPS acceptance.

| Receipt | Earlier implementation | Optimized | Scope |
| --- | ---: | ---: | --- |
| `native-loading-generation3-{baseline,optimized}-v1` player readiness | 12,252.6 ms | 4,818.1 ms | Both full successful isolated replays, 441/441 objects, no scope/resource errors, normal-heap CDB, clean finish/drain. |
| `native-loading-graphical-{baseline,packed}-v1` first-area player | 12,993 ms | 5,042 ms | Bounded 25 s observations; later missing corpus bytes prevent full-world acceptance. |
| `native-loading-graphical-five-area-{v1,fenced-v1}` peak transition retirement callback | 474.3 ms | 59.7 ms | Original-paced five-area runs; missing corpus resources remain explicit failures. Different receipts retain all failures. |

Cold optimized generation 3: first terrain tile 484 ms, complete terrain 1,909 ms,
camera entry anchor 21 ms, controlled actor ready 4,818 ms. The gap after terrain
still exists; it has shrunk and remains an optimization target.

Later successful generation-3 receipts (same complete 441-object endpoint):
`native-loading-generation3-table-policy-v1` player 3,848.8 ms;
`native-loading-generation3-packed-ascii-v1` player 3,758.4 ms, complete terrain
2,042.0 ms and camera anchor 22.9 ms. A roughly 1.7-second terrain-to-player gap
still exists. The first **sampled** complete initial population improved from
26.93 seconds in baseline to 6.81 seconds with packed ASCII; profiles are sampled
about every two seconds, so these are observation upper bounds, not exact finish
timestamps. Later recorded arrivals/appearance changes remain part of replay.

The repeated ~400 ms outside-callback hitch was traced to diagnostic screenshot
work: `native-loading-preview-attribution-v1` records 10.9 ms GPU readback plus
381.0 ms PNG encoding. `native-loading-graphical-five-area-no-preview-v1` delivered
the full timeline without that 400 ms stall: the first area's sampled maximum
frame was 46.4 ms. Do not classify every outside-callback stall as this cause.
Screenshot-at-shutdown work is outside active gameplay measurements. Older
baseline native entrypoints ignore this new opt-out, so their diagnostic readback
is not a fair frame-time comparison against a current no-preview run.

`native-loading-final-five-area-v1` adds projectile/ranged/voice table source
retention to the grouped disposal packet. It delivered all five areas without a
native exception or engine/lifetime error, with clean finish/worker drain and no
forced data/world drains or deferred queue overflows. Its sampled retirement
callback peaks were 0.005, 0.645, 0.690, 1.156 and 0.748 ms by area. This is a
sampled-peak comparison, not every-frame coverage. Total frame spikes still reach
about 88 ms during state application/initial publication. The run remains a
failed full-world acceptance receipt because of explicit missing capture bytes.

Additional original table evidence: `C2DA::Load2DArray` 0x1401a73a0 calls
`Unload2DArray` at 0x1401a787b, `CRes::Demand` at 0x1401a7885,
`Get2DADataPtr` at 0x1401a78de and `Get2DASize` at 0x1401a78ea; token calls occur
at 0x1401a858d/0x1401a8637. The full 40,877-code-unit pseudocode and complete
assembly/callee views are retained in the `rea-loading-six-stage-2da-*-v1.json`
dossiers. This path consumes original table bytes; it does not establish that no
other original table cache exists. Original quote parsing remains a separate
parity investigation; fast unquoted paths preserve our existing scanner behavior.

### Validation and open limits

Six-stage checkpoint suite: 219 native checks plus three Node recording checks;
`native-loading-six-stage-local-v2` passed against owned original Prelude server.
Subsequent focused packed-key parity (41), ASCII parity (15), 2DA parity (30),
coalescing/isolation (12), frame-fenced data release (10), entity release (10) and
world retirement (72) checks pass. Reports contain exact source hashes; old
checkpoint checks are not automatically current-source acceptance.

The five-area capture is sealed but does not contain every resource needed by
all later object variants. Replay forbids installed/network fallback and reports
each missing resref explicitly. Generations 3/4 have complete observed object
sets; generations 1/2/5 have corpus gaps. A missing remote creature currently
becomes a world-scope error, unlike isolated static object failures. That behavior
remains open. No deletion of failed receipts or silent replacement assets.

Required before final acceptance: rerun localhost and focused integration on the
final sources, complete the additional optimization phase, preserve a verified
source checkpoint, record remaining stalls and avoid claiming full gameplay or
original-binary performance parity from a stationary replay.

## Final-source verification checkpoint, 12:16 UTC

`tools/audit-native-loading-six-stages.mjs --run=<new-name>` rechecks current
authored source digests and all focused native receipts. Latest receipt:
`reports/native-loading-six-stage-final-audit-v3.json`, **410 native checks** plus
the three separately run Node timeline checks. The additional 16 checks compare
actual `actor_data` supermodel composition, root aliases, relevant-node filtering,
events and final rig channels against eager decoding, beyond raw-key comparison.

Second complete-area comparison:
`native-loading-generation4-{baseline,optimized}-v1` both succeed with **630/630**
objects. Controlled readiness improves **12,615.4 ms to 3,565.7 ms**; optimized
terrain completes at 1,529.5 ms and camera anchor occurs at 23.7 ms.

`native-loading-final-prelude-gameplay-v1` passes against the owned original
127.0.0.1:5121 Prelude server: actual click/keyboard movement, held looping gait,
Q/E strafing while inventory is open, inventory/reopen, examine/dialogue and
three authoritative door transitions. Rendered/authoritative movement both
advance; Q/E distances are 0.929/0.954 m with facing dot at least 0.9999997.
Held gait has 650 advancing samples and a phase wrap with zero nonlooping samples.
The three transition receipts reach complete object sets, player readiness
598/193/279 ms and total transition observations 2,837/492/776 ms. CDB terminal 0,
four traps, no native exception/engine error, unchanged source and clean worker/
finish drain. Editor retained: this remains a functional, not clean FPS test.

The subsequent **eight-transition attempt failed before its first transition**:
`native-loading-final-prelude-eight-transitions-v1` reports “Original campaign
door did not open.” Movement, gait and strafe probes pass; the door remains
closed in received server state. Its interaction flags differ from the successful
run. The exact server-script/door-state cause is unproven, so this is neither a
successful stress result nor established proof of a new loading regression.
No server state or acknowledgements were fabricated to bypass it.

Retained runner/fixture failures: source-bytes suite v3 omitted `--fixture` and
exited 2 before checks; corrected v4 passes 15. Inheritance fixture v1 had a
GDScript inferred-Variant type error; explicit bool types in v2 pass 16 without
production changes. Older failed receipts and missing-resource replay failures
remain intact. Earlier table-cost temporary cache payloads (about 124 MB total)
were removed using verified exact owned paths; the current fixture removes its
own five content files and empty directory after checking them.

Next measured targets are the remaining 1.7–2.0 second cold terrain-to-player gap,
indivisible first-publication work, and 30–90 ms full-state/transition work. A
possible later optimization is native bulk validation of packed controller arrays;
the current arithmetic extension's shared string-key cache is not assumed safe
on new loader workers. No unvalidated worker use of that cache was introduced.
The full five-area corpus gaps, failed longer door run and broad original-binary/
mixed-client parity remain explicit limits; the overall goal is still active.

Follow-up binary cleanup evidence: `CExoResMan::FreeChunk` 0x14018f740 walks its
free list, skips pinned/demanded entries and stops its loop once the accumulated
freed payload reaches 0x100000 bytes (one indivisible resource can overshoot).
`Free` 0x14018f630 removes the resource's retained list node and releases data on
the explicit path. Complete dossiers are retained as
`rea-loading-six-stage-{freechunk,free}-v1.json`. This is evidence for chunked
logical/physical resource retirement, not proof that the original spends one
megabyte or a fixed time budget every frame; scheduler/caller coverage is limited.

`Update` 0x1401957f0 also periodically checks eligible storage tables for changes
and can drop/rebuild them. Our direct map and resident source caches are scoped
to a mounted session snapshot and replaced on remount, server/resource-context
change or explicit invalidation. Automatic live editing of loose override files
without remounting is not covered by this acceptance. This does not affect the
immutable captured corpus comparisons, but remains an original-workflow parity
question for future development.

Latest authored source checkpoint: `backups/native-loading-optimized-v1.zip`,
1,387 files, verified SHA256
`81f7695b784d4e14488eceb052ebf417db3bd6933289a1f56b40c0f679961176`.
It includes implementation/tests and the documentation as of its creation;
subsequent research notes and receipts are retained separately. Latest re-audit
is `native-loading-six-stage-final-audit-v4.json`. No owned test client remains
running; the editor and both existing owned local server processes are preserved.
The original client SHA256 was rechecked unchanged at 12:18 UTC.

## Native validation and deferred ASCII rotation checkpoint

The additional optimization phase passed two hours at 12:21:32 UTC and continues
under the user's instruction to work until they return. New authored code:

* `native/animation_keys.hpp` reads binary32 key pools through the pinned Godot
  packed-array const API. It checks range/finite/ordered-time constraints without
  scene access, source mutation or the extension's shared string-key map. Godot
  ABI size/hash checks cover the added API. GDScript validation remains available
  as a reference/fallback (`--animation-keys=gd`). ASCII double precision is intact.
* Packed ASCII orientation keys retain original axis-angle values and defer the
  exact existing trigonometry until a selected channel is materialized. Source
  decode identity is now `mdl-actor-packed-v3`, rig identity
  `actor-rig-emitter-v9-deferred-axis`; older cached representations cannot be
  mistaken for the new representation. Older converted descriptors remain readable.

Native validation microbenchmark: 0.95 ms versus 12.58 ms GD for the authored
batch. **No meaningful whole-world player-time gain was observed from that change
alone**: paired same-source generation-3 runs are 3,724.6 ms forced GD versus
3,714.9 ms compiled. Deferred ASCII conversion then measures 3,597.1 ms, with
1,980.2 ms terrain and the same complete 441-object endpoint. These are single
functional observations, not a statistical speed guarantee. `h_ba_custom` packed
decode measured 626 ms versus the earlier ~695 ms; the original key/eager rig
comparisons still pass exactly.

`native_actor_persistent_loading_test.gd` creates fresh catalog/model owners for
each read, preventing session-memory hits from being mistaken for disk reuse.
Exact composed nodes/skins/clips/controllers and source chains match. Observed
first/warm preparation: `pme0` six-model chain 700/333 ms, `c_nulltail` six-model
chain 1,351/334 ms, chest piece 7.5/1.1 ms. All warm ancestors load verified disk
data without reparsing. Its private derived files are removed after the test.
This is parsed-data preparation, not complete actor publication or world latency.

Current focused native suite: **676 checks**, including 252 validation/range/
concurrent-worker cases and 14 persistent-owner cases. Additional existing native
ABI regressions pass 1,227 particle vertex and 2,137 original/mesh collision checks.
`native-loading-deferred-axis-local-v1` passes the current native library/decoder
against the original localhost Prelude server, with sealed capture and clean
native finish/drain. Historical three-transition gameplay and the failed longer
closed-door attempt remain scoped to their earlier exact source snapshots.

Run the current receipt audit with
`node godot-client/tools/audit-native-loading-six-stages.mjs --phase=compiled --run=<new-name>`.
`native-loading-compiled-audit-v1.json` validates current source hashes and those
receipts. The full five-area post-change sweep is in progress. Retained new fixture
failures: persistent-owner v1 used `all` on PackedStringArray and omitted its
catalog argument; the corrected Array conversion/invocation passes v2/current
suite. Geometry runner v1 named a nonexistent script; the actual existing kernel
test passes v2. Neither failure was hidden or fixed by weakening production checks.

Next scheduling experiment: the existing `pending_plan` forbids background
preparation until controlled readiness. Test a small, bounded nearby-scenery wave
after terrain admission while the controlled actor's high-priority job runs.
Preserve the exclusive player request first and compare readiness/population
tradeoffs against a disabled reference. This is not implemented in this checkpoint.

## Bounded entry scenery overlap (current default)

The scheduling experiment is now implemented and enabled. The controlled actor
is still the first exclusive request. Once terrain/surface admission is ready and
that actor's job is already in flight, one background owner may prepare at most
eight nearest scenery/door objects within 20 m. Remote actors cannot take that
window; a completed initial wave cannot start another while control is pending.
Normal nearest-ready streaming resumes afterward. `--entry-prefetch=false` keeps
the disabled reference for comparisons. This eight-object policy is our measured
adaptation, not a claimed original-NWN constant. Original held-model priority
evidence is in `NATIVE-PLAYER-CENTERED-STREAMING.md`.

Same-source fresh-prepared-cache comparisons (single observations; OS/driver
caches not flushed):

| Captured area | Disabled player ms | Enabled player ms | Extra ms | Scenery before player, disabled/enabled |
| --- | ---: | ---: | ---: | ---: |
| Generation 3, complete 441 objects | 3,574.4 | 3,687.7 | 113.3 | 0 / 8 |
| Generation 4, complete 630 objects | 3,472.7 | 3,647.2 | 174.6 | 0 / 8 |
| Generation 1, bounded 22 s observation | 4,061.6 | 4,199.8 | 138.2 | 0 / 8 |

This is a deliberate foreground-completeness tradeoff, **not a claim that control
becomes faster**: roughly 3–5% more initial player wait in these observations
places eight nearby objects before the first playable view. The first-room pair
has the same four explicit missing frozen resources and remains failed full-world
acceptance. For generation 3, the 436th unique admission occurred at 5,422.6 ms
disabled / 5,489.5 ms enabled; the larger difference between first sampled
complete profiles is largely observation cadence and is not an exact load-time
measurement. All complete-area comparisons finish with unchanged required counts.

Current `native-loading-prefetch-audit-v2.json` verifies **685** focused native
checks against current source digests, plus 1,227 vertex / 2,137 collision ABI
regressions. `native-loading-entry-prefetch-default-local-v1` verifies the default
is enabled in an authoritative localhost Prelude load, with sealed resource
capture and native finish/drain. Run
`node godot-client/tools/audit-native-loading-six-stages.mjs --phase=prefetch --run=<new-name>`;
prefetch is also the audit's current default phase.

`native-loading-prefetch-default-five-area-v1` delivers the full frozen timeline:
no native exception or engine/lifetime error, zero remaining workers, retired
worlds and data packets, and a clean finish acknowledgement. It still exits 1
because of missing corpus resources. Sampled retirement peaks by generation are
0.005/1.262/0.954/0.833/0.738 ms; full frame peaks still reach about 91 ms during
state application. Hot generation 3/4 entries do not start an initial scenery wave
when the player is already ready by terrain admission. No unnecessary forced
startup delay is introduced for that case.

Remaining work: isolate actor-specific visual failures from world readiness
(currently a missing remote creature can invalidate an already-rendered player's
readiness); preserve explicit failed-object/full-world diagnostics. Then measure
the cold ancestor-model critical path. Source `actor_data` currently parses each
model before requesting its supermodel; a bounded native data-only ancestor
preparation experiment may overlap independent decoding. Before implementing it,
check original deserializer order, avoid pool starvation/nested single-flight
waits, validate cycles/fallbacks/retirement, and record child work in timing
metrics. No speculative ancestor scheduling exists in this checkpoint.

## Independent creature failure scope

Remote creature/item failures now use the same explicit appearance-bound failure
bookkeeping as independent placeables. Planning, equipment selection, absent
models, shared model decode and actor installation failures carry the actual
object ID. One failed shared source reaches each dependent actor. Valid neighbors
still publish; unchanged failed bindings do not retry every frame. A later server
appearance change clears only that failed binding. A failed replacement preserves
its previously admitted body and remains visibly incomplete in diagnostics.

Shared required-table failure still blocks the area, and failure of the current
controlled actor still becomes an explicit loading error. Stale failed results
cannot poison a newer appearance. Invalid plans no longer queue their earlier
partial model list, and table failure does not proceed by guessing actor plans.
The exact original creature loader failure policy remains **unproven**: additional
symbol searches only located server creature loaders. This change is our explicit
streaming policy, not a claim that those server functions describe client visuals.

`native-loading-actor-failure-v1` passes 27 actual authored raw-table/model,
worker, shared-failure, publication and replacement checks. The existing static
failure test passes 28 checks (`native-loading-actor-failure-static-v1`); its mock
was corrected to implement the current data-detachment lifetime contract.
`native-loading-actor-failure-local-v1` passes the authoritative Prelude load with
sealed resources, no public connections and native finish/drain.

`native-loading-actor-failure-five-area-v1` delivers the original-paced full
capture, with unchanged sources, no native exception/engine error and no remaining
workers. All 109 sampled area observations have zero scope errors and no loss of
readiness after their playable timestamp. Generations 1/2/5 still expose missing
object bytes; the final state retains the missing `dwc_gate_02` object. The run
correctly exits 1 and **does not** claim complete-world acceptance. Individual
isolated complete-area/FPS validation and the current full regression audit must
be rerun after subsequent production changes.

Next experiment is isolated in `tests/native_ancestor_prefetch_experiment.gd`,
not the production renderer. Original deserializer `140079f90` resolves the
supermodel with `FindModel` at **14007a105**, adds its reference at **14007a11c**,
then deserializes animation/physical nodes at **14007a301/14007a36f** (the pinned
`rea-loading-six-stage-binary-deserialize-v1.json` dossier). Our production parser
still decodes each child before its parent. An initial two-immediate-ancestor
experiment passed 15 exact composed-data/drain checks but saved only about
63–73 ms on the two inherited pieces in single observations. A second isolated
experiment selects the largest independent ancestors instead. No global worker,
whole-world or lifetime acceptance is inferred from these microbenchmarks.

## Bounded early ancestor decoding (current default)

`systems/native_data/ancestor_preparation.gd` now implements the measured strategy
for high-priority controlled-actor requests only. It reads a bounded header hint
chain (at most 15 ancestors/32 MiB of source bytes), then starts at most two native
helper threads on its largest independent source parses. A mutex-protected global
two-helper budget uses nonblocking admission. Other asset requests can reuse the
same immutable decoded-source cache without spawning competing helper waves.
Helpers decode one source each: no recursive inheritance, nested pool jobs,
SceneTree/GPU access, or source mutation. Normal composition still owns exact
parent choice, scaling, clip overrides, aliases, failure and cycle/depth checks.

Hints may be absent, truncated or overridden later in ASCII data. A bad speculative
read/decode stays diagnostic; it cannot replace the authoritative result. All
started children join on every normal/error return before their root asset job
finishes or its owner may retire. Child read/decode/cache/coalesced timings and
join overhead are retained in `phases.ancestor_preparation`, rather than being
misreported as free memory hits. Global helper count/peak/default are observable
in the world snapshot. `--ancestor-preparation=false` preserves a disabled
reference. This is our bounded parallel adaptation of the original early-parent
ordering, not evidence that NWN uses these helper threads or constants.

Same-source single paired frozen-world observations, fresh prepared caches,
same engine/driver; OS/driver caches uncontrolled:

| Area/pair | Disabled player ms | Enabled player ms | Disabled/enabled terrain ms | Final objects |
| --- | ---: | ---: | --- | ---: |
| Generation 3, v1 | 3,720.3 | 3,324.2 | 1,943.1 / 2,044.1 | 441 / 441 |
| Generation 4, v1 | 3,615.3 | 3,286.2 | 1,528.9 / 1,617.5 | 630 / 630 |
| Generation 3, reverse run order v2 | 3,661.9 | 3,382.3 | 1,930.0 / 2,088.3 | 441 / 441 |

The candidate shortens whole-world player preparation by about 280–400 ms in
these observations, while terrain preparation becomes roughly 89–158 ms slower
under the extra concurrent CPU work. Camera anchoring remains early (about
20 ms). Required final objects are unchanged and no native crash/engine error
occurs. This is useful latency evidence, not statistical FPS/native-executable
timing parity or a claim that pop-in is solved.

`native-loading-ancestor-verified-suite.suite.json` passes **4,146** assertions:
782 focused loading checks and 3,364 existing native vertex/collision checks.
Its 42 production ancestor cases include exact authored/captured composition,
bad/missing/unused hints, cycles/depth, the global cap, pool saturation, and closing
real asset owners while coalesced child work remains active. All source hashes,
normal-heap CDB/four traps and engine/lifetime checks pass. A new reusable runner
is `tools/test-native-loading-suite.ps1`, taking explicit private fixture paths.
The initial runner joined two PowerShell arguments and the ASCII fixture exited
2 before assertions; that failed receipt is retained. Quoting each argument fixes
the runner; all cases were rerun with the verified prefix. Production checks were
not weakened. `native-loading-ancestor-default-local-v1` passes authoritative
Prelude load/seal/finish with the enabled, bounded and drained default.

`native-loading-ancestor-default-five-area-v1` now completes the original-paced
timeline without a native exception, full engine-log error, or worker/retirement
survivors. Required capture gaps keep its exit 1/full-world acceptance false.
Player-ready times are 4,083.4/699.4/565.6/418.3/410.8 ms across its five areas;
camera anchors at 11.2–30.5 ms. All sampled playable areas retain readiness.
Frame peaks remain 54–71 ms. Old-world incremental retirement can still reach
5.2 ms and its initial begin operation reaches about 23 ms; do not mistake
background data-disposal worker duration for main-thread frame time.

The first paced area has terrain admission at **510.0 ms** but a usable controlled
world object is first observed at **2,220.8 ms**, then control at 4,083.4 ms. This
roughly 1.71-second terrain-to-object gap is part of the frozen presentation
timeline, not proof of current wire/server latency. About 1.86 seconds then remain
for cold actor preparation/adoption. Later entries receive their controlled object
at roughly 39–42 ms. Keep these arrival and preparation costs distinct when
comparing original-paced versus acknowledgement-paced/isolated playback. A future
selected-character source-only warmup might overlap the former gap if authentic
appearance inputs are already available, without inventing live state.

`native-loading-ancestors-audit-v1.json` verifies current source hashes, the
4,146 assertions, paired complete areas, enabled/drained local default and the
explicitly incomplete full capture. Reproduce with
`tools/audit-native-loading-six-stages.mjs --phase=ancestors --run=<new-name>`.
`native-loading-ancestor-prelude-gameplay-v1` reaches native inventory roundtrip,
examine/dialogue, movement, strafe and held gait, but again fails the first campaign
door with no open acknowledgement. Zero completed transitions; source unchanged,
no native exception/engine error. This is a repeated open gameplay acceptance gap,
not a successful transition test or proof of the server script's cause. The earlier
three-transition success remains tied to its historical source snapshot.

Next measured hitch targets: the previous five-area run peaks around 59.5 ms in
protocol application, 29.6 ms applying the received world/UI snapshot, 24.9 ms
beginning old-area retirement, and 29.0 ms in mesh CPU publication. These spans
overlap and must **not** be added. Original binary part deserialization includes
bulk `memcpy` (`14007b0e7` → `140c417f0`), while our `resource_pool.prepare_geometry`
still loops through coordinate conversion, index reversal and normal generation
on the main thread. A next compatible candidate is data-only prepared mesh upload
arrays on workers, retaining main-thread ArrayMesh/GPU creation, raw collision/
skin data, exact winding/normals/UVs and explicit decoder cache invalidation.
No such geometry-worker change is implemented at this checkpoint.

Additional cold texture evidence in the final sweep: the controlled batch's
head/foot texture phases take about 379–430 ms on their first palette-dependent
preparation; a neighboring `wmgst_t_122` model spends about 1,566 ms in textures
despite only about 10 ms in model preparation. `texture_data.gd` still converts
TGA/DDS pixels and `palette_texture.gd` scans/blits PLT pixels in GDScript. A native
data-only exact-pixel conversion path is another next candidate, alongside
single-flight palette preparation. Inspect the original CResTGA/PLT behavior and
preserve all pixel/alpha/origin, palette dependency/color and corrupt-input checks.
At that ancestor checkpoint, compiled raster/PLT conversion and palette
coalescing were not implemented; the following section describes current work.

## Compiled exact-pixel conversion and shared palettes (current default)

Read-only original research was refreshed against unchanged executable SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
`CResTGA::OnResourceServiced` **1401a4730..1401a4966** dispatches RLE readers and
swaps RGB bytes in a compiled loop at **1401a4940..1401a4953**. Its descriptor
origin bits do not change the stored row order. `ReadUnmappedRLETGA`
**1401a4ac0..1401a4d37** expands 24/32-bit packets with compiled byte copies.
`CResPLT::OnResourceServiced` **1400fab60..1400fabee** retains raw indexed data
or calls `ReadRLEPLT` at **1400fabba**. Earlier `AurCreatePaletteTexture`
**1400e5a70** copies the shared master palette at **1400e5b3f**. These refreshed
dossiers are `backups/animations/rea-loading-raster-{tga-service,tga-rle,plt-service}-v1.json`.
The existing unchanged-code 288-case TGA resource oracle is still used; its SHA256
is `1631828109384843f926fb9e9119f97794e8fb1727e5ea55991c1a8f86802b5c`.
This evidence covers CPU resource handling, not original GPU palette sampling.

`native/raster_conversion.hpp` now exposes bounded TGA/RLE/DDS channel conversion,
PLT first-encounter layer discovery and PLT row lookup/blit through the pinned
GDExtension. Inputs remain read-only; private byte outputs are the same bytes
produced by the GD reference. No GPU/SceneTree/Image objects, file/network calls
or extension shared string-key map are used by these worker routines. Packed
input ABI sizes/API hashes are checked against the pinned engine, and method
pointers bind once before workers start. Invalid native conversion falls back
to the existing GD validation and precise error messages. The same bounded pixel
limit applies. Original oracle coverage is RGB/gray resource handling; other
admitted codec forms are checked against the existing GD behavior, not claimed
as complete original malformed-codec/GPU equivalence.

Godot retains its existing baked RGBA/mip/material flow. A complete master-palette
shader migration would also need original sampling/filtering/lighting equivalence;
the compiled bake removes the observed CPU bottleneck while preserving current
texture bytes and rendered material rules. Source/palette/color identities and
persistent pixel-cache keys stay unchanged because the output is exact. Palette
source decoding now uses a content-addressed single flight and immutable shared
pixels, including error wakeups. First-encounter dependency order stays intact.
Changed palette bytes on a new mount or changed used color rows produce a new
identity/pixel result. Existing disk results still verify and reload correctly.

Representative single-observation exact-output microbenchmarks:

| Source/work | GD ms | Compiled ms |
| --- | ---: | ---: |
| Captured `i_spidstf_002`, 4,032,000 input bytes | 1,273.6 | 2.5 |
| Captured `c_amethyst`, 1,048,620 input bytes | 386.9 | 1.2 |
| Captured `c_diamond`, 1,048,620 input bytes | 390.8 | 1.0 |
| Authored PLT, 131,072 pixels | 78.5 | 0.6 |

Faster texture work exposed a scheduling interaction: a second expensive actor
root reached the global ancestor budget while the first root owned both helpers.
The second then decoded serially. A same-source complete 441-object comparison
measured 3,533.6 ms player readiness with up to two helpers per root, versus
3,175.4 ms with **one helper per root / two globally**. The latter is now the
default; `--ancestor-share=2` retains the earlier share for diagnosis. The global
cap and join/retirement rules stay unchanged. This is our measured scheduling
adaptation, not an original binary constant.

An alternative animation-source-first actor queue raised player readiness from
3,149.2 to 3,377.3 ms in its complete 441-object pair. It was rejected: its
production branch, CLI flag and standalone fixture were removed after preserving
the authored candidate checkpoint `native-loading-raster-candidates-v1.zip`
(SHA256 `652fbdfbcb4eb72688f5e83958227fec7a79de78457b150aa92749ee11e971e7`).
Physical/source request hierarchy order remains unchanged.

Final same-source raster-mode pairs, one helper/root in both, fresh prepared
caches and unchanged engine/driver; OS/driver caches uncontrolled:

| Area | GD/compiled tiles ms | GD/compiled player ms | Final objects |
| --- | --- | --- | ---: |
| Generation 3 | 1,977.1 / 1,577.7 | 3,237.0 / 3,200.3 | 441 / 441 |
| Generation 4 | 1,555.0 / 1,221.2 | 3,216.5 / 3,197.9 | 630 / 630 |

For generation 3 the uncapped admission log's last object admission is
6,997.0 / 6,198.1 ms (GD/compiled). Generation 4 reaches the diagnostic 512-entry
cap, so its last tracked entry cannot establish world completion time. Different
intermediate appearance replacements change cumulative GPU creation counts;
those are not final scene/object counts. Required final object counts remain the
same. Pixel conversion substantially improves terrain/background preparation;
**player readiness is essentially unchanged in these final raster-mode pairs**.
This is not statistical FPS, original-GPU equivalence or a claim that pop-in is
solved. Candidate v1's later observation window overlapped a headless fixture;
standalone candidate v2 is used for the final generation-3 pair.

`native-loading-raster-suite.suite.json` passes **4,779** assertions (1,415 focused
loading checks plus 3,364 existing ABI/vertex/collision checks). New coverage:
608 exact raster checks including the 288 original cases, seeded malformed
headers/packets, integer/range rejection, PLT order/color/alpha, private outputs
and concurrent worker calls; 25 actual palette prepare/coalescing/error, cache,
remount/color invalidation and large-bake checks. All source hashes, normal-heap
CDB/four traps and full engine/lifetime checks pass. Initial retained failures:
the GD adapter needed explicit integer width/height annotations, and the new
fixture mistakenly called a float-style method on int. Both were corrected and
the entire current suite rerun. The compiled build also caught a const-qualified
ABI wrapper mismatch before linking; the read-only size call now has the explicit
API-required wrapper cast. No production acceptance check was waived.

`native-loading-raster-default-local-v1` passes the authoritative localhost
Prelude load/sealed resource capture, with compiled pixels available/enabled,
fair helper default, zero unfinished workers and clean native finish. It is a
load-only check; the earlier unresolved campaign door attempt is historical
gameplay evidence, not current-raster transition acceptance.

`native-loading-raster-default-five-area-v1` now delivers the complete original-
paced timeline with unchanged sources, no native exception/full engine-log error,
zero outstanding asset/data/retired-world work and a clean finish acknowledgement.
It still exits 1 for known missing frozen resources; final `dwc_gate_02` remains an
explicit failed object. No installed/network fallback is used. Sampled player
readiness stays available after admission in all five areas. Player-ready times
are **3,719.3/716.3/547.3/429.4/450.1 ms**; camera anchors at 11.0–38.5 ms.
The first usable controlled object still arrives at 2,237.3 ms in that recording,
leaving roughly 1.48 seconds of cold preparation/adoption. Frame peaks remain
53.8/69.2/61.8/79.6/75.1 ms: this is not hitch-free loading acceptance.

`native-loading-raster-audit-v1.json` verifies current source digests, 4,779
assertions, the original oracle hash, same-source complete-area pixel-mode pairs,
default localhost load, bounded/drained helpers, readiness continuity, and the
strictly incomplete full capture. Reproduce with
`tools/audit-native-loading-six-stages.mjs --phase=raster --run=<new-name>`.
Mesh publication and transition-state application remain the next measured
main-thread targets. The goal remains active.

## Exact worker mesh derivatives and bounded GUI reuse (16:02 UTC)

Original-method evidence uses the same pinned NWN:EE 89.8193.37-17 x64 executable
and SHA256 above. `MdlNodeTriMesh::InternalPostProcess` at **0x1400a9ae0** gates
setup at field +284. Its initial path calls `ProcessVerts` at 0x1400a9b0a,
`BuildNeighborLists` at 0x1400a9b39, `BuildVertexIndices` at 0x1400a9b41,
`GenerateVertexData` at 0x1400a9b49 and tangent preparation at 0x1400a9b51.
`BuildVertexIndices` (**0x1400a5e20**) requests a render pool at 0x1400a5fe2,
locks it at 0x1400a6064 and unlocks it at 0x1400a60ba. This supports separating
one-time geometry preparation from instance publication, not a claim that the
original uses our worker topology. Read-only dossiers:
`../backups/animations/rea-loading-mesh-{postprocess,build-indices}-v1.json`.

`native_data/mesh_preparation.gd` now computes exactly the former main-thread
positions, normal generation, UVs, winding, bounds and missing ASCII face planes
in the existing bounded source workers. Serialized original binary face planes,
collision face order/materials, raw mesh fields and empty physical parts remain
unchanged. Only typed data enters immutable source/prepared caches, versioned
`mesh-upload-v1` with separate mode identities and raw-content verification.
`ArrayMesh`, GPU textures, scene nodes, pick shapes and mutable actor state stay
on the main thread. The legacy path is retained with `--mesh-preparation=main`;
normal startup uses worker data. Actual policy/use/fallback counters appear in
`world.pool.mesh_preparation`, `prepared_mesh_uses`, `main_mesh_preparations`.

Same-source complete-area observations (fresh prepared caches, OS/driver caches
uncontrolled) lower sampled mesh-publication peaks from **11.54 to 7.58 ms** in
441 objects and **13.77 to 3.87 ms** in 630 objects. There were no candidate
conversion fallbacks. Player readiness was 3,121/3,049 ms and 3,147/3,226 ms,
respectively: publication improves, cold character readiness is essentially
unchanged. Overall pre-player frame peaks did not consistently improve. A later
same-source 630-object pair with corrected profiling measures mesh peaks
12.12/4.67 ms, player 3,098/3,209 ms, ready-window frame peaks 22.38/12.93 and
40.62/28.18 ms. These are individual diagnostic observations, not statistical
FPS or original-client timing acceptance. Area-4 admission records hit the
512-entry diagnostic cap; they cannot establish the last admission time.

Profiling exposed a real missing measurement: `frame_post_draw` continuations
ran after the collector and were cleared at the next frame. They now survive as
`postdraw_` spans in the following wall interval. Those spans overlap children
and can include asynchronous waits; never add them to callback CPU totals.
Readback itself took about 1 ms, but immediate temporary GUI-model destruction
took 97–159 ms during entry. Separate cleanup/upload/notification/rig-close
spans identify cleanup; measured rig close was only 0.006 ms. The precise engine
destructor/driver contention inside that synchronous free is not established.

The original GUI retains a model pointer at +0x10: `CGuiObject::SetModel`
(**0x1401fb710**) calls `NewCAurObject` at 0x1401fb74e and destroys the previous
object at indirect call 0x1401fb841 when replacing the model.
`CGuiButton::HandleMouseoverHilite` (**0x1401e56f0**) invokes the existing object's
animation at indirect call 0x1401e572f rather than reconstructing a model. Dossiers
`rea-loading-gui-set-model-v1.json` and `rea-loading-gui-button-hilite-v1.json`
record the evidence; unresolved virtual targets stay unresolved. Our baked GUI
is an adaptation: up/down/hilite states now reuse private physical GUI actors
with identities covering source/texture/animation dependencies and layer choice.
The working set is bounded at 32 models, each at most 512 descendants. Roots are
hidden and rigs stopped between bakes. Rotated models and sources containing
emitters, references or lights use the existing transient path. At capacity the
old transient path runs instead of evicting during entry. All retained scene/GPU
owners still free on the main thread at session shutdown; this does not remove
their ultimate teardown cost. `--icon-model-reuse=false` retains the reference.

`native-loading-icon-cache-{reference,candidate}-v1` both complete all 630 objects
and render 28 UI states. Reuse retains 12 roots and reuses them 16 times. Sampled
post-draw cleanup peaks fall **105.23 to 0.018 ms**, total icon completion
106.30 to 3.34 ms, and overall sampled frame peak **132.30 to 54.65 ms**. Player
readiness is **3,145.6 / 3,268.0 ms**; terrain 1,240.7/1,279.1 ms. Do not present
this as a lower cold-entry latency measurement. Other entry work remains.

`native-loading-mesh-suite.suite.json` passes **5,677 assertions across 33 cases**:
846 exact worker/old mesh comparisons using actual upload/pick/collision paths
and original captured body/large tile/prop/creature models; 14 real worker/cache
identity, warm reload, corrupt-file repair and source-change cases; 10 actual
failed-parser coalescing cases; 8 graphical post-draw lifecycle checks; 20
graphical GUI original-pixel/bounds, bounded reuse/fallback and teardown checks;
plus the earlier 4,779 checks. Source and DLL hashes, normal-heap CDB/four traps,
full engine/lifetime logs all pass. The first GUI fixture failed due to an
inferred-bool compilation error and a fixture API typo (`open` vs `mount`);
corrected v2 and the entire current suite pass. Failed logs are retained.

Candidate checkpoint `backups/native-loading-mesh-candidates-v1.zip` is verified,
SHA256 `9b433793b0b784758cf6f091efb1423570b069714e3f5222419eb49b45ee26c3`.
It preserves the opt-in mesh experiment before GUI reuse/default changes. The
final source checkpoint follows validation. No public-server connection was
made. Goal remains active.

Default validation completed at 16:10 UTC. Isolated generations 3 and 4 complete
441/630 objects; player-ready 3,408.8/3,252.0 ms, terrain 1,646.5/1,239.8 ms and
zero main-thread conversion fallbacks. The authoritative localhost Prelude
load/resource capture (`native-loading-mesh-default-local-v1`) passes 19 entities,
277 prepared meshes, zero conversion fallbacks, zero workers and native finish
acknowledgement. This is load-only; previous unresolved campaign-door gameplay
coverage stays historical and is not promoted to success.

`native-loading-mesh-default-five-area-v1` delivers the entire original-paced
timeline, unchanged sources, clean engine/native lifetime and zero outstanding
workers, data disposal or retired worlds. Final `dwc_gate_02` remains missing from
the capture; the run truthfully exits 1 and is not a complete-world pass.
Player-ready times are **3,811.0/736.8/527.4/453.1/374.3 ms**, terrain
500.5/719.3/515.4/445.9/368.6 ms and camera anchors 11.3–41.3 ms. Readiness stays
available after admission in all sampled areas. Sampled area frame peaks are
39.7/30.6/61.6/83.7/74.4 ms; loading is not hitch-free. The new icon policy's
effect is supported by its same-source isolated comparison, not a cross-phase
claim about this uncontrolled full sweep.

The next measured costs are explicit in the full-sweep profile: generation-4
protocol apply is 62.9 ms, including incoming world/UI application 33.3 ms and
transition retirement begin 18.2 ms (child spans overlap). Final old-world
retirement begin reaches 23.2 ms. These are CPU callback work rather than a
render-GPU attribution. Another post-admission actor publication reaches 30.1 ms
with only 2.1 ms in mesh conversion/submission. Profiler summary/encoding also
adds diagnostic overhead and must not be mistaken for unprofiled FPS.

`native-loading-mesh-audit-v1.json` verifies the current 2,313 focused assertions
plus 3,364 native ABI checks (5,677 total), current source hashes, original raster
oracle, actual GUI graphical tests, retained same-source geometry/icon pairs,
default complete-area/local paths, bounded/drained helpers and explicit five-
area gaps. It does not accept full gameplay, mixed-client parity, statistical
performance or original-executable timing parity.

## Transition retirement (candidate comparison completed 16:25 UTC)

The earlier pinned area-retirement dossier maps unnamed routine **0x1407e7770**
(`../backups/animations/rea-world-area-retirement-v1.json`). It iterates its owned
object-ID array at +0x2c8/count +0x2d0: lookup at **0x1407e7906**, then registry
delete at **0x1407e7933** and object destruction at 0x1407e7943. This is evidence
of explicit owned collections, not a Godot-style generic descendant-name scan;
no claim is made that the original uses Godot physics or our deferred retirement.

Our old retirement first hid/disabled the whole area, then recursively searched
its entire hierarchy to zero every collision mask. Actual engine ray fixtures
prove that native collider defaults (`PROCESS_MODE_INHERIT`,
`DISABLE_MODE_REMOVE`) already remove bodies from physics immediately when the
area is disabled. Rays stop hitting them before another frame, remain clear
while the old scene/workers stay retained, and hit the original shape again on
re-enable. The duplicate scan is now removed by default. The diagnostic reference
is `--retirement-physics=scan`; `world.retirement_physics_scan` records the actual
mode. New collider creation must retain the inherited/remove policy or supply
explicit lifecycle handling. Scene/GPU cleanup remains on the main thread.

The authored two-path 25,000-node fixture measures 8.7 ms old retirement versus
3.3 ms inherited removal. `native-loading-transition-{scan-reference,inherit-candidate}-v1`
then delivers the entire identical sealed original-paced five-area timeline in
both modes. Both truthfully exit 1 for the same missing captured bytes, with no
native/full-engine/lifetime failure, zero remaining workers/data disposal/retired
worlds and native finish acknowledgement. Four retirement begins total
**76.27 / 52.73 ms**, peak **23.68 / 15.68 ms**, reference/candidate. Sampled frame
peaks at generations 3–5 are **66.44/59.18, 83.77/71.12, 74.43/70.41 ms**. Player
ready timings are essentially unchanged. These are individual same-source
observations, not statistical timing, complete-world or original-client parity.

Finer child spans now separate incoming world application, UI reset/object map/
inventory/desktop replacement and retirement hide-disable/audio/scan/cancel.
Reference generation-4 world application is 7.85 ms and UI 26.62 ms, of which
desktop replacement is 24.00 ms; inventory 1.34 ms, object map 1.23 ms and reset
0.026 ms. Retirement hide-disable is 11.30 ms, duplicate scan 4.75 ms, audio
0.067 ms and cancellation 0.019 ms. Child spans overlap their owner; they must
not be summed with the owner callback. Desktop state replacement is the next
measured target; its control reset versus detached raw-state release is not yet
attributed. Do not assume all of it is GPU rendering or network wait.

Final current-default receipts: `native-loading-transition-default-area{3,4}-v1`
both pass 441/630 objects with zero mesh fallbacks and the recursive physics scan
off. Player ready is 3,223.2/3,250.2 ms. Area-4 current-default coverage overlapped
brief metadata inspection and is validation only, not a clean timing comparison.
`native-loading-transition-default-local-v1` passes the authoritative owned
Prelude load/capture. `native-loading-transition-default-five-area-v1` delivers
the whole original-paced timeline with no engine/native failure, zero asset/data/
retired-world work, acknowledgement and the same explicit missing captured model.
It truthfully exits 1. Readiness stays available after admission across all five
sampled areas: player **3,729.4/713.3/545.6/442.8/409.2 ms**, camera 10.7–36.6 ms.
Sampled frame peaks **43.8/34.8/62.5/71.7/70.6 ms** remain above hitch-free targets.
Four retirement begins total 53.7 ms, peak 16.9 ms.

`native-loading-transition-verified-suite.suite.json` passes **5,693 assertions
in 34 cases** (2,329 focused + 3,364 native ABI). Retirement now uses real ray
checks, including 78 held-worker/next-world/overflow checks and 10 inherited-body
physics checks, rather than requiring masks to be rewritten as an implementation
detail. Initial expanded-fixture failure observed valid completions during its
new physics setup frames; the observer now attaches immediately at retirement.
Zero post-retirement completions remain required, and all cases were rerun under
the verified prefix. The failure remains retained. The current audit verifies
current sources/full logs, default modes, comparisons and incomplete capture
scope. A source checkpoint is saved as
`backups/native-loading-inherited-retirement-v1.zip` after these validations.

Next player-readiness lead, not implemented: reconstructing the recorded first
area shows object **4294965485** already has its correct area, complete 19-part
appearance/3 equipment entries and three-coordinate pose at **+1,829.0 ms**.
The header's controlled ID is still INVALID (2130706432); it becomes that object
at **+2,239.9 ms**. Our controlled-first gate postpones other actor preparation
until the controlled identity arrives. A bounded nearby canonical-actor warmup
before that assignment may hide some of this 411 ms gap without inventing control
authority. First verify original object-creation versus controller-assignment
ordering and evaluate competing NPC/appearance-change/error cases; do not label
an actor as controlled by proximity. Separately split desktop reset/object-map/
header replacement and actor install phases before selecting their next fix.

### Rejected early-actor experiment (17:17 UTC)

Fresh read-only model/AI dossiers (`rea-loading-early-creature-{model,ai}-v1.json`)
cover `CNWCCreature::LoadModel` 0x140802cc0..0x140803382 and AI 0x1407fbd10.
The model routine owns/reuses a per-creature animation object at +0x78 and invokes
its load virtual at 0x1408030af; control lookup is absent from that complete body.
This supports model preparation being separable from input ownership, but does
not prove the full original scheduler or its order before control assignment.
No Ghidra annotation or original process/binary was modified.

An opt-in candidate prepared one canonical creature after terrain admission while
control was INVALID. A broad 20 m radius selected an NPC at 12 m before the player
arrived and did not help. A 2 m radius selected the real player's existing state
about 405–412 ms before control assignment. Initially its source jobs chose serial
ancestor decode; making bounded entry-data priority independent of authority
enabled both helpers. Runtime and tests kept input/camera control tied to the
received ID, promoted matching in-flight work, demoted wrong/stale appearances,
rejected late removed results, and promoted exact failed models to required errors.
The final authored fixture passes 30 real-worker/publication/authority checks.
Its initial v1 failure was an incomplete authored static-rule fixture; v2–v7
corrected required tables and expanded coverage without waiving assertions.

Two same-source, first-area original-paced 30-second pairs with fresh prepared
caches and opposite run order still show no useful improvement:

| Observation | Reference player ready ms | Early player ready ms |
| --- | ---: | ---: |
| Reference then candidate, v3 | 3,634.3 | 3,592.5 |
| Candidate then reference, v4 | 3,579.4 | 3,605.0 |

Both candidates chose object 4294965485 early; no stale appearance invalidation
occurred. Largest source work grew enough to offset the earlier start. Every run
completes its bounded observation with the same four captured-resource failures,
no other world error/native crash, zero unfinished workers and finish ack. They
are partial timeline observations (not full replays) and not statistical FPS
acceptance. The experiment is rejected rather than adding unhelpful runtime
complexity. Complete candidate source is archived before restoring the verified
inherited-retirement production flow. Next target is measured large-model source
decode cost and separately desktop replacement/actor install child spans.

### Direct ASCII key writes and raw UI handoff (verified, 18:01 UTC)

Read-only `AddGenericController` 0x140098570..0x140098783 in the same pinned
`nwmain.exe` parses keys at call 0x1400985bb and appends times/values into a
contiguous float pool (stores at 0x140098646/0x1400986c3), using geometric growth.
The full dossier is `../backups/animations/rea-loading-ascii-controller-v1.json`.
Our existing double-precision ASCII pools now receive values directly instead
of building, slicing and converting a boxed Array for every key. Counted streams
allocate once; uncounted lists grow geometrically under the existing count cap.
Original ASCII double precision, axis-angle, all physical/animation fields,
Bezier values and validation/error precedence remain unchanged. Binary key
decoding is unchanged. `--ascii-key-write=arrays` retains the exact old reference
path for comparison.

The 81-check actual-parser fixture loads the old authored source from the
hash-verified inherited-retirement checkpoint, then compares entire serialized
graphs/errors against both current paths. It covers four original captured ASCII
models, counted/uncounted keys, allocation boundaries, double extremes and bad
numeric/shape/order input. The exploratory decode-cost fixture also passes nine
checks. `h_ba_custom` isolated decode was 652.8 ms before and 574.5 ms with indexed
typed writes; same-process reference/candidate was 633.6/569.3 ms. This reduces a
measured source cost, not an established general entry-time improvement:

| Complete cold area observation | Old array-write player ms | Direct typed player ms | Objects |
| --- | ---: | ---: | ---: |
| Generation 3, reference first | 3,140.4 | 3,200.7 | 441 |
| Generation 4, candidate first | 3,251.7 | 3,080.2 | 630 |

Both pairs use identical source/recording hashes, fresh prepared caches, CDB/four
native traps, zero game-server connections, exact final coverage, clean engine
logs and drained workers. OS/driver caches were not flushed; these single pairs
do not prove a statistical latency or FPS gain. Checkpoint before the next change:
`native-loading-typed-ascii-candidates-v1.zip`, SHA256
`c1b7ffa13f35aa1d51d40774e098c451c1fcf6f9e73bf7f3632cc97192bc8515`.

Finer actor installation spans show binding/setup peaks around 16 ms and rig
setup around 10 ms, with roughly 4 ms each spent in skin-source expansion and
skin runtime creation. Spans overlap and must not be summed as frame totals.
Read-only `MdlNodeSkin::InternalCreateInstance` 0x1400df1a0..0x1400df1fd allocates
a 0xc0-byte private part and calls `PartTriMesh` construction at 0x1400df1d4.
The constructor 0x140087fd0..0x14008811b stores the model pointer at
0x140088028 and creates private material state at 0x1400880ab. These routines
support private instance/shared source ownership; they do not establish the
complete original skin/GPU pipeline. Separate skin-instance/part-mesh dossiers
preserve this evidence. Worker skin derivatives remain a possible next change.

The five-area trace with finer desktop spans completes its timeline with only
the known missing `dwc_gate_02` captured bytes, no native/engine failure, and
clean shutdown. Old desktop object-map replacement alone costs 5.0/9.9/12.1/13.2
ms across transitions; menu-view resets cost only 0.5–0.6 ms. The accepted candidate
retains only the replaced raw JSON map/header through the existing two-frame
bounded data-disposal owner, then releases those extra references on a worker.
No UI controls, projected menu state, GPU resources or same-map live incremental
updates enter that packet. Optional-owner fallback is guarded with `has_meta`.
Its actual held-worker fixture passes 20 checks with clean engine/lifetime logs;
the initial unguarded metadata engine-error receipt remains retained.

Same-source `native-loading-ui-handoff-main-v1` versus default
`native-loading-typed-final-five-area-v1` delivers the entire original-paced
timeline. Both end with 922 entities, exactly the same missing `dwc_gate_02`
failure, zero other world errors, no native/engine failure, four safely released
old worlds and zero pending workers/data packets. Worker mode schedules four
additional raw-state packets (519 versus 515 total data tasks), with no forced
drains. Both runs reach the same existing bounded deferred-overflow fallback
three times; it is not evidence of an unbounded queue.

| Sampled transition | Main desktop handoff ms | Worker desktop handoff ms | Main / worker sampled frame peak ms |
| --- | ---: | ---: | ---: |
| 3 | 10.142 | 0.623 | 60.985 / 49.529 |
| 4 | 24.794 | 0.721 | 82.385 / 54.302 |
| 5 | 14.120 | 0.519 | 69.953 / 53.163 |

These are overlapping profiled phase/window peaks from single paired runs, not
an exhaustive event trace, statistical FPS acceptance, or proof all stutters are
gone. Transition 2's detailed event fell outside the sampled window and is not
invented in the table. The object-map replacement itself is about 0.001 ms after
retention; view reset remains about 0.5–0.7 ms. Scene/GPU destruction stays on main.

Final complete cold replays `native-loading-typed-final-area3-v1` and area4
reach all 441/630 objects with player readiness 3,149.1/3,204.8 ms, complete
terrain 1,605.2/1,254.9 ms, early camera anchoring 21.6/24.2 ms and zero legacy
main-thread mesh-preparation fallbacks. The current localhost original Prelude
load passes with 19 entities, sealed native resource capture and clean shutdown;
this remains a loading check, not new combat/door-transition acceptance.
`native-loading-typed-suite.suite.json` passes 5,794 checks across 36 cases
(2,430 focused native loading plus 3,364 ABI checks). Current audit verifies all
source hashes, CDB/four traps, full engine logs, required coverage and explicit
scope limits. Original executable SHA256 was read-only rechecked unchanged.

Next measured targets: private actor skin expansion/runtime upload and first
static-template construction, plus optional prepared-cache writes still on the
decode worker's critical path. A tiny foot-piece source observed a 12 ms cache
write wall span; that includes scheduling/IO and is not a CPU attribution.
Evaluate bounded deferred cache publication against exact cache integrity,
source-graph lifetime and shutdown tests before changing its default.

Verified authored checkpoint: `backups/native-loading-typed-handoff-v1.zip`,
1,410 files, SHA256
`49a999f1f20b6806b79ff4116cd6d4696826845f2cafbd4b601a50638ec9fa81`.
The archive predates only this self-hash note; runtime/test sources match the
current-source audit. It contains no original game assets or credentials.

Later working-tree experiment: `--prepared-cache-write=sync|disabled` measures
the upper bound from removing optional prepared writes, retaining all canonical
resource reads/model data. The prior typed audit/checkpoint remains the verified
baseline; new diagnostic source hashes are not yet the audited default. Both
complete-area pairs succeed with identical source/input hashes, no native/engine
error, full final coverage and clean drains. Generation 3 reference/disabled:
player 3,185.4/2,928.3 ms, terrain 1,698.8/1,199.1 ms and last uncapped admission
6,315.5/5,516.0 ms. Reversed generation 4: player 3,021.9/2,810.2 ms, terrain
1,224.6/879.4 ms, all 630 objects. These are single observations, not general
performance acceptance or justification to disable persistence by default.

Added save-phase telemetry shows the generation-3 model-source aggregate at
384 ms serialization, 77 ms checksum, 62 ms file write, less than 1 ms flush and
434 ms final publication for about 32 MB of prepared payloads. These worker wall
spans overlap other activity; their sum is not main-thread CPU. A compiled
binary/ASCII source reader does not establish an equivalent original decoded
disk cache: existing ReadSync dossiers show direct binary deserialize or dofile
ASCII load, but whole original cache/publication behavior remains unproven.
Next candidate should retain persistence with one bounded low-priority native
writer, coalesced content identities, immutable model/rig payloads only, and an
explicit last-owner shutdown drain. Generic mutable GFF/table data and scene/GPU
resources must not enter that queue. Measure queue overflow, cold/warm integrity
and actual first-player/nearby-scene outcomes before adopting it.

### Bounded background persistence and per-destination locks (verified, 18:38 UTC)

The next native candidate moves only decoded MDL source persistence off the
asset worker's completion path. The decoded graph is first published immutable
to its existing store; mutable consumers receive the established private
wrappers/copies. The writer retains an outer-header snapshot and uses that
store's existing serialized-size charge, avoiding another sizing serialization.
One `Thread.PRIORITY_LOW` writer handles at most 128 retained packets/64 MiB of
estimated serialized data. That charge is not a hard RSS claim. Duplicate
destination/content identities coalesce. Full queues skip optional disk
persistence, never canonical bytes, live models or geometry. Corruption checks,
decoder/content identity and atomic temporary-file publication are unchanged.
Rig/other derivative writes remain synchronous; generic mutable GFF/table/UI/GPU
state never enters this queue.

Asset services share leases. The native application now also holds a lifetime
lease, keeping disposal outside transient world/menu close paths; after all
owners finish, shutdown drains and joins the writer. Pending/peak/skip/failure
and completed-byte counters are explicit. Actual held-worker tests pass 27
checks for delivery before disk completion, exact typed data/doubles, limits,
duplicate keys, private rig metadata, missing destination, shared owner release,
fresh-store disk reuse and complete shutdown. No original game data is included
in those authored fixtures.

The cache's old global publication mutex held filesystem fingerprint/repair/
rename work for unrelated paths. The candidate protects small proof/lease maps
globally but uses a refcounted gate per destination for filesystem operations.
Leases disappear after the last waiter. A 13-check real-thread fixture holds one
path, proves its same-path competitor cannot enter, and lets a different path
fully commit/reload before release. Same-length corruption/repair and cleanup
also pass; the existing 16 integrity cases pass in path mode. This is a measured
adaptation, not a claim of an equivalent original decoded disk-cache design.

An eight-run same-source factor comparison (fresh prepared caches, reversed
order for area4) completes all required objects with clean CDB/engine/shutdown:

| Area | Write / lock | Player ready ms | Terrain complete ms | Last uncapped admission ms |
| --- | --- | ---: | ---: | ---: |
| 3 | sync / global | 3,352.8 | 1,672.8 | 6,437.1 |
| 3 | sync / path | 3,231.1 | 1,613.2 | 6,139.0 |
| 3 | deferred / global | 3,101.8 | 1,498.5 | 5,946.6 |
| 3 | deferred / path | 3,083.1 | 1,402.5 | 5,966.3 |
| 4 | sync / global | 3,227.7 | 1,336.5 | capped |
| 4 | sync / path | 3,240.3 | 1,294.9 | capped |
| 4 | deferred / global | 3,134.2 | 1,161.2 | capped |
| 4 | deferred / path | 2,929.3 | 1,073.4 | capped |

Deferred runs save every eligible source with zero skips/failures; queue peaks
range 57–112 packets, remain within the estimated-byte bound, and drain to zero
on exactly one thread. A prior 16-packet experiment skipped 74 optional writes;
it is retained but not selected as the policy. The current 128-packet bound
preserves all writes in this corpus. OS/driver caches are uncontrolled; these
single factor observations do not establish statistical FPS, no-pop-in or
original-executable loading parity. Sync/path alone does not consistently lower
player readiness. Combined deferred/path is selected for full default validation.

The pre-default candidate is archived as
`backups/native-loading-deferred-cache-candidates-v1.zip`, SHA256
`563ec082267cc84ea92ffe08654a7c6a55c382269cab7b987f907fecd84ff00f`.
It retains the earlier 16-packet/single-lock experiment, not the final policy.
The first new full suite stopped on an old held-decoder test override signature;
the optional argument/forwarding now matches production, assertions are intact,
and the entire current-source suite was rerun under
`native-loading-cache-verified-suite`. The 18:01 typed audit remains historical
for the changed runtime; final default/local/paced coverage is recorded below.

The new full suite has now passed 5,834 checks across 38 cases with unchanged
current runtime/test hashes, native CDB/four traps and clean full engine logs.
This includes the corrected 10-check failed-model case, unchanged assertions,
plus 27 writer/13 path-concurrency checks. The default whole-route replay finishes
with all recorded frames delivered, 922 final entities, exactly
the known missing `dwc_gate_02` resource and no other world error/native/engine
failure. All 1,616 eligible source writes complete on one thread with zero skips,
failed writes or pending work; peak 54 packets/about 8.9 MB serialized estimate.
Application shutdown releases every lease, joins the writer and receives finish
ack. The complete default generation-3/4 replays reach 441/630 objects, no legacy
main-mesh fallback, player readiness 3,153.9/3,107.8 ms, terrain 1,500.3/1,125.7
ms and early camera anchoring 26.0/30.9 ms. The localhost authoritative Prelude
load passes with 19 entities and a drained native writer. This is still load-only
local coverage, not new combat/door-transition acceptance. The current receipt
audit passes 2,470 focused loading checks plus the 3,364 ABI checks, verifies all
current source hashes and preserves the partial-capture/performance limitations.
Reference/candidate terminal screenshots show the same visible geometry and
recorded framing; this is not an original-client visual parity or FPS oracle.
Next publication targets after this checkpoint are worker-prepared skin streams
and shared immutable rig clip metadata. Preserve original flat-normal/winding,
four-weight/64-slot sentinel and binding validation semantics, private skeletons,
events/clocks and render-thread resources; measure each change before adoption.

Verified authored source checkpoint: `backups/native-loading-background-cache-v1.zip`,
1,413 files, SHA256
`25be0a6ac95d25d7664eccc7256322696e2c7aa37e19a84c9d059f7d99d1478b`.
The archive predates only this self-hash note. Runtime/test sources match
`reports/native-loading-cache-audit-v2.json`; game assets and credentials are
excluded. The six-stage goal remains active for further pop-in/publication work.

### Worker skin streams (verified, 19:23 UTC)

Existing read-only original dossiers pin `MdlNodeSkin::InternalPostProcess`
0x1400a99e0..0x1400a9ad0, its `ProcessVerts` call at 0x1400a9ac1, small private
skin creation 0x1400df1a0..0x1400df1fd and `PartTriMesh` model-pointer retention
at 0x140088028. These support separating reusable model derivatives from private
instances; they do not establish complete native shader/deformation equivalence.
Target binary/hash is unchanged from the evidence at the top of this note.

The next candidate prepares exactly the old native skin-source expansion and
upload loops on source workers: face order 0/2/1, original FLOAT positions,
authored normals or per-face flat normals, UV defaults, four influences, unchanged
negative/zero/nonunit weight policy and unweighted slot64. It preserves raw
mesh/weights/bones/inverse binds. Invalid/nonstandard slot validation remains at
runtime against each actual private mapping, with the same error/failure scope.
The main thread retains skeletons, Skin resources, ArrayMesh upload and posing.
The source cache key now includes `skin-upload-v1`; warm derivatives cannot alias
legacy source flights/files. Existing prepared geometry and raster pixels do not
change. `--skin-preparation=main|worker` is the explicit reference/worker selector.

Actor disposal also retains only pure original/derived skin-source dictionaries
through the existing two-frame data owner. Live skeleton/mesh/bind Resources
remain main-thread owned. New per-rig and cumulative per-batch prepared/main
skin counters expose actual branch use even after intermediate appearances retire.

The 277-check graphical fixture compiles hash-pinned pre-change authored actor
and rig scripts from the verified background-cache checkpoint. It compares
source FLOAT streams, actual ArrayMesh arrays/bounds, private binds and real
posed mesh baking for authored normals/UV/zero/negative/nonunit/invalid slots,
repeated-root sentinel and degenerate faces, plus two binary/two ASCII original
robe models with nine skin parts. Only the single pinned error logger is captured
for deliberately rejected inputs; production logging/control flow is unchanged,
and exact expected rejection as well as equality is required. Pure-data disposal
is checked on each valid runtime binding. Initial v1 misclassified rigid parts
and emitted expected errors to the strict logger; corrected corpus/error capture
and v3 passes are retained. Separate 12-check actual-worker cache tests verify
distinct schemas, unchanged source fields, memory reuse, fresh-owner disk reuse,
corruption repair and edited-source invalidation. Its initial v1 used the wrong
worker return API; the corrected real Thread return path passes.

Same-source complete-area single pairs (reversed order in area4) retain all
441/630 objects with clean native/engine logs, source pins and finish drains:

| Area | Main / worker skin-source peak ms | Main / worker skin-runtime peak ms | Main / worker player-ready ms |
| --- | ---: | ---: | ---: |
| 3 | 3.710 / 0.004 | 4.163 / 0.519 | 3,164.5 / 3,177.9 |
| 4 | 4.446 / 0.004 | 4.555 / 0.428 | 2,971.6 / 3,093.4 |

These are sampled nested child spans, not summed frame CPU or general loading/FPS
improvements. The main goal here is eliminating individual publication work;
player readiness did not improve in these observations. Overall sampled frame
peaks remain about 54–56 ms, dominated elsewhere. Actual old-code versus worker
large-robe source/runtime isolated cost was about 6.66 ms versus 0.23 ms with
byte-exact posed output. Cumulative constructed skins remain 7 and3 respectively.

Pre-default candidate checkpoint `native-loading-skin-stream-candidates-v1.zip`
is verified, SHA256
`b8b1c707aaa3868f4b8e12b4be6b3499caf081c407ac60cdea0ac207be618d43`.
The new complete suite passes 6,123 checks/40 cases. The original-paced whole-route
pair finishes with the same 922 entities and same single missing `dwc_gate_02`
resource, no other world/native/engine errors and full asset/cache/data/scene
retirement drains. The final 18 skins all use main preparation in the reference
and all use worker streams in the candidate, with zero opposite-path fallbacks.
Sampled source/runtime phase peaks are 5.166/4.835 ms main versus 0.008/1.017 ms
worker. Overall sampled frame peaks remain 57.4/57.5 ms: other work still dominates
the worst frame, and no hitch-free or general FPS improvement is claimed.

Default cold isolated areas reach all 441/630 objects with seven/three constructed
prepared skins and zero legacy skin loops. Player readiness is 3,066.4/2,903.7 ms,
terrain 1,412.5/1,054.7 ms and early camera anchoring 24.1/27.6 ms. Local original
Prelude loading passes with 19 entities and clean native shutdown; this remains
load-only authority coverage, not new combat/door-transition acceptance. The
current source/receipt audit passes 2,759 focused checks plus 3,364 ABI checks,
requires graphical pose baking, actual runtime branch use and all existing
source/coverage/error scope gates. The prior 18:38 cache audit is historical for
these later sources. No public-server connection has been made.

Next investigate main-thread rig/clip metadata and remaining indivisible model
publication. Precomputed clip indices should avoid aliasing whole clips into a
second persisted dictionary, which would duplicate Variant serialization. Also
inspect authoritative own-control identity propagation versus later player-state
arrival before revisiting the rejected pre-control preparation experiment; do
not infer control authority from character name or proximity. Its result may
differ after removing the independently measured cache bottleneck, but any new
candidate still needs opposite-order recorded comparisons and no-authority tests.

Verified authored checkpoint: `backups/native-loading-worker-skin-v1.zip`,
1,416 files, SHA256
`d7c1587e7a2c87458d0bc6fae2ba9f88b442d749c642e7017abd279d15a5ef4a`.
It predates only this self-hash note. Runtime/test source fingerprints match
`reports/native-loading-skin-audit-v2.json`; original assets and private runtime
settings are excluded. The goal remains active for the remaining entry delay,
pop-in and other indivisible publication hitches.

## Authoritative control and shared animation metadata, 20:02 UTC

Read [NATIVE-CONTROL-IDENTITY.md](NATIVE-CONTROL-IDENTITY.md) and
[NATIVE-LOADING-ANIMATION-INDEX.md](NATIVE-LOADING-ANIMATION-INDEX.md) for exact
original call sites, validation, counterbalanced observations and limitations.
The private native5/2 message sets local controlled identity immediately, before
proxy lookup; party14/14 only updates the roster. The protocol port now preserves
that distinction, with61 focused wire/state/session regressions and a local load.
There is no name/proximity-based authority inference. The sealed adapted recording
cannot prove the original5/2 arrival time or an initial-entry benefit.

The native shared-model animation lookup suggested avoiding per-instance full
metadata rebuilding. Worker-built clip indices/controller definitions now support
private on-demand Animation resources/events/clocks. Cache schema v10 is isolated
from the old derivative. Exact current port clip case/duplicate semantics remain;
original FindAnimation case-insensitive first-match/default fallback is still a
separate parity gap. The unchanged authored pre-change runtime is the new81-check
actual-worker/AnimationPlayer/pose/cache reference, not a duplicated new algorithm.
The new default passes6204 native loading/ABI checks across41 cases, current
441/630-entity offline areas and a19-entity authoritative local Prelude load.

Animation installation phase peaks fall roughly5.2–5.7→3.4–3.6 ms in isolated
pairs, and10.618→6.361 ms over the original-paced five-area route. Cold player
readiness remains variable: current defaults3072.105/2966.822 ms, entry cameras
23.005/27.493 ms. Neither overall hitch nor original-binary timing parity is
accepted. The route candidate has an unexplained115.046 ms wall frame,108.686 ms
outside the instrumented callback envelope. It is retained, not dismissed as noise
or attributed to a cause that has not been established. Both routes deliver all
events, end with922 entities and the same missing dwc_gate_02, then drain all
workers/retirement/cache with clean engine logs. Partial source coverage stays
explicit; no public/server repair is attempted.

Next measured targets are indivisible scenery-template construction (16–17 ms in
post-player frames), early unattributed startup work, and cold appearance2DA parse/
coalesced waits (around600 ms). A compiled table parser or split native template
builder must preserve all source fields, physical cell/row semantics, precedence,
geometry/material/collision metadata, private owners and failure scope. Do not
replace that work with FPS claims from small child timing wins. The goal stays
active; no public connection was made.

Verified authored checkpoint `backups/native-loading-worker-clips-v1.zip`,1420
files, SHA256
`740ba6c35f99b33cc1f181b19b0e432b0200380396f79e3764eae10a8685eb9e`.
It predates only this self-hash note. Current runtime/test source hashes match
`reports/native-loading-clips-audit-v2.json`. Original resource bytes/private
settings remain outside authored checkpoints. The earlier control-only checkpoint
`native-loading-control-identity-v1.zip` is also the pinned pre-index authored
reference used by the new fixture.
