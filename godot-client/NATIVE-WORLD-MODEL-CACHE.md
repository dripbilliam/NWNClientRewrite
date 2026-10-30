# Original cached models and private instance trees

Status: partial binary-guided loading implementation; full ordered goal active.
Follow-up: [NATIVE-SESSION-RENDER-CACHE.md](NATIVE-SESSION-RENDER-CACHE.md) adds
bounded immutable GPU/template retention across area changes, further original
global-search/reference-release evidence and current local/captured regressions.
The per-world lifetime and report pins below describe the earlier checkpoint.
Target: unchanged NWN:EE89.8193.37-17 x64, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Fresh Ghidra12.1.4 immutable REA analysis and isolated original-code execution;
no live original process changes, Ghidra edits or copied game assets.

## Binary observations

- `FindModel140098cd0..140098fd8` calls `BinarySearchModel140098ba0` at
  `140098e8e`. A hit skips dispatcher/parser work. A miss calls
  `IODispatcher::ReadSync140079f70` at `140098ecf`, restores `currentmodel`,
  and diagnoses differing model names while retaining a valid parsed model.
  Null/NULL names and failed parse/cast remain null results.
- `NewCAurObject1400931f0..140093847` calls FindModel, retains model references
  using count+94, then creates a private Part tree with
  `CreateInstanceTreeR14008dab0`. Parsed original model sources are shared;
  runtime instance transforms/behavior and referenced objects are separate.
  Its optional three-model LOD path and exact eviction policies remain open.
- `CAuroraModel::LoadModel1400f4a70..1400f4ac4` demands resource bytes before
  exposing MDL data. `CExoResMan::Demand14018ef90..14018f2fe` has explicit
  loaded-resource reuse, demand counts and storage-class service calls.
  Its lower list/eviction/storage behavior has not yet been ported in full.
- `IODispatcher::PreSpawnAsync1400799f0..140079a7a` allocates/registers a
  descriptor; this function alone does not prove a running worker or a model
  scheduling algorithm. `RetreiveAsync14007c750..14007c827` resolves a registered
  descriptor and binary data; deeper servicing remains to be traced.
- `CExoResMan::Update1401957f0..140195a90` checks eligible storage modifications
  roughly once per second and rebuilds changed key tables. It is not evidence
  that this Update function is the missing model-work queue.

New dossiers in `backups/animations`: `rea-native-stream-find-model-v1.json`,
`rea-native-stream-new-object-v1.json`, `rea-native-stream-demand-v1.json`,
`rea-native-stream-resman-update-v1.json`, `rea-native-stream-pre-spawn-v1.json`,
`rea-native-stream-retrieve-async-v1.json`. Name-search misses do not establish
absence of unnamed functions. `scripts/inspect-native-world-model-cache.py`
executes the entire original FindModel on80 cases. Search, I/O, cast, ASCII
comparison and logging are explicit lower providers. It proves the cache-hit,
load/failure and temporary-currentmodel branches, not the lower parser/eviction.
Observations: `native-world-model-cache-v1.json`.

## Implemented native cache

Godot's existing resource pool shared meshes, rasters and materials, but each
new static-stream batch rebuilt its PackedScene templates. The pool now retains
up to512 prepared templates, using the existing full source/texture/animation
and publication-settings identity. Hits move to the recent end; eviction drops
only the cache reference. Every placement still instantiates private physical
nodes and reference/particle owners. Static and terrain stream owners use the
same native pool. `clear()` retires template references with the world.

This borrows the evidenced separation of cached model source from private
instances. The512 bound/LRU policy is our implementation choice, not a claimed
original cache size or exact eviction algorithm. Pool lifetime is still one
world: sharing render templates across area transitions/reconnects is not yet
implemented. Existing native data/disk cache tiers remain separate.

## Validation

- `native-template-cache-v1`:16 native checks; four separately retired real
  object-stream owners build one template with three hits for48 objects.
  Tests independent transforms, shared immutable geometry, changed-source and
  material-setting keys, bounded eviction, live-instance survival and cleanup.
  Authored static source; this test makes no original pixel/FPS claim.
- `native-template-cache-reference-gpu-v1`:147 reference graph/private model,
  moving chain, target-loss and cleanup comparisons remain green.
- `native-capture-template-cache-v1`:48 tiles,889 static objects,eight animated
  creatures and one ground item prepare without model errors; workers0.
  Screenshot inspected; actual clips/skin deltas advance.1351 emitters retain
  1182 diagnosed failures. This is the final raw snapshot with native animation,
  not complete moving-protocol replay. It builds336 templates with zero hits
  because its terrain/static owners each run once, so this report validates
  compatibility, not the cache's cross-batch speedup.
- `native-session-template-cache-v1`:actual default launcher on owned localhost
  Prelude. Player ready1445.485 ms, native/server movement while background work
  remains, then all20 entities/nine tiles, finish acknowledgment and workers0.
  This small local room has13 unique template builds and zero hits, not a dense
  streaming benchmark.

These checks use normal-heap CDB, four armed exception traps, unchanged sources
and no trapped native or engine/lifetime error. No public connections occur.
Captured preparation is11544 ms; settled process-frame mean20.398 ms,p9521.482,
worst22.750 across179 samples. Loading mean13.080 ms,p9526.612,worst48.313,
zero>50 ms across801 samples. Editor1776 remains open; cache/scheduling conditions
are uncontrolled and there is no paired experiment. These numbers establish
neither a causal speedup nor clean complete-scene60 FPS acceptance.

Continue tracing actual client model-demand priority and cancellation, native
object update/admission, incremental construction, culling, cache lifetime,
repeated transitions/reconnects and full native presentation. The historical
native shutdown fault and incomplete effects remain open. Full JS migration and
the final Markdown wiki follow the first phase in BINARY-WORLD-STREAMING-GOAL.md.
