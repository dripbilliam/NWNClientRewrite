# Native particle ownership, incremental world updates and diagnostics

This increment addresses the five costs identified in the live profile
`reports/native-profile-1792956611877.performance.jsonl`. Rendering, resource
preparation, particle simulation and GPU publication use Godot/GDScript/C++.
The JavaScript host still owns login/network/protocol services and forwards raw
server state. No JS-prepared model, particle stream or render scene is needed.
The networking migration and the 60 FPS goal remain incomplete.

Current collision follow-up: [Heal and impact particle performance](NATIVE-PARTICLE-IMPACT-PERFORMANCE.md)
adds persistent bouncing sprites and native original-face/model-Part scene
queries. Wind-dependent/custom movement, chunks and lightning keep separate
owners. The earlier collision exclusions below describe their checkpoint.

## Implementation

| Cost | Current implementation |
|---|---|
| Per-field Godot Variant crossings in particle/controller work | `native/particle_resident.hpp` registers a private `NwnParticleOwner : RefCounted`. State, active/free records and compiled scalar/vector/byte controllers persist in C++. `particle_records.hpp` provides compact emitter/particle/pose/list slots. Controller destinations bind to stable private field addresses. Base parameters copy once; selected controllers update their own fields. |
| Vertex conversion and repeated staging allocations | The shared arithmetic in `native/particle_vertices.hpp` writes Godot-ready position/RGBA/UV streams through reusable C++ staging buffers in `particle_streams.hpp`. `particle_emitter.gd` publishes these directly to its existing dynamic `ArrayMesh`. Retained capacity is reused and unused vertices are cleared. |
| Repeated spatial checks and transform marshalling | Native owners read validated Node3D IDs through pinned public GDExtension methods. The source/parent transform is read once when they are the same object. Native sphere/frustum checks cover retained particles/trails conservatively. Automatic emitters share one camera packet per render frame after camera controllers; explicit manual ticks revalidate same-frame changes. |
| Full emitter scans and historical diagnostic copies | `systems/native_render/particle_metrics.gd` maintains world-owned counters at publication/cull/failure/retirement boundaries. Entries retain IDs and scalar counters, never nodes or particle records. `live_world.snapshot(false)` omits deep historical arrays for HUD updates. |
| Full world-registry delivery every 200 ms | `tools/raw-world-deltas.cjs` compares opaque original records against the last acknowledged baseline. The private bridge sends only changed/new records, explicit removals and current metadata. Native world, gameplay text and inventory repositories apply those deltas. |

The native records are **our private schema**, not the proprietary original
memory layout. They retain tagged scalar values and private array containers;
this is not a claim that every native field is already a dedicated POD member.
Exclusive small numeric-vector storage is reused. Aliased values retain
replacement semantics, protecting cached controllers and diagnostic snapshots.

The shared arithmetic bodies compile against both the retained Godot-backed
reference and the persistent C++ owner. Native random draws still use the
world's existing visual RNG in the same order. Controller Bezier endpoint and
byte-write behavior remain covered, including lazy malformed-storage failures.

## Lifetime and transport boundaries

- Each emitter releases its RefCounted native owner on retirement. It retains
  scene IDs, not borrowed Node pointers. Every native transform read resolves
  and validates the ID as Node3D. A retained diagnostic owner rejects a freed
  source/parent. No callbacks or scene pointers survive a frame call.
- Returned PackedByteArrays own their data. Reusing C++ staging cannot mutate
  an already queued RenderingServer upload. GPU buffer growth preserves the
  existing material binding. Empty and shrinking frames clear stale quads.
- Custom movement/update providers, wind-dependent emitters, chunks
  and lightning retain their previous owners. Existing explicit unsupported
  effects remain diagnosed. A callback failure cannot republish a failed surface.
- `state` on a resident emitter is an explicit read-only diagnostic **snapshot**.
  Mutating it does not issue a command; use `detonate()` for detonation.
  Normal ticks and incremental diagnostics do not export full particle state.
- Delta transactions commit only after an exact connection/generation/serial
  acknowledgement. Reconnect and area-generation changes require a full base.
  Native reception rejects a delta with a missing/wrong baseline. Source server
  fields, object identity and original protocol bytes are unchanged.

The host still serializes/compares the current registry in Node every polling
interval. This increment removes full native delivery/application, not all
host-side registry work or the remaining JavaScript protocol service.

## Binary evidence and inference

Read-only NWN:EE89.8193.37-17 x64 `nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original files, processes and the existing Ghidra project were not modified.

- **Observed:** `FountainEmitter::Update140064b30` accesses emitter/particle
  fields directly and uses the active list at +188/count +190 and free list at
  +130/count +138. Allocation occurs when a reusable free record is unavailable.
  `chkParticleLife140065f10..1400660bf` recycles retired records and grows list
  capacity from 16 by doubling. The existing unchanged-binary schedule/physics
  corpora validate arithmetic, lifetime and lower-provider ordering.
- **Observed:** `MdlNode::InternalControl140051c50` writes numeric controllers
  at their runtime displacement. Its radius-update call is `14005246d`.
  Our destination binding applies that direct-write principle without copying
  original class layout or retaining original process memory.
- **Observed:** `ManageSceneBSP1400db320` clears/collects emission buckets;
  callback `1400dc140..1400dc8f3` calls the sphere/plane test at `1400dc3e4`.
  `DoEmitterBucket1400c7ae0` calls Animate at `1400c7c94` after collection.
  See [admission evidence](NATIVE-PARTICLE-ADMISSION.md) for exact original cases.
- **Inference/application:** persistent state, direct controller writes and
  admission before simulation remove adapter overhead. Our Godot camera planes
  and conservative active-quad envelope are not a full original BSP port.

## Verification and performance scope

Debugger checks use the pinned Godot 4.7.2 build, normal heap and traps for access
violation, heap corruption, fail-fast and illegal instruction. Reports retain
source/DLL hashes and check source immutability. All tests are local/offline.
See `reports/native-hotpaths-final-*.debugger.json` for the final cohort.

Final cohort: 24,646 checks passed across resident state/controllers, actual
GPU scene ownership, original streams/assets, point wind, incremental metrics,
world deltas and fused reference simulation. The bridge framing/delta suite
adds seven passing Node tests (`native-hotpaths-final-bridge.tap`).

`native-hotpaths-final-local-cycles-v1.json` passes three normal local reconnect
cycles plus an abort while streaming, stale-session fencing and authoritative
movement. It sent four full snapshots and 22 deltas containing 157 object
records total. `native-hotpaths-final-prelude-v1.json` passes three requested
door transfers across four admissions, server-owned movement, examine/dialogue
and unequip/re-equip with an inventory reopen in generation four. Both report
zero public connections, unchanged sources and no native exception.

The persistent-owner comparison covers 1,620 authored moving frames across
Fountain/Explosion/Single, spatial births, inheritance, recycling, random draws
and exact GPU streams. Separate tests exercise native linear/Bezier/byte
controllers, actual moving/scaled GPU sources, camera leave/re-entry, original
torch/portal assets, unchanged original draw streams, counter audits and deltas.
These do not substitute for a complete original-client moving-world comparison.

The saved-room comparison uses the same captured input, original resources,
camera and supported-effect policy. All variants retain 1,351 emitter nodes,
542 simulated emitters, 99 currently culled emitters and 710 previously explicit
failures (596 scene-intersection, 10 ambient-wind, 104 missing `fxpa_cloud02`).
Models/textures are unchanged; the full effects implementation remains open.
Active particle counts vary with asynchronous loading and elapsed visual time.

| Diagnostic run | Settled mean | Approximate FPS | Particle CPU mean |
|---|---:|---:|---:|
| `native-hotpaths-reference-room-v1` | 44.44 ms | 22.5 | 37.64 ms |
| `native-hotpaths-resident-room-v1` | 35.36 ms | 28.3 | 27.80 ms |
| `native-hotpaths-boundpose-room-v1` | 26.52 ms | 37.7 | 19.41 ms |
| `native-hotpaths-record-reuse-room-v1` (600 frames) | 26.36 ms | 37.9 | 17.07 ms |
| `native-hotpaths-final-room-v1` (600 frames, final pinned sources) | 27.38 ms | 36.5 | 18.61 ms |

These are instrumented offline diagnostic samples with the user's editor
preserved, not clean benchmark or live-server acceptance. The final row had no
settled interval above 50 ms, p95 31.18 ms and worst 35.89 ms. Verification
passed with unchanged source/DLL pins and zero remaining workers. It remains below
60 FPS. Full native networking, missing effects, original global translucency
ordering, full moving capture replay and broad gameplay parity remain open.

## Rollback and investigation

Verified authored-source checkpoints:

- `backups/native-hotpaths-before-v1.zip`: before this increment.
- `backups/native-hotpaths-streams-deltas-v1.zip`: initial streams/delta/counter
  stage, before persistent native state.
- `backups/native-hotpaths-resident-native-v1.zip`: completed native code and
  tests (1,078 authored files), SHA256
  `caebbe235ed1fc1f0f6e739fd7dc5bb1b11ba0419d80dcc59b0cee1e3a1b8a9e`.

For a same-scene reference comparison use
`native-world.ps1 -ReferenceParticleOwners -LegacyParticleStreams`.
`--particle-owner=reference` retains the Godot-backed compiled arithmetic path;
`--particle-streams=legacy` also restores the GDScript vertex repack.
`--particle-poses=gd` compares GDScript pose marshalling within a resident owner.
The full GDScript arithmetic fallback remains `-GdParticles`.

Do not connect an automated test to a public server. Use the owned Prelude
server at `127.0.0.1:5121`, or the saved-room `native-world.ps1` fixture.
