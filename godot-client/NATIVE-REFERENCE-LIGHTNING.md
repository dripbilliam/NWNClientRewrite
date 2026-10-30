# Native references and lightning

The direct Godot route now prepares referenced models on native workers, owns
each child independently, and feeds the first direct physical reference into
the native lightning simulation. No JS model, reference, particle or Three
preparation is involved. This is a partial migration, not multiplayer or
performance acceptance.

Read-only original target: NWN:EE89.8193.37-17 x64 `nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
The binary dispatcher at 14007abe0 copies the reference's 64 name bytes and
signed reattachable DWORD. CreateReferenceObjects14008db90 and deleting
destructor14008acf0 establish private child ownership. SetEmitterTarget1400643c0
selects the first direct reference. LightningEmitter::Update140065290 and
RecursiveFractal140062460 establish the chain schedule, reuse and random draws.
Gob::ReattachReference140093b50 establishes physical BFS eligibility/order.
See the existing read-only observations in `evidence/model-references.md`,
`evidence/model-reference-ownership.md` and `evidence/lightning-particles.md`.
These stored cases capture lower providers; they do not prove their entire
implementations or complete Gob construction/event ordering.

`reference_assets.gd` deduplicates resource requests, uses four native workers
with a bounded pending queue, and checks weak requester/generation/retiring
ancestors before publishing. Each instance owns its mutable animation and
reference state; immutable geometry can be shared. References follow position
and quaternion without inheriting anchor scale. Explicit resolved Part anchors
feed the BFS reattachment adapter; missing names are not resolved by proximity.
Nested/cyclic/missing/deferred-retired models have explicit diagnostics. Cleanup
drains workers. The 64-model cache is count bounded, not a byte budget. The
publication time budget is checked between complete models, not a hard bound
on one model's publication.

## Verification

- `native-particle-lightning-v2.json`: 5,494 checks against 2,697 stored original
  lightning cases and 97 target/initialization cases, including f32 values,
  list/pointer aliasing, capacities, CRT draws and quaternions.
- `native-reference-reattach-v1.json`: 784 checks, including 783 stored original
  physical BFS cases. Target Part resolution remains an explicit provider.
- `native-reference-gpu-v2.json` and `.debugger.json`: 147 checks, actual original
  cold-ray child models, original 3/33-point chains and 204 linked vertices,
  authored direct-reference ordering, private clones, nested children, target
  loss, reattachment, cycle/missing diagnostics and retirement. Normal-heap CDB
  armed four exception traps, sources stayed unchanged, clean exit; screenshot
  inspected. This is a fixture, not live casting or original pixel parity.
- `native-particle-runtime-reference-v2.json`: 29 existing torch/portal/actor
  clock/clone/cleanup checks remain passing with clean log.
- `native-actor-reference-regression-v1.json`: 266,819 animation/skin/data checks.
- `native-static-clip-v1.json`: eight checks. A negative binary clip duration
  is retained as explicitly unavailable playback; geometry and other clips
  remain usable. Negative-duration playback semantics are not implemented.
- `native-session-references-v1.json`: actual normal direct entry, owned-local
  server, 20 entities/nine tiles, authoritative movement, finish acknowledgement,
  zero remaining workers and zero public connections. No JS render modules
  loaded; no native exception, source mutation or engine/lifetime error. This
  small room has no referenced-model jobs; the separate fixture covers them.

Older particle and direct-entry source pins are historical. This follow-up does
not resolve all historical native shutdown faults.

## Dense-room failure and performance evidence

`native-capture-references-v3.json` is explicitly **unsuccessful**: 48 tiles,
889 static objects and eight creatures prepare, but one ground item is missing
the original texture `ait_mscmedp_008`. It is absent from the recorded resources
and installed KEY/BIF lookup checked so far; other caches/texture mappings still
need investigation. No guessed texture replaces it. Many unsupported/missing
emitters also remain diagnosed. The test uses one captured snapshot with live
idle animation, not a complete moving protocol timeline.

Preparation took 22.225 seconds. Settled frame intervals averaged 74.27 ms,
p95 82.25 ms. In the rolling CPU profile, particle simulation averaged 22.73 ms,
vertex generation 28.03 ms, channels/pose 4.80 ms and upload 2.64 ms. The parent
particle span averaged 58.75 ms; child spans must not be added to the parent.
Measured viewport GPU time averaged 0.88 ms. This identifies GDScript CPU
particle work as the next compiled-native target. Concurrent/editor work,
incomplete visuals and a failed resource make these diagnostic results, not
clean benchmark or 60 FPS acceptance.

Still open: compiled particle kernels, complete effects/weather/wind/collision/
P2P/chunks, original global event/RNG/opacity bindings, canonical picking for
referenced meshes, automatic combat/projectile reattachment, UI/resource parity,
complete capture timeline, transitions/reconnects and sustained frame pacing.

Follow-up: the [compiled vertex kernel](native/README.md) now has opt-in original
word/GPU/normal-entry checks and reduces the room's vertex cost substantially.
Simulation and complete performance/visual acceptance remain open. The current
kernel reports pin later sources; reference reports above remain historical
where their source hashes differ.
