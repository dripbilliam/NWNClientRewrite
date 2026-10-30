# Native crowd and brazier test

`./godot-client/stress-native-local.ps1` opens the same authored `DensePerf`
module used by the former JS dense-server tests. It starts the isolated owned
server on `127.0.0.1:5123`, preserving the Prelude server on 5121. An original
game already running can be explicitly preserved with `-PreserveOriginalPid`.
The current-user protected local test key is selected privately when present.

Each area has 100 tile placements, 48 server-controlled wandering humanoids,
48 braziers and 32 other props. The installed wizard adds the 49th creature.
Gender, head, skin and hair selections vary. These are the original authored
fixture's choices, not a broad sample of every custom model. Godot loads the
original installed meshes, textures, palettes and animation data natively.
JS handles protocol only and rejects rendering imports. Public game-server
connections and transfers remain disabled.

The native window shows FPS, entity/tile loading, pending batches and unique
GPU mesh/texture resources. WASD and click movement are server-authoritative;
middle drag orbits and the wheel zooms. Chat `-stress-b` / `-stress-a` requests
the fixture's ordinary server-owned transfers. Those transfers are available
but have not yet been accepted in this new native dense route.

## Current evidence and limitations

`reports/native-dense-play-v1.json` is a retained failed attempt: the native
ASCII parser rejected the original female `pfh0` model's duplicate `Impact`
nodes. The existing JS parser retains all physical nodes and uses its final
declaration for name lookup. The native parser now follows that behavior.
This is JS-reference compatibility, not an independently measured binary
duplicate-name lookup rule. `native-streaming-v4.json` passes 36 checks,
including all 57 physical nodes and both original Impact records.

`native-dense-play-v2.progress.json` recorded 129/129 entities, 100/100 tiles,
zero pending batches/errors and 108 unique meshes / 505 textures. Its native
ready screenshot was inspected. The preview is intentionally left open;
cleanup, final source validation and a terminal acceptance report are pending
until it closes. FPS samples around 70–77 are observations, not a clean or
accepted performance result. The original game and editor remain open.
Particle/effect parity is incomplete, so this scene needs considerably more
frame-time headroom before it can represent complete gameplay performance.

## Loading investigation

Workers now report source read, memory lookup, model/inheritance, rig,
texture and cache-save time separately. Completed actors attach independently
of unfinished siblings; stale results are discarded once. Preparation is
shared across catalog forks in a bounded 256 MiB / 512-entry memory cache,
with private returned graphs and catalog mount generations. Mounted sources
are assumed stable; dependency edits require remounting rather than a live
file watcher. Persistent caches still validate actual palette-source hashes.

The local Prelude `v23` run found body-part texture preparation taking roughly
750–830 ms while model/rig preparation took roughly 1–2 ms each. PLT preparation
decoded the source palette TGAs before checking its finished persistent cache.
That order is corrected: hash dependency bytes, check the finished result,
and decode palette pixels only on a miss. Decoded palettes are also shared
through the bounded native memory tier. Runtime inheritance selection avoids
expanding tracks that cannot bind to a piece while retaining empty clips,
overrides, events and root renames. Five original models produced identical
bound rig data against the full inheritance path in the headless checks.

The observed first complete area samples on the same Prelude route changed
from 5019.52 / 2046.90 ms (`v23`) to 3009.29 / 1218.73 ms (`v24`). These are
500 ms sampled completion observations with a warm persistent disk cache,
not precise cold-disk benchmarks. V24 passed authoritative inventory,
equipment appearance, movement, NPC dialogue and the native server's area
transfer under an armed normal-heap debugger, with no engine error/exception.
Its source hashes precede the later stress-launcher/duplicate-node changes.

`native-light-motion-v8.json` passed 83,863 headless checks before those later
stress changes. The older playability ledger remains pinned to the accepted
inventory milestone; it must not be represented as verification of these
newer sources. A fresh combined headless/local check and ledger refresh remain
due after the user's interactive preview. Full native migration, gameplay,
rendering parity and sustained performance remain incomplete.

## CPU/GPU profiling and bone prototype

After the user authorized restarting it, `native-dense-play-v2` completed
normal shutdown under CDB with unchanged sources and no trapped exception or
engine/lifetime error. Both subsequent `native-dense-profile-v1/v2` runs also
closed normally. Unicode surrogate warnings in the first profiling log remain
unresolved; complete protocol/text parity is not claimed.

`frame_profile.gd` adds rolling CPU spans and asynchronous viewport render
CPU/GPU measurements. `.control.json` commands temporarily alter the workload
for diagnostics and request normal shutdown. `tools/profile-native-dense.ps1`
records those ablations. The baseline measured roughly 15–16 ms/frame with
0.67 ms GPU rendering and 3.2 ms actor animation. Pausing animation yielded
9.4 ms/frame. Lower resolution and unshaded rendering barely affected total
time. Detaching actor picking bodies had no clear gain and was not adopted.
Skipping model entries without animation owners reduced bookkeeping to about
2.8 ms; seven authored event/pose/lifetime checks pass. The second run remained
around 14–15 ms/frame. These sequential wandering workloads are diagnostic,
with the original game/editor preserved, not a clean causal speedup. Engine
TIME_PROCESS readings were inconsistent with rolling wall intervals and must
not be used to attribute their percentages or summed with nested spans.

Fresh read-only Ghidra dossiers use the pinned original SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
`Scene::Animate` (`0x1400c5210`) walks its registered list backwards; this
function does not establish off-screen animation skipping.
`CreateInstanceTreeR` (`0x14008dab0`) creates per-instance Parts from model
nodes, initializes controllers and links physical children/parents.
`ExecuteSkinGPU` (`0x1400deb90`) supplies up to 64 bone matrices and draws
retained primitives. Reports `native-scene-animation-dossier-v1.json` and
`native-profile-14008dab0-v1.json` / `native-profile-1400deb90-v1.json` retain
assembly, call sites, pseudocode and evidence IDs. These support separating
immutable geometry from private pose state and GPU deformation; they do not
prove Godot Skeleton3D is the original representation or will be faster.

The **unpromoted, opt-in** `skeletal_rigs.gd` prototype replaces the per-bone
Node3D tree with native bones and GPU-skins rigid pieces as well as weighted
skins. Original physical indices, meshes, textures, clips and events remain.
The default still uses the established node rig. Bounds, manual pose/external
references, picking, held equipment and whole-world performance need more work.
`native-skeletal-pose-v1.json` passes 403 authored curve/pose/scale/event/loop/
rest/attachment checks with zero position difference. Actual original dwarf
and robe GPU comparison `native-skeletal-actor-v1` passes 108 checks under
normal-heap CDB: all 13 meshes / 3,235 vertices agree at two sampled poses,
maximum world vertex error below 2.4e-7. Screenshot inspected. This is one
character, not broad model parity, native pixels or a dense-scene speedup.

The user then requested Arelith. The existing Godot public browser was opened
for user server/character selection. It still uses staged assets and does not
validate the direct native loader or skeleton prototype on Arelith. Preserve
that session and defer competing GPU tests while it remains active. The
current source checkpoint remains WIP; older ledger pins are historical.

## Public compatibility launcher failure (2026-10-24)

`public-browser-1792899094192.json` reached server-authoritative playing and
received NUI, but exported zero areas and ended with `Local source models failed
to prepare`. The old compatibility host rejected its entire prepared world when
any optional entity had failed. Its bridge snapshot retained only object IDs,
discarding the useful renderer failure reasons. This is distinct from the direct
native-loader performance tests and does not validate that loader on Arelith.

Bridge v41 now exposes bounded per-entity failure reasons. A focused readiness
boundary retains prepared terrain/actors despite unrelated entity failures while
still requiring the current area, completed preparation and controlled actor.
Fourteen readiness/export/content/transfer tests pass; the bridge build preserves
the production JS source. A user-directed browser was reopened for verification.
Actual rendered-world acceptance remains pending, including the failed entities.
The source-preparation observations are now present in the live status report.
This compatibility repair does not remove the remaining JS staging dependency.

That run also recorded two leaked objects and a retained `frame_profile.gd`
resource at normal engine exit. Do not count that shutdown as clean acceptance.
