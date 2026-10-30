# Compiled particle simulation and default entry

Current ownership update: ordinary sprite emitters now retain private C++
state/controllers and publish Godot-ready streams, with native pose/admission
checks. The Godot-backed arithmetic described below remains the reference and
fallback for other owners. See [current hot-path implementation, tests and
measured limits](NATIVE-HOTPATH-OWNERS.md). Historical statements below about
all state remaining in Godot Dictionaries describe the earlier stage.

Windows native entry now uses compiled particle lifetime/frame/schedule,
initialization, standard movement and vertex arithmetic. The Godot scene owner
retains channels, source/camera transforms, provider resolution and GPU upload.
No JavaScript particle, model, geometry, texture or renderer output is required.
This advances the rendering migration; complete visuals/gameplay/performance
remain unaccepted. Lightning fractal/update is still native GDScript, with its
random-position helper and standard vertex drawing compiled.

`native/particle_simulation.hpp` extends the direct C GDExtension in
`native/particle_kernel.cpp`. All emitter/particle state remains privately owned
Godot Dictionaries/Arrays. The DLL retains no emitter pointers or providers.
Provider callbacks preserve original call ordering, shared visual RNG draws,
list reuse/capacity changes, wind/collision boundaries and mutable collision
output aliasing. Original Z-up/WXYZ transforms and f32 grouping stay intact.
Callbacks can reenter the kernel on the presentation thread; concurrent worker
calls remain unsupported. Errors become explicit diagnostics, not fake models
or guessed force/collision results. Active/birth allocations are bounded.

`tools/ensure-particle-kernel.ps1` checks the pinned executable, build inputs and
DLL hash before normal entry. Stale/absent builds compile before opening the
game, using the locally dumped ABI and `/fp:strict`; an unchanged build is reused.
Generated binaries/API stay outside authored sources, in ignored directories.
Checkpoints now retain `.hpp` alongside authored C++/GD/build sources. The old
runtime remains available with `join-native.ps1 -GdParticles` or
`native-world.ps1 -GdParticles`. Standalone native arguments support
`--particle-kernel=gd`; `NWN_PARTICLE_KERNEL=gd` is an additional diagnostic
override. Unsupported platforms retain GD unless explicitly requesting compiled.

## Original binary evidence

Read-only target: NWN:EE89.8193.37-17 x64 `nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
No original game files or running processes were modified. Addresses/corpus
providers are established in `evidence/particle-emitter-runtime.md` and
`NATIVE-PARTICLE-RUNTIME.md`:

- Lifetime140065f10..1400660bf; outer frame140061210..1400615ec.
- Fountain140064b30..140065281; Explosion1400647c0..140064b29;
  Single140065cd0..140065f05.
- Constructor140060680; initialize140066450..140066685;
  randomPosition140068d80..140068ed2; randomDirection140068800..140068d73;
  inheritVelocity140066140..1400663c4; chkRandom1400660c0..14006613a.
- Standard movement140068010..1400687f9; draw140062900..14006416c.

Stored original executions capture lower providers, not their complete scene
services. No new original-client execution or public server connection was
needed for this increment.

## Verification

Final default-backend reports, each with a `.debugger.json` source/DLL manifest:

- `native-kernel-default-schedule-v1`: 1,907 checks, original lifetime, frame,
  Fountain, Explosion and Single cases; callback order and capacity/list state.
- `native-kernel-default-physics-v1`: 1,262 checks, 876 initialization and 384
  movement cases; exact f32 and RNG draws, inherited transforms, collision output
  aliasing, ignored hits, reflection, stop/orientation and chunk offsets.
- `native-kernel-default-lightning-v1`: 5,494 checks; original native-GD lightning
  and targeting with the compiled random-position helper, including DWORD sizes.
- `native-kernel-default-vertices-v1`: 492 checks, 245 original streams checked as
  exact uint32 words, provider calls and atlas mutations across all seven modes.
- `native-kernel-default-moving-v1`: 18,084 checks over 2,160 deterministic
  authored moving-emitter frames. Compare full state, all allocated particle
  records, provider traces, RNG state/draw count and exact vertex bytes against
  the separately original-checked GD owners. Includes temporal/spatial Fountain,
  Explosion/Single, moving/rotating sources, inheritance, blur, wind, collisions,
  chunk providers, retirement/reuse, negative/zero/clamped delta and atlas updates.
- `native-kernel-default-particles-gpu-v1`: 30 checks, real original torch equip
  flame/smoke and portal plus authored clones, private surfaces and retirement.
  Recorded emitter backends are compiled without a compiled user-argument flag.
- `native-kernel-default-reference-gpu-v1`: 147 checks, original cold ray, private
  authored moving reference chains, nesting/reattachment/loss/retirement.
- `native-kernel-gd-rollback-physics-v1`: 1,262 original physics checks through the
  explicit GD backend. `native-kernel-gd-rollback-particles-v1`: 29 headless
  model/surface/clock/retirement checks through GD, not a GPU image assertion.
- `native-session-kernel-default-v1`: real normal launcher on owned-local Prelude,
  compiled requested, 20 entities/nine tiles, authoritative 1.5-metre movement,
  finish acknowledgement and zero remaining workers. No native exception,
  engine/lifetime error or source mutation; 129 retained protocol/service JS
  modules, no forbidden rendering modules, zero public connections. This small
  room does not establish dense-world FPS or complete effects.

Normal-heap CDB arms four native exception traps for every scoped check. Clean
results here do not resolve all historical native shutdown faults. Earlier
opt-in reports and verifiers remain historical wherever source hashes differ.

## Captured-room profile and remaining work

`native-capture-kernel-simulation-v1` is an **unsuccessful** room check: the known
ground-item texture `ait_mscmedp_008` remains absent. It assembles 48 tiles,
889 static objects, eight creatures and zero of one ground items; cleanup has
zero workers. CDB traps remain armed, with no native exception or source change.
The project editor is preserved. This is one captured snapshot with real idle
animation, not a moving protocol replay or clean FPS acceptance.

Settled frame intervals average 27.34 ms, p95 30.85 ms, worst 33.56 ms over 179
samples: roughly 36.6 FPS. The earlier vertex-only run averaged 43.63 ms; the GD
baseline averaged 74.27 ms. Recorded particle simulation falls from 22.70 ms
(vertex-only) to 9.24 ms, with vertex generation 2.35 ms, channels/pose 5.15 ms
and upload 2.71 ms. These nested CPU spans are not additive with their parent.
GPU mean is 0.90 ms. Preparation took 16.43 seconds; uncontrolled cache/scheduling
state prevents claiming a cold-load speedup. Full 60 FPS acceptance remains open.

The captured room still diagnoses 1,182 emitter failures: 689 missing cloud
bitmaps, 472 unavailable point-wind owners, 11 scene intersections and ten scene
wind owners. Compiled provider semantics do not implement these scene services.
Missing textures must be resolved from original resource precedence or proven
original behavior; no guessed substitutes are accepted. Native global event/
random ordering, opacity/fade, P2P/chunks, complete effects/weather, combat/
projectiles, UI parity, referenced picking, transitions/reconnects and sustained
moving-world frame pacing remain incomplete. No full migration acceptance.

`native-capture-kernel-default-v1` checks the final default launcher rather than
the prior opt-in selection. It retains the same missing item and diagnosed
emitters, 48 tiles/889 static/eight creatures and zero remaining workers. Sources
and DLL remain unchanged, CDB is armed with no native exception. Settled intervals
average 26.21 ms, p95 30.90 ms, worst 34.74 ms over 179 samples, with zero >50 ms
intervals. Simulation mean is 8.82 ms, vertices 2.23 ms, channels/pose 4.91 ms and
upload 2.62 ms. Preparation is 15.049 seconds. Screenshot inspected. The failed
resource means the room report and aggregate verification remain explicitly
unsuccessful; these diagnostic timings cannot establish clean/full-world 60 FPS.

The offline `tools/check-native-particle-simulation.mjs` audits current source/
DLL pins, original/authoring checks, default GPU/local entry, GD rollback and the
known failed-room result. Its success is an evidence consistency check, not full
visual or performance acceptance. Verified authored-source WIP checkpoint:
`backups/native-particle-simulation-default-wip-v1.zip`; preserve the previous
accepted rollback and prior vertex/reference WIP checkpoints.
