# NWN-64 geometry worker: bounded headless acceptance

The opt-in worker remains **unpromoted**. This review ran headless only; it does not establish visual parity or FPS improvement.

## Pinned original-resource witness

`reports/native-effect-membership-local-index-v3.native-emitter-inventory.json` (SHA-256 `3a9d6b5239d1b327dbb8d5e0d5505c82daa84f260835af270617ebb7164decea`) records 70 runtime emitter instances from original `plc_i05`. The separate sealed recorded-model parse identifies `plc_i05` MDL SHA-256 `8df82cfe35b42605fcec476b0cb446f7981809c12ba933ec5518f6637aa40b49`, with 18 nodes and eight clips (`reports/native-recorded-emitter-resources-v2.json`, 649 checks, no failures). The witness selects four distinct original authored profiles: Explosion flags 82 (chunk/collision), Fountain flags 70 (wind), Explosion flags 74 (lit), and Fountain flags 98 (additive). All four use Normal draw mode; the inventory does not cover the other six modes or Lightning/Single.

`tools/nwn64/prepare-geometry-worker-original-witness.cjs` creates an immutable private fixture by projecting those original authored fields into eight paired native typed owners. It retains synthetic movement, collision floor, native wind manager, actor clock callback, and chunk service callbacks. Its source/binary/inventory hashes are in `.cache/nwn64/geometry-worker-original-d/witness-receipt.json`. The private worker DLL SHA-256 is `9ccdd3128a7fc71d4b310577f0eed7fa9df3fc41c2b63f25d020a81b4f713f28`; the accepted DLL is different. The private DLL was built against `particle_presentation.hpp` SHA-256 `e4c32d629a0792cfca4e384f827be122c2a2930a5f21a208e90020fa2bc345d5`; the current source header differs, so this is a candidate-build gate, not proof of current accepted DLL behavior.

Run command (PowerShell, from project root):

```powershell
$fixture=(Resolve-Path .cache/nwn64/geometry-worker-original-d).Path
$out=Join-Path $fixture 'witness-report.json'
& .tools/native-core/Godot_native_core_e_win64.exe --headless --path $fixture --script res://tests/geometry_worker_original_witness_test.gd -- --report=$out
```

Result: exit 0; **7,323/7,323 checks, 180 frames, 150 worker frames, 36,912 worker vertices**, no GPU execution. Report SHA-256 `82c6fa81e6130f499f11ccab241139451ff8bae98eabadbc3239de8e195aafd9`. Per frame, the original-field candidate's exact range bytes, native owner state, RNG state/draw count, callback ordering, and immutable published packet match the separate serial owner. Dynamic births, native wind, collision and chunk callbacks, moving source, actor clock detachment, enable/disable and detonation were exercised. The headless engine printed a `user://logs` write diagnostic but exited 0 with a successful report; it did not affect assertions.

This fixture does not run an actual `plc_i05` model clone through the shared group, actual animation clip tracks, textures or GPU. Its pose/collision/attachment callbacks are controlled. It cannot prove original-resource visual parity or all-family support. The earlier all-seven-mode **synthetic** paired test remains separate: `.cache/particle-geometry-worker/candidate-e/headless-chunks.json` passed 6,872 checks over 180 frames, 150 worker frames; the direct serial/worker geometry fixture passed 2,167 checks with ordered range/batch equality. Do not combine those scopes into an original all-mode claim.

## Installed original-model OFF/ON worker pair

`tools/nwn64/prepare-geometry-worker-installed-models.cjs` copies the source closure of the installed-model oracle into a private project and changes only its fixture: the first presentation runs serially, the second requests the geometry worker. The fixture compares exact packet bytes, ordered `first`/`count`/bounds ranges, per-owner state/clip/recycling, shared RNG state/draws and callback event order on every frame. It asserts actual worker execution and lists every source emitter it skipped as unsupported. Source pins and the same private worker DLL are in `.cache/nwn64/geometry-worker-installed-e/installed-receipt.json`.

Run command (PowerShell):

```powershell
$fixture=(Resolve-Path .cache/nwn64/geometry-worker-installed-e).Path
$install=(Resolve-Path '..\..\FullDecomp\NwnRootInstall').Path
$out=Join-Path $fixture 'installed-report.json'
& .tools/native-core/Godot_native_core_e_win64.exe --headless --path $fixture --log-file (Join-Path $fixture 'engine.log') --script res://tests/geometry_worker_installed_models_test.gd -- --install=$install --report=$out
```

Result: exit 0; **1,668/1,668 checks, 21 emitters from eight installed original MDLs, 36 worker frames, 41,370 worker vertices**, `unsupported=[]`. Report SHA-256 `484bb91add77b6087ee8f635efc47f1a025d0b22929fbccaacd2474287d38dbc`. The original draw modes exercised are Normal, Aligned_to_World_Z, Billboard_to_World_Z, Linked and Motion_Blur; update families are Fountain, Explosion and Single. Model/resource identities and each emitter's authored mode/update/flags are in the report. The fixture uses actual MDL hierarchy, TRS and emitter clip pools, native wind owner and deterministic chunk service boundaries. It does not construct the complete original actor/attachment scene or render pixels.

A separate read-only census of the 323 sealed recorded original model names is in `.cache/nwn64/geometry-worker-installed-d/mode-census-b.json` (SHA-256 `9a107c38235951b576bacefefa0c5d20c0edef6532a8216fbe5ca8cba387a0f4`). It parsed 286 installed originals, found 198 emitters and the same five render modes; 37 names were unavailable or did not parse in this installed catalog. Billboard_to_Local_Z and Aligned_to_Particle_Dir were **absent from this corpus**, not proven unsupported by the implementation. The synthetic seven-mode worker parity remains the only check for those two.

The older `native_perf140_particle_clock_models_test.gd` cannot serve as a current attachment-clock gate: it calls `ModelRigs.particle_clock_binding`, which current `systems/model_rigs.gd` no longer defines. It failed under both the private worker DLL and accepted DLL for that exact missing contract. Neither failed clock report is acceptance evidence.

`tools/nwn64/prepare-current-clock-worker-pair.cjs` replaces that stale route in a private fixture with the current `ModelRigs.playback_state.bind(id,0)` Callable used by `ActorInstance`. It uses installed original `it_torch_000` and `plc_cndl01` model/clip data, creates two independent rigs/presentations, and binds each native emitter's source to an attached rig node. The controlled attachment anchor moves every frame. At frame 12 the original animation restarts; at frame 20 a new rig takes over the clock Callable through native control while the retained attachment source remains alive; at frame 28 one emitter is removed from each presentation. Both presentations continue through frame 35. Source and binary pins are in `.cache/nwn64/geometry-worker-clock-current-b/current-clock-receipt.json`.

Run command (PowerShell):

```powershell
$fixture=(Resolve-Path .cache/nwn64/geometry-worker-clock-current-b).Path
$install=(Resolve-Path '..\..\FullDecomp\NwnRootInstall').Path
$out=Join-Path $fixture 'current-clock-report.json'
& .tools/native-core/Godot_native_core_e_win64.exe --headless --path $fixture --log-file (Join-Path $fixture 'current-clock-engine.log') --script res://tests/geometry_worker_current_clock_test.gd -- --install=$install --report=$out
```

Result: exit 0; **667/667 checks**, four original emitters, 33 worker frames, 8,526 worker vertices. There were 72 exact paired clock witnesses, 70 clock changes, two witnessed animation restarts, 70 attached-source movement witnesses, four rig clock authority replacements (two models in each presentation), and two emitter retirements. Ordered range/packet bytes, owner state and shared RNG/callback order remained exact. Report SHA-256 `d1d68cac5a2e48bb057c65c22fcbcf29ccc28576ef159a0856d28528734cb558`. This validates the current Callable boundary under a controlled attachment; it does **not** reproduce a complete actor model replacement that destroys and reconstructs its emitter/pose nodes, nor live network animation events.

## Strict unsupported family gate

The private strict fixture was rerun with the **current** `particle_stream_group.gd` SHA-256 `9dc67c696580c04f9d810b3fabe68af68446ecf16298a497d1c72d63062ce440` and current `particle_emitter.gd` SHA-256 `40161ab7b85b9382a78f9c9ce60b12cf9f8cb67823a1a93929eddc99c0d8aecd`. `.cache/nwn64/geometry-worker-strict-current-a/strict-report.json` passed, SHA-256 `f244887bdfde744232ad7715d64d24840021a4060cac979f5eb0edf59e3b7771`. One reference/custom-owner emitter was explicitly suppressed: `suppressed=1`, `native_fallbacks=1`, `old_ticks=0`. Closing the strict group, toggling an unregistered emitter, and direct tick did not reactivate the old surface. This verifies exclusive-path policy for that unsupported case, and also demonstrates the user-visible risk: an unsupported emitter disappears under strict opt-in.

## Remaining acceptance matrix

1. Finish headless original-resource coverage for Billboard_to_Local_Z and Aligned_to_Particle_Dir from an identified installed MDL, and test a full actor model replacement that reconstructs its emitter/pose nodes. Lightning still lacks an original worker-path case. A required suppressed effect is a failed acceptance gate.
2. Under an exclusive graphical lease, use installed original assets for Fountain, Explosion, Single and Lightning, a chunk effect, native wind and scene collision, plus all seven draw modes. Record source hashes, every registered/suppressed reason, active/vertex counts, draw range order and RNG/clock witnesses over spawn, motion, attachment, disable, retirement and area reset.
3. Compare same-camera OFF/ON frames and pixels for atlas, lighting, tint, two-sided/additive blend, fog and gamma with matched clocks and particle seeds. Use original `plc_i05` and representative torch/portal effects; include first use and later steady state.
4. Only after visual/correctness passes, pause other agents and run matched OFF/ON Arelith Tracy and FPS legs with the same engine, DLL, settings, camera route and recording. Report frame median/p95, particle callback wall/CPU, suppressed count, worker frames and visual differences. Keep the accepted default until this gate passes.
