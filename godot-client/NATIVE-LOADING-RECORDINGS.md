# Native area-load recordings

2026-10-27. Native Godot recording/replay for cold application-cache loading
investigations. JS records/forwards protocol envelopes; Godot performs resource
selection, decoding, scene construction, animation and rendering. No JS scene
export or prepared geometry is used.

## Record a manually chosen server/area

Close the previous replacement client, then run from the workspace:

```powershell
.\godot-client\record-native-loading.ps1
```

The normal native server selector opens with profiling and a visible yellow
**RECORDING AREA LOADS** banner. Secondary-monitor/nonactivating launch preferences
are preserved. Choose/connect Arelith manually, enter the intended area, let the
load complete and optionally walk enough to capture streaming arrivals/removals.
Quit through **Main Menu → Exit** to drain resource workers and seal the recording.
Forced termination produces an incomplete recording; do not treat it as usable.

The launcher log prints `NATIVE LOADING RECORDING: <directory>`. Ordinary recordings
persist in the application's private settings directory under
`native-loading-recordings/capture-*`, outside the source workspace. Original
model/texture/TLK bytes are stored only there. The normal session report records
the directory and sealing result. Local fixtures use private OS-temp directories.
Only the run's separate disposable prepared cache is removed after verified child
exit; recordings and the normal user cache are preserved.

Application RAM/model/GPU-resource caches start in a new process; disk model and
UI preparation use a new private cache. Windows file caches, Godot shader caches
and GPU-driver caches are not flushed. Thus this is cold application loading,
not a claim of physically cold disk/driver performance. Downloaded NWSync/HAK
files remain available; this is not a fresh content-download benchmark.

## Replay offline

```powershell
.\godot-client\replay-native-loading.ps1 -Capture '<directory>' -Generation 2
```

`-Generation` can select any recorded full area entry and start it with a fresh
process and cache, without first loading previous areas. Omit it to replay all
recorded worlds. Persistent server NUI/token/TLK state and the resource setup are
seeded when selecting an area; old chat/game worlds are not replayed as seeds.

The default advances as soon as recorded native acknowledgments permit, exposing
preparation throughput without retaining the old machine's idle waits. `-Paced`
preserves recorded timing. These modes are different workloads: compare the same
mode, resolution, particles and selected generation when evaluating changes.
`-Interactive` leaves the completed replay available for inspection; gameplay
inputs are disabled/rejected. `-Headless` is useful for functional checks, not FPS.
`-VerifyOnly` validates manifests/timeline without starting Godot. New FPS/GPU
benchmarks still require a clear machine and user authorization where applicable.

The replay process imports no game networking/session/resolver modules. Its only
socket is authenticated IPv4 loopback to its owned Godot process. It cannot send
actions, chat, area acknowledgments or other packets to Arelith. Native requests
are consumed as recorded readiness barriers or counted as rejected actions.

## What is retained

* Ordered native presentation frames: full/delta raw world envelopes, movement,
  combat/visual/voice/script-sound events and server UI messages.
* Monotonic capture timestamps, native catalog/area/world acknowledgments,
  sampled camera/viewport/particle settings and baseline frame profiles.
* Complete winning resource presence/storage classes, so unread alternatives
  do not disappear from model/format selection during offline playback.
* Exact original bytes returned by native catalog reads, plus base/custom talk
  files. Hashing and file writes run on a dedicated native data thread; readers
  enqueue immutable COW byte arrays through a bounded queue.
* Capture source hashes and cache policy, sealed manifest/timeline checksums,
  native resource checksums and explicit incomplete/error states.

Login/hello packets, CD keys, credentials, outgoing gameplay commands and raw
encrypted network packets are outside the recorder boundary. Server NUI window
tokens remain ordinary presentation IDs. No recorded private resources are
included in source checkpoints.

Frozen replay validates/reads captured payloads rather than mounting the original
BIF/HAK/Workshop/NWSync storage. It reproduces native model/data preparation,
publication and replicated-state presentation, but not original archive/index
mount latency, content download, server computation, ping or the user's physical
input sequence. SHA validation also has overhead. Camera/settings are sampled,
not a frame-perfect video/input recording. A performance gap that disappears in
frozen replay can therefore implicate an omitted boundary; it is not proof that
the online problem is fixed.

## Format, ownership and failures

`recording.json` seals `timeline.jsonl` and `catalog-N/manifest.json` digests.
Each native catalog manifest v2 records availability, requested resource results,
TLK identities and content-addressed `objects/<sha256>` original byte payloads.
Missing recorded payloads fail explicitly; playback has no installed/network
fallback. Recorded original read failures remain failures. Resource lookup and
texture format/storage precedence match the original mounted catalog.

The protocol writer bounds queue/timeline size; native resource recording bounds
queued bytes and disk growth. An overflow, missing resource seal, changed checksum
or interrupted close is not promoted to a successful complete capture. The world
and its workers close before the native resource writer seals. Scene nodes and
GPU resources never enter the capture writer thread.

## Verification

* `native-loading-recording-v1`:17 headless native checks under normal-heap CDB,
  four traps, unchanged source hashes and no engine/lifetime error. Real native
  data worker and catalog forks, native writer, exact frozen bytes/TLK, presence
  versus capture gaps, format precedence, changed sources, corruption and overflow.
* `tools/native-loading-recording.test.mjs`:3 passing Node tests for presentation
  and acknowledgment ordering, excluded credentials/actions, NUI token retention,
  sealed verification, corruption/incomplete capture, and single-area selection.
* `native-loading-capture-local-v4`: normal native host with a separate existing
  local-test key, headless, owned unchanged original Prelude server only. Nine
  tiles/19 world entities,235 captured resources, clean native finish and sealed
  recording. Tests no gameplay movement/UI actions or FPS. Public connections0.
* `native-loading-replay-local-v1` and `native-loading-replay-selected-v1`: full and
  selected-generation native replay through the actual native_session_world root,
  fresh private caches, normal-heap CDB/four traps, actual terminal0, unchanged
  sources, complete world, drained workers and no engine/lifetime error. Game
  server connections0. The final receipt adds owned prepared-cache cleanup.

Earlier capture fixture v1 waited on a nonexistent UI-ready test field and timed
out despite producing a sealed recording. V2 omitted interactive mode from this
load-only fixture, so the existing movement-required success predicate rejected
its stationary loaded world. Both failed receipts are retained. V3/v4 correct the
fixture and pass; this does not waive normal gameplay/strafe acceptance gaps.

The manually captured five-area Arelith recording `capture-pUQlR4` is now sealed
in private AppData storage. Its timeline SHA256 is
`d955e6fef37015dc189ab480a76bb03b0cc2f44482bdee5a55b45561a23715ee`:
4,019 events and 2,927 frozen resource payloads, about 212 seconds. No new automated
public connection was made during loading optimization.

A valid seal proves recorded payload integrity, **not dependency completeness**.
This original slow session did not request every seen model variant before it
left each area. Missing examples include `dwc_gate_02`, `mbanner_pwc_24b`,
`plc_a01d` and a later remote creature's `pmh0_*` body pieces. These stay explicit
replay failures. The replay does not repair the corpus from guessed installed
assets. Isolated generation 3 does complete with all 441 observed objects and is
used for successful cold-loading comparisons.

`tools/replay-native-loading.mjs --generation=3 --paced` selects that area with
its preceding catalog/persistent UI state in a fresh process. `--source-project`
can select a separately verified authored baseline. `--duration-ms` is a bounded
observation, not a successful-full-replay override. `--no-preview` disables the
automatic ready screenshot during frame measurements (also the default now).
Use `--preview` to opt into an automatic ready screenshot; screenshots at shutdown
remain outside active presentation. `diagnostic_preview` in native reports records
opt-in readback and PNG wall time explicitly. Normal gameplay also defaults to no
automatic ready screenshot; explicit profile-control `capture` remains available.

Current replay comparisons also accept `--ancestor-preparation=true|false` and
`--entry-prefetch=true|false`. Their actual policies appear in native world
diagnostics; requesting a flag alone is not proof the selected source implements
it. Ancestor helpers are native data-only threads with a global maximum of two;
this changes preparation scheduling, never recorded protocol data or the resource
resolver. Independent failed remote visuals remain explicit failed-object
bindings and keep full-world acceptance false, while an already admitted player
can keep control. Required player/table errors remain blocking.

`--raster-conversion=gd|compiled` compares exact-pixel CPU conversion paths;
`world.raster_conversion` reports actual availability/mode. Compressed DDS/KTX
block retention is unchanged. `--ancestor-share=1|2` selects per-root helper
fairness inside the unchanged global two-helper limit (default one/root).
Original-paced replay preserves recorded player-data arrival gaps; isolate
generation/acknowledgement pacing only when that is the intended experiment.

`--mesh-preparation=worker|main` selects data-only upload/collision preprocessing
(default worker); the actual mode and prepared/fallback counts are in
`world.pool`. `--icon-model-reuse=true|false` selects bounded reuse of private
GUI bake actors (default true); actual cache/reuse/bound counts are in
`gameplay_ui.desktop.art`. These preserve original geometry/pixels; they do not
change recorded data arrival times. `postdraw_` profile spans are prior
after-collector work included in the next wall interval, and may overlap/wait;
do not sum them into main callback CPU totals.

`--retirement-physics=inherit|scan` compares inherited native-body removal with
the prior recursive collision-mask scan. Default inherit uses disabled-area
notifications; `world.retirement_physics_scan` is false. Actual engine ray
fixtures verify immediate old-area physics exclusion while scene/workers remain
retained. Fine profile spans distinguish disable/audio/scan/cancel and incoming
world versus UI replacement; parent/child spans overlap.

See `NATIVE-LOADING-OPTIMIZATION-GOAL.md` for the measured original-method research,
source checkpoints and current acceptance limits. Broader gameplay/performance
goals remain incomplete.

`--ascii-key-write=typed|arrays` selects direct typed ASCII transform/emitter
key writes (default typed) or the exact earlier boxed-Array reference path.
`world.ascii_key_write` reports the actual mode. Both preserve double precision,
axis-angle values, interpolation, validation and error precedence; this flag does
not change binary model parsing. The focused fixture compares complete parsed
graphs and failures against a hash-pinned authored pre-change parser. Isolated
parser savings do not imply the same whole-area loading improvement.

`--ui-data-retirement=worker|main` compares fenced release of replaced desktop
raw protocol maps with ordinary main-thread reference release. Default worker
uses the persistent session disposal owner; `gameplay_ui.desktop` reports the
actual mode and number of retired maps. It excludes UI controls/resources and
same-map incremental updates. Fine desktop spans split view resets, transient
state reset, raw-object replacement and header replacement. Existing bounded
disposal diagnostics account for the retained data and final shutdown drain.

`--prepared-cache-write=deferred|sync|disabled` compares native background MDL
source persistence with synchronous writes or a diagnostic write opt-out. The
new verified default is deferred; `--prepared-cache-lock=path|global` compares
per-destination repair/publication gates with the earlier global filesystem lock
(default path). Canonical resource reads and rendered models are never
skipped. `world.prepared_cache_writes`, `world.prepared_cache_lock` and
`prepared_write_queue` expose actual policy/lifecycle, including the final joined
writer in the root report. The queue is bounded by 128 packets and a 64 MiB
serialized-size estimate; overflow skips only optional persistence. Rig and
other derivative persistence stays synchronous. See the goal note for current
validation status; experimental flags alone are not performance acceptance.

`--skin-preparation=worker|main` selects immutable typed skin stream preparation
(default worker) or the exact legacy main-thread reference. It isolates the
derived source/disk cache schema with `skin-upload-v1`; old caches cannot alias
new arrays. Actual policy is in `world.skin_preparation`, live branch counts in
`world.actor_rigs`, and cumulative construction counts in `world.batches`.
Skeletons/bind validation, GPU publication and posing remain on main. Original
weights/winding/normals/UVs and source fields are preserved; exact graphical
ArrayMesh/pose-bake checks are required alongside cache/invalidation tests.

`--clip-preparation=worker|main` selects shared immutable worker clip indices and
on-demand private playback metadata (default worker), or the earlier per-instance
full-map preparation. Decoder namespace `actor-rig-emitter-v10-clip-index` isolates
the new derived cache. Old index-free assets use the legacy fallback. Actual policy
is `world.clip_preparation`; indexed models/metadata counts are in `world.actor_rigs`.
The mode does not move AnimationPlayer, AnimationLibrary, GPU resources or scene
owners to workers. See `NATIVE-LOADING-ANIMATION-INDEX.md` for exactness, same-source
comparisons and the retained115 ms full-route outlier. Lower child work is not an
overall world-entry/FPS acceptance claim. The clips audit is historical after
material prewarming; current receipt is `native-loading-material-prewarm-audit-v1.json`.

`--material-prewarm=true|false` selects bounded graphical startup preparation of
20 production material classes (default true; headless skips it). The root
`material_prewarm` report records preparation and final owner release.
`--render-thread=safe|separate` is an explicit engine diagnostic option only;
separate produced engine shutdown errors and is not the production default.
Actual pipeline counters, deltas, thread observations, and bounded top-16 template
phase timings are recorded when profiling is enabled. They do not alone prove
overall FPS improvement. See `NATIVE-MATERIAL-PREWARM.md`.
