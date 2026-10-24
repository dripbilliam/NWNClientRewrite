# Particle material lifetime and native crash investigation

Particle surfaces now retain one configured draw material as their dynamic
vertex buffers grow. Reconfiguration/retirement releases that material along
with the old mesh and texture. Previously every capacity increase constructed
a new draw material; lit surfaces also constructed an unused StandardMaterial
before constructing the ShaderMaterial. Buffer growth now only replaces the
ArrayMesh. Shader source, original texture/alpha, blend and winding settings,
packed streams and private weather ownership are unchanged.

This reduces resource churn. It is **not a demonstrated fix** for the earlier
heap-corruption exit0xc0000374, whose cause is still unknown. Full migration,
weather and performance acceptance remain incomplete, and the last accepted
checkpoint remains `native-retirement-tested-v1.zip`. The original rain/snow
work and its earlier failures are in [NATIVE-WEATHER-RENDER.md](NATIVE-WEATHER-RENDER.md).

## Fresh shader compilation investigation

The native game and editor use different shader caches. The failed run's exact
rain variant was in the game's `user://shader_cache`, not the editor's
`res://.godot/shader_cache`. `tests/shader_cache_inventory.gd` queries the
pinned engine's actual directories and settings without changing them.

`tools/test-weather-cold.ps1` copies and verifies only the exact owned rain
variant before removing that single cache entry. It freezes14 relevant source
hashes, requires an actual native shader-cache-miss log and regenerated entry,
runs the full localhost weather A–B–A check, and restores the original cache
bytes plus ordinary owned server module. It never clears an entire cache,
touches the editor cache, changes a registry setting or contacts a public
game server. It stops on failure and retains all per-run evidence.

- `weather-cold-series-v1.json`:three successful fresh-compile runs **before**
  material reuse, each with40 weather checks, three animated admissions and
 18 retired outer world owners. This establishes that a cache miss alone did
 not reliably reproduce the previous fault. It does not rule out a related
 intermittent failure.
- `weather-material-cold-v1.json`:two further successful fresh-compile runs
  **after** material reuse, with the same full weather/area/quit checks.
- Across the five runs:200 local weather checks,15 animated admissions,
 90 tracked outer world owners retired, no forced exits and no tracked
 surviving world/UI owners. All five actually compiled the exact rain
 shader after a cache miss. Both batches verified original cache restoration.
- The previous `weather-render-local-v2.json` remains a failure with exit
 0xc0000374. No stack establishing its origin has been obtained.

Only the application shader cache was made cold. This does not flush the
driver's private cache or prove a complete driver cold-start scenario.
The editor remained open, so these are functional checks, not FPS benchmarks.

## Allocation and rendering checks

`tests/particle_surface_stress.gd` uses authored bitmap/numeric data with the
actual production Surface class. It grows24 surfaces through eight capacities
and repeats destruction/recreation12 times, exercising all four lit
blend/culling combinations. This is2304 buffer allocations and288 configured
surface lifetimes. Readback must remain productive and weak owner references
must be destroyed after each cycle.

- `weather-surface-stress-v2.json` and
 `weather-surface-stress-cdb-v1.json`:pre-change stress passes normally and
 under CDB, with zero surface survivors. The old CDB launcher did not execute
 its startup command file, so it is not proof of armed exception capture.
- `weather-material-reuse-stress-v1.json` and
 `weather-material-reuse-cdb-v2.json`:post-change4644 checks each. All2304
 growth steps retain the same configured material;288 draw materials are
 created, and every material/surface is released. The debugger repeat traps
 access violations, heap corruption and fail-fast exceptions in **only the
 owned Godot fixture**, without instrumenting any original game process.
- The draw-material allocation count for this workload falls from one per
 growth step2304 to one per configured surface288:87.5% fewer. The unused
 StandardMaterial construction on lit allocations is also gone. This count
 is not an FPS improvement claim.
- `weather-material-lighting-v1.json`:five native Vulkan lighting/layout/
 lifetime checks. Red, green and ambient pixel values exactly equal the
 earlier pre-change `weather-particle-lighting-v2.json` values.
- `weather-material-stream-v1.json`:5026 actual GPU stream/readback checks,
 including672 read-back vertices,28 visible/8 hidden frames, original blend,
 front winding, texture selection, epoch reconfiguration and ownership.

The stress launcher retains engine/source digests, native exit, forced-exit
state, debugger exception state and stderr. A clean debugger exit by itself
cannot qualify without the complete fixture report and zero survivors.
The first normal stress attempt had an incorrectly split report argument and
exited2 before the fixture ran; the grouped-argument v2 is the successful run.
The first debugger launch hit a PowerShell variable/switch name collision
before launching the engine; it was corrected without changing production.
The capture self-test then exposed `-g` skipping the debugger command file.
The final launcher requires actual START/ARMED log markers and uses only a
local symbol search path. `weather-material-cdb-trap-v2.launcher.json` and its
CDB log verify capture using an explicitly requested OS.crash in the authored
fixture:actual illegal-instruction recordc000001d and current-thread stack.
That report records `workloadPassed:false`; the expected fault cannot count
as a completed rendering test. The first self-test lacked the illegal-
instruction filter and is retained as failed capture evidence. `.ecxr` was
unavailable at the first-chance event; the logged exception record and current
thread stack were captured, with export-relative Godot names rather than
complete engine PDB/source symbols. No claim of full context/source diagnosis.

Both normal and debugger stress tests are narrower than the complete game.
The investigation has not reproduced or diagnosed the historical fault.
Future failures must retain a native stack rather than being accepted from a
subsequent clean rerun. Continue the full multiplayer migration; do not treat
this investigation or the resource reduction as renderer/migration completion.
