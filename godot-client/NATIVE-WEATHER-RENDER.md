# Original rain/snow presentation — work in progress

Godot now renders the original rain and snow resources through the existing
original-derived particle workers and native dynamic surfaces. These are
independent private visual models, not replicated game entities. Models,
emitter tracks, bitmaps and UVs come from the session's normal resource
resolver and hashed external runtime bundles. No proprietary assets are in
the source checkpoint.

This remains **work in progress**. One full-scene run crashed with native
heap-corruption exit `0xc0000374`; its cause is not known. Later clean checks
do not establish that the failure is fixed. Lightning/thunder, weather audio,
native world-timer pause behavior, broader custom weather and complete
particle lighting/wind/fog parity remain incomplete. The last accepted
checkpoint is still `native-retirement-tested-v1.zip`. No online connections
or clean performance benchmarks were used.

## Implemented rendering and ownership

- Six independent instances surround the controlled player's current world
  position. The camera determines orientation and the2×3 layout. A native
  camera/world-frame adapter preserves Z-up/Y-up distinctions.
- Each original model supplies four emitter nodes:24 independently owned
  emitters per active weather set. Backend workers receive original physics,
  clip and texture-presence metadata; Godot receives the original texture
  templates and rendered vertex streams. Emitters wait for actual native
  poses before consuming random values or spawning at the resource origin.
- The original play/clear/external-advance/freeze sequence samples the native
  animation/controller owner at intensity/100. It is not a hard-coded spawn
  rate or continuously looping clip. This also preserves animated velocity:
  full rain approaches13 and snow4.5 in the actual original clip data, rather
  than retaining the models' default unanimated values.
- Resources import once per physical weather type in an admitted world;
  every use owns fresh nodes/rigs and particles. World identity, connection,
  area, generation and ticket guard preparation and publication. Private
  model and emitter IDs do not collide with canonical or visual-effect IDs.
- Type/clear transitions remove particles and retire the six native models.
  Area replacement destroys the entire weather owner and its immutable
  resource cache. Shutdown explicitly retires live weather before particle
  and environment teardown. Late streams cannot recreate removed surfaces.

Rain's original tinted flag exposed a previously missing scene-light-color
provider. The native path explicitly delegates that lighting to Godot: its
CPU vertices retain neutral lighting tint and original emitter colors, while
a lit native material applies scene ambient and direct/point light. The
shader treats billboard particles as lit points rather than Lambert faces.
Normal/additive blending, original texture alpha and front winding remain
explicit. This is an **engine lighting difference**, not a claim of native
per-emitter CPU lighting equality. Untagged missing lighting providers still
fail explicitly; original flags are not stripped. The shader uses the
[documented Godot light processor](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html#light-built-ins)
and its light-energy normalization.

## Evidence and limits

Pinned original binary SHA256:
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
The state/request/setter evidence is in [NATIVE-WEATHER.md](NATIVE-WEATHER.md).
Placement executes original block `1407e7f05..1407e81f2`, helpers normalize
`140230920`, cross `14022fba0`, Yaw `14022f690` and YawPitchRoll `14022f6d0`.
Assembly sets pitch and roll to zero: the decompiler's repeated-yaw parameter
display is misleading. Static helper analyses are retained in
`reports/native-weather-normalize-v1.json`, `native-weather-yaw-v1.json` and
`native-weather-quaternion-v1.json`.

- `weather-placement-v3.json`:87 synthetic native camera/player cases,
 522 model placements,3654 comparisons; position arithmetic exact and
 quaternion components within1.2e-7. CRT sqrt/trig calls are explicit
 Python-math float32 stubs, not a CRT parity claim.24 additional native
 camera-adapter checks independently verify the player-centered high cell
 and camera-relative horizontal direction.
- `weather-particle-lighting-v1.json` and `-v2.json`:five actual Vulkan checks
 each for double-sided and original front-culling variants, including red,
 green and ambient lighting, original stream layout and owner retirement.
- `weather-render-backend-v1.log`:101 focused particle/provider, weather,
 protocol/scope, sky/environment, shutdown and offline area regressions pass.
 Untagged tinted emitters still reject the unavailable scene provider.
- `weather-particle-world-v2.json`:15 existing native particle ownership,
 first-emitter startup, clock/event, backpressure and retirement checks pass.
 Its old test double lacked the already-required transfer ticket; v1 exposed
 that stale fixture, and v2 supplies the actual scope contract.
- `weather-render-local-v3.json`:33 real localhost weather checks. Rain and
 snow each produce nonzero pixels in a weather-only Vulkan viewport.
- `weather-render-local-v5.json` and `-v6.json`:40 checks each, five real
 SetWeather requests,24 productive emitters for each rain/snow rendering
 sample, then additional live rain/snow across actual A–B–A replacement.
 Old native weather owners/models are destroyed while each new world lives.
 Each run admits three animated worlds, creates36 actual weather models
 across six batches, and quits while rain is still active. Final native
 retirement releases all18 tracked outer world owners; all particle worker
 epochs close with zero remaining threads and tracked UI survivors are zero.
- V6's three weather-only passes affect8084/1527/8181 pixels with
 9216/13104/9504 submitted vertices. These are visibility checks, not FPS
 measurements or native-image equality. The editor was preserved.
- V6 records every instance's frozen clip/time/speed and four emitter
 birthrate/velocity samples. The milestone verifier compares144 controller
 values against independently sampled original exported tracks (tolerance
 1e-4) and18 frozen clocks against the float32 original play sequence.
- `weather-render-normal-v1.json`:ordinary local16-check dialogue/examine
 and animated presentation regression, followed by clean native retirement.
 The ordinary GodotFeedback1 owned server is restored.

Retained failures: v1 could draw snow but rain correctly stopped at the missing
light-color provider. V2 crashed with heap corruption after a shader cache
miss, without a useful native stack. V4 rejected a duplicate inherited test
field at compile time; it is not counted as runtime evidence. The standalone
lighting passes and subsequent v3/v5/v6 runs do not prove v2's cause. The first
adapter test tried to use a camera before SceneTree initialization; the
deferred v3 test is the successful result. No failure was relabeled a pass.

Next work must investigate the native crash under a controlled fresh shader
compilation workload, then complete weather lightning/audio/timer behavior
and broader reconnect/cross-server/custom-content coverage. Full migration,
public-server compatibility and the complete moving-scene60FPS goal remain
active and unaccepted.

Follow-up: [NATIVE-PARTICLE-MATERIALS.md](NATIVE-PARTICLE-MATERIALS.md) records
three confirmed cold-compile runs before, and two after, per-surface material
reuse. Allocation stress and Vulkan readback pass; the old heap fault still
has no proven cause. These are additional evidence and a resource-lifetime
improvement, not a replacement for the retained failure or full acceptance.
