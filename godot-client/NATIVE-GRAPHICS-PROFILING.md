# Native graphics settings and frame accounting

The normal native client now exposes **Main Menu → Options → Graphics → Enable
particles**. Changes apply immediately and persist in the rendering section of
`user://native-options.cfg`. Particles now default off. Malformed preference values
retain that default; an explicit saved boolean remains the user preference. The Performance tab can independently enable/disable
detailed profiling and displays the principal frame timings.

## Particle control

`native_render/particle_visibility.gd` belongs to the session host, above all
areas. Emitters register weak references when admitted and unregister when
retired. Disabling particles hides their drawing and disables their process
subtree; both automatic callbacks and explicit/manual ticks are gated. Existing
resources and simulation state remain retained. Re-enabling resumes them rather
than preparing their models again. Newly streamed emitters inherit the setting
before their first tick, including across area/reconnect boundaries.

This is a presentation preference. It does not remove server objects, disable
movement collision, change gameplay effects or turn off model lights. Unsupported
native particle features remain unsupported; this increment does not complete
their migration. The direct native entry is the scope of this menu.

The offline capture tool also defaults off. Use `native-world.ps1 -EnableParticles`
to opt in, or `-DisableParticles` to state the default explicitly. These flags
do not change the user's saved menu preference. Historical on/off comparisons
below remain diagnostic visual ablations, not graphics-preserving optimizations.

## Frame accounting

`native_render/frame_profile.gd` measures an interval from the first native
process-frame work through the late profiler callback. Separate, non-overlapping
callback-owner spans cover:

- Root protocol/world processing, movement/admission and model animation.
- Particle callbacks, including diagnostic counters and publication bookkeeping.
- Terrain, object, creature and reference preparation/publication.
- Worker-result delivery/catalog completion and world retirement.
- UI/inventory/font/icon updates, camera, keyboard and environment/weather.
- Model-light/shadow selection, reference poses, wind and walkmesh preparation.

The frame record publishes `accounted_callback_ms`, `unattributed_callback_ms`
and `callback_overlap_ms`. An overlap is exposed rather than silently counted
twice. `outside_callback_ms` is the rest of the frame interval: it can include
engine traversal, rendering/driver work, physics, waits, post-draw continuations
and scheduling. It is not attributed wholesale to any one subsystem.

Additional nested measurements include protocol read/decode/apply/encode/write,
selection registration, deferred HUD refresh, the full native particle call
(including its ABI conversions), particle counters, GPU icon readback and icon
render waits. Render waits are elapsed waits, not CPU work. Native C++ particle
subphases remain available. Parent callbacks, child spans, profiler self-time
and asynchronous render CPU/GPU counters **must not be added together**.

Records also include node/object/resource/orphan counts, CPU static memory,
render/texture/buffer memory, draw/triangle counts, queued/running asset workers,
world-admission counts, model lights and selected point shadows. Available engine
pipeline-compilation monitors are discovered rather than assuming every Godot
build exposes them. Summaries retain the worst frame's complete record.

Periodic work is averaged over all frames with zeroes for frames where it did
not run. `when_present_mean` and `active_samples` separately show its conditional
cost/frequency. This prevents a 5 ms summary performed twice in 240 frames from
being reported as a 5 ms cost on every frame.

Profiling itself has costs: recording, collection and summary work are reported
separately. Record self-time covers the measured recording function body, not
every clock call or instrumentation cost. Disabling detailed profiling stops
phase collection and viewport timing. These measurements are diagnostic, not
zero-overhead benchmark results.

## Protocol host

The normal launcher writes `reports/<run>.performance.jsonl` while detailed
profiling is enabled, including when enabled through Settings after launch.
Samples include the actual particle switch state and a separate `protocol_host`
record with interval CPU time, event-loop utilization/delay and process memory.
The event-loop delay sampler uses 20 ms resolution; its values include platform
timer/scheduling effects, not exclusively application stalls. Sampling stops
when detailed profiling is disabled.

JavaScript still owns protocol/download services, not rendering. No JS render
dependency is added. Native internal engine/GPU costs and OS scheduling are not
fully attributed by these script-level spans; the explicit remainder is retained
for further investigation.

## Verification and findings

Final-source reports:

- `particle-settings-profile-final-v3`: 19 actual checkbox, persistence,
  streaming-inheritance, pause/resume and frame-accounting checks. The adjacent
  `.json.png` verifies the Performance tab's layout.
- `particle-settings-registry-final-v1`: 36 interaction/hidden-portal checks.
- `particle-settings-retirement-final-v1`: 72 deferred-retirement checks.
- `particle-settings-runtime-final-v1`: 30 original-data particle/actor GPU checks.
- `particle-settings-local-final-v3`: normal client entry on the owned Prelude
  server. Main Menu opens Settings; all 57 registered emitters pause and restore;
  all 20 world objects remain loaded; authoritative movement completes and zero
  workers remain. Test preferences are isolated from the user's settings.

Tests use normal-heap crash diagnostics and source hashes. No public-server
connections were made. The original editor was preserved, so these are not clean
FPS or full multiplayer/performance acceptance.

The same saved room, original model/texture resources and camera were used for
two 240-frame diagnostic runs:

| Capture | Settled mean interval | Approximate FPS | Active particles at finish |
|---|---:|---:|---:|
| `particle-settings-room-on-v1` | 27.71 ms | 36.1 | 693 |
| `particle-settings-room-off-v1` | 5.93 ms | 168.7 | 0 |

Both retain 1,351 emitter nodes and the same 710 explicit unsupported-effect
failures; only the enabled run simulates/draws supported particles. Both finish
with no worker tasks remaining. Turning particles off deliberately changes the
effects, so it is not visual-parity acceptance or a prediction of live FPS.

The enabled run's full particle callback cost averages 20.84 ms, compared with
the narrower existing `native_particles` span at 18.69 ms. Native dispatch takes
9.84 ms inclusive of its child phases; GPU render time averages 0.89 ms.
Unattributed callback time is 0.82 ms and outside-callback time 4.53 ms. Measured
profiler-record self-time alone is 2.34 ms and overlaps the callback spans.
This strongly identifies particle CPU/owner overhead as the dominant remaining
cost; it does not establish the best next representation or complete binary
parity. More detailed live data can now distinguish its subparts.

## Rollback

Authored-source checkpoints:

- `backups/particle-settings-profile-before-v1.zip`, SHA256
  `c9d4d1aca49b96c910190f8118f8a2603151c71565168b84da3e55bb4cc58e9e`.
- `backups/particle-settings-profile-after-v1.zip`, with adjacent verified hashes.

`reports/particle-settings-profile-final-audit-v1.json` records final source-pin
verification. Earlier failed/partial checks are retained under their original
run names and do not replace the final evidence above.
