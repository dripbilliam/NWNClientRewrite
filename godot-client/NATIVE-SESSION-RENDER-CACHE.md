# Native render resources across area changes

The normal native client now retains bounded immutable GPU resources and static
model templates across world changes. Returning to the two tested Prelude areas
creates no additional pooled meshes, textures, materials or templates. Scene
nodes, transforms, animation/skin owners, effect clocks/lists and target/reference
owners remain private. This is a partial binary-guided loading improvement; the
full ordered migration and performance goal remains active.

Follow-up: [NATIVE-SESSION-CONNECTION-SCOPES.md](NATIVE-SESSION-CONNECTION-SCOPES.md)
adds actual same-process reconnect and pending-worker disconnect coverage with
cache reuse and final cleanup. The report pins below retain this earlier cache
checkpoint's scope; remote handoffs and full performance acceptance remain open.

## Original evidence and limits

Target: unchanged NWN:EE89.8193.37-17 x64, executable SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
No original file/process changes, Ghidra edits or copied proprietary assets.

- Complete `BinarySearchModel140098ba0..140098c2d` reads the global model-array
  pointer at1413018b8 at140098bd9/140098c21 and compares names at140098bed.
  This is a global source collection, rather than a per-area object tree.
- Previously traced `FindModel140098cd0` routes hits around synchronous I/O;
  `NewCAurObject1400931f0` retains source models and constructs private Part
  trees. See [NATIVE-WORLD-MODEL-CACHE.md](NATIVE-WORLD-MODEL-CACHE.md).
- Complete `Model::DelRef14008dd20..14008dd43` decrements count+94 and calls
  `MaxTree::operator_delete14008a070` only at zero. Full
  `Gob::~Gob1400889c0..140088e6a` contains the corresponding source-reference
  release paths while destroying private scene/behavior owners.
- `Model::InternalDestructor140091e50..140091fe9` removes a model from the global
  array, releases its supermodel and invokes lower child/root destruction.
  `MaxTree::operator_delete14008a070..14008a37b` distinguishes borrowed/unloaded/
  owned structures and releases their lower resources. These complete selected
  pseudocode/assembly views are not a claim that all lower destructors or engine
  eviction policies have been reconstructed.

Selected REA dossiers in `../backups/animations`:
`rea-native-global-model-search-v1.json`, `rea-native-model-delref-v1.json`,
`rea-native-gob-model-release-v1.json`, `rea-native-model-internal-release-v1.json`
and `rea-native-maxtree-release-v1.json`.
`../scripts/inspect-native-model-search-release.py` executes the complete original
global search on42 cases and DelRef onseven cases. Comparison and downstream
delete are explicit lower providers. Observations:
`native-model-search-release-v1.json`. Signed invalid/zero starting refcounts
are recorded as boundary observations, not adopted as a safe ownership policy.

Evidence establishes global source lookup, private instance trees and reference
release. It does **not** establish an original512-entry LRU or indefinite source
retention after an area's final reference disappears. Our bounded session cache
is a Godot adaptation using those ownership distinctions. Do not describe its
exact retention/eviction policy as copied from the binary.

## Native ownership and keys

`native_live_world.gd` owns one `resource_pool.gd` for the client lifetime and
passes it to each `live_world.gd.open`. Worlds borrowing this pool do not clear
it during retirement. Standalone/captured worlds still own and clear their own
pool. Final native shutdown closes worlds/joins their workers, records cache
diagnostics and clears every cache binding. Session/menu reset retains the
cache; cross-connection behavior still requires its own live test.

The pool bounds cache bindings to512 templates,4096 meshes,512 textures and2048
materials. Recent use updates ordering; eviction drops only the cache reference.
Admitted instances/templates can keep referenced resources alive. Consequently
these counts are **not a hard byte/VRAM limit**, and diagnostics distinguish
cumulative creations/hits from retained cache bindings. Immutable model/texture
content identity and material/publication settings remain in keys. Original PLT
palette/color dependencies already contribute to texture identity.

Picking participates in both template and geometry identity now. Warming a model
without hit-shape publication cannot cause a later pickable instance to reuse
geometry lacking that shape. Mesh eviction also removes the corresponding
cached picking-shape binding; live mesh metadata keeps its own reference.

No JS resource preparation or renderer output is introduced. Temporary protocol
JS remains; this is not completion of the full native migration.

## Current verification

- `native-session-render-cache-v3`:18 authored native/GPU checks. Actual private
  emitter state and rest transforms stay separate across two world owners;
  retiring one does not retire the other; cached geometry/templates survive;
  texture/material/mesh/template eviction preserves live resources; picking
  keys, private-world cleanup and final cache-binding release pass.
- `native-shared-cache-templates-v1`:16 existing cross-batch template checks;
  `...publication-v1`:10 real stream-adoption/effect-lifetime checks;
  `...chunks-v1`:119 original-derived chunk/private-model GPU checks;
  `...retirement-v1`:72 real delayed-worker/cancel/overflow checks;
  `...references-v1`:147 original-derived reference/target/private-pose checks.
- `native-shared-cache-three-transitions-v1`:real owned Prelude protocol,
  generations1..4, all92/20/92 entities and100/9/100 tiles per leg. After both
  areas first load, pooled creations stay at1253 meshes,96 textures,119 materials
  and77 templates through both return legs. Template hits rise16→29→109 and mesh
  hits64→114→144. Three old worlds release; cache bindings are zero after final
  shutdown. Walk/WASD, equipment, conversations and final inventory reopening
  pass. Durations2864/852/1194 ms include actions/network/loading and reflect
  existing cache/server state: **not a controlled speedup or cold/warm comparison**.
- `native-session-shared-cache-v1`:actual default native launcher, player ready
  at1420.712 ms with one of19 entities and two batches pending. Actual native and
  server movement occur while background batches remain. Final20 entities/nine
  tiles, zero workers, acknowledged finish and empty final cache bindings.49
  diagnosed effect failures remain; complete effects are not accepted.
- `native-capture-shared-cache-v1`:existing offline raw snapshot,48 tiles/889
  static objects/eight animated creatures/one item, zero workers. Original native
  clocks/skin deltas advance and screenshot inspected. Pooled creation counts
  match the prior checkpoint exactly.1182 effect failures remain. Preparation
  11549 ms;179 settled frame intervals average20.465 ms,p9521.566,worst21.875.
  Loading831 intervals average12.635 ms,p9527.277,worst46.109. Editor1776 preserved;
  uncontrolled wall-clock samples, incomplete effects, final snapshot plus native
  animation rather than full moving-protocol replay. No60 FPS acceptance.

Accepted tests use normal-heap CDB, four armed traps, unchanged source/DLL pins
and no trapped native exception or engine/lifetime error. No new public
connections occurred. Initial authored v1 failed at an inferred WeakRef warning;
fixed with an explicit type. V2 is a historical pin before per-leg cache counters
were added to the transition probe; v3 is current. Source checks caught that
stale proof and required the refresh rather than relabeling it.

`tools/check-native-session-render-cache.mjs` audits all nine report sets and
current inputs, original case counts, real return-visit reuse, bounded/private
ownership regressions, default entry, compatible captured scene and clean logs.
Output: `reports/native-session-render-cache-v1.verified.json`.
Same-process reconnects, exact original cache policy, full effects/culling,
controlled large-area cold/warm tests, full moving replay and dense-world frame
pacing remain open. Native shutdown faults are not globally declared resolved.
