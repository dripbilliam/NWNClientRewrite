# Prepared-model cache investigation

## Current decision

Persistent model preparation is **implemented as an opt-in prototype and OFF
by default**. It correctly reuses calculations, but the full-client comparison
does not justify enabling this implementation generally. The overall >=60 FPS
and <=16.7 ms p95 goal is still unmet. No Arelith connections were made.

The user's replacement client was already absent when the authorized close
command checked its exact executable/command line. Tests used only the owned
private DensePerf UDP5123 server and offline fixtures. The owned server and test
clients are stopped; other local servers were preserved. The final normal
build has comparison hooks removed and existing experimental switches off.

## What is cached

`electron/prepared_model_cache.mjs` and its bounded Node worker pool save parsed
base MDL data and rigid geometry preparations. `src/prepared_model_geometry.js`
contains the extracted production calculation used both by cold rendering and
worker preparation: expanded positions, UVs, normals, material groups, bounds,
source vertex indices and original picking faces. Rendering copies prepared
attributes into instance-owned BufferGeometry; the existing rigid geometry
lease pool still owns GPU lifetime. Skinned/deformed geometry remains live.

Disk keys combine SHA-256 of the authoritative source bytes with a preparation
schema. The schema includes local parser/geometry dependency source, worker and
cache code, package lock and V8 serialization ABI. Checksummed files are written
atomically. Corruption or schema/content changes cause rebuilding; storage
failures do not prevent rendering a calculated result. The memory buffer cache
has a 256 MiB limit and disk retention targets 2 GiB, with serialized incremental
eviction accounting. Oversized entries are not written. The default application
directory is `app.getPath('userData')/prepared-models`; native test data stayed
in owned OS temporary directories, never in the workspace.

`src/persistent_model_sources.js` retains renderer base data with a 256 MiB
**serialized-size accounting budget**; actual JS heap use can be higher. Every
returned model owns its animation/diagnostic arrays. Own clips and nodes remain
immutable sources, as already shared by instances. Inherited animations are
resolved anew against the current context's parent models. Position, animation
clock, posed vertices, equipment, materials, textures, lights, particles,
object IDs and live scene roots are not persisted in this cache.

New connections validate model content against the authoritative resource
owner. Within one mounted connection, base data can be reused directly between
areas. The context is the main-process session UUID, which rotates on portal
handoff. `NetworkGameSession` initializes its resolver once and ignores repeated
module-resource initialization (`network_game_session.mjs`); mod changes are
blocked while connected (`network_ipc.cjs`). This cache follows that mounted
context lifetime, not live editing of resource files under an active connection.
Changed files are picked up on the next resource context and checked by content.
Callers without a context identity always validate. Equal names across contexts
cannot bypass validation. An area can stop waiting for shared preparation as
soon as its ModelSourceCache closes, without cancelling another consumer's work.

The new IPC route only accepts a model resref and optional content key from an
attached trusted main frame. It obtains resource bytes from the current native
session and rechecks ownership after IO/preparation. A failed service falls back
to ordinary worker decoding; a missing resource remains a missing resource.

## Measurements and rejected variants

The first disk-only path successfully retained 65 models across a client
restart, but did not improve area loading. It repeatedly restored/transferred
about 19 MiB of decoded base data per area. Renderer reuse removed 128 of those
transfers and reduced repeated rigid geometry constructions from 321 to 107
over three local visits (214 avoided). Cross-process tests nevertheless varied
too much to infer a stable full-client gain. Direct context reuse then removed
128 backend model requests as well. All these variants remain non-default.

The most useful test is `dense-local-prepared-model-alternating-v1.json` and
`prepared-model-alternating-summary-v1.json`: one client process, twelve visits,
native shadow maximum **verified as 1** in every area, 3440x1369 render size,
moving native NPCs, identical profile instrumentation, two initial warmup
visits excluded, then alternating two-visit cache/off blocks. Before/after
uncached visits to the same room estimate local time drift.

| Cache case | Uncached neighbor estimate | Cached | Load change |
|---|---:|---:|---:|
| Restore into empty renderer cache, pass 4 | 12.90 s | 13.75 s | +6.62% |
| Resident context reuse, pass 5 | 13.85 s | 13.11 s | -5.31% |
| Restore into empty renderer cache, pass 8 | 12.70 s | 13.33 s | +4.95% |
| Resident context reuse, pass 9 | 13.69 s | 11.20 s | -18.18% |

Corresponding phase-median FPS changes were +7.93/-3.66/-0.33/-1.24%. NPC
motion/draw counts vary and steady phases were only five seconds; these are
descriptive, not deterministic FPS acceptance. There were zero cache failures,
zero model-service fallbacks and no renderer errors. All twelve area's workers,
GPU preparation owners and shared geometry leases retired after disconnect.
The main cache had 64 disk hits and 64 memory-buffer hits, zero recalculations.
Resident context visits skipped the backend entirely. This is evidence for
useful retention, not evidence that disk restoration or steady FPS is solved.

Earlier `baseline-b-v2` stalled before creating a renderer because a Page-domain
command preceded document creation; its owned bootstrap was explicitly stopped
and recorded. `baseline-b-v3` terminated with a native login timeout. A reset
empty fixture allowed subsequent controlled runs. `baseline-b-v4` requested
shadow 1 but actually used 3, so its requested-setting metadata is not proof.
The final harness enables the Page domain, verifies the startup preference and
asserts actual native maximum 1. Those earlier artifacts are not relabeled.

The measured baseline worker CPU spent only about 151 ms parsing 64 models in
one area. Another 779 PLT tasks and resource/texture delivery remain outside
this model cache. The minute-long live tail in `teleport-loading-followup.md`
cannot be explained by model parsing alone. Next work should target immutable
source/rule/palette reuse and the ordered resource/texture queue; preserve raw
resource ownership, palette variants, shader profiles and the arrival-to-visible
boundary. A RAM cache fed directly by existing decoders may avoid the extra
main-process restoration/transfer cost. Do not enable this disk path merely
because it saves calculations.

## Correctness and final verification

- `prepared-model-cache-tests-v9.txt`: **96/96 pass**, including the installed
  original MaxFace fixture (an unprivileged earlier run skipped that fixture).
  Covers format/content invalidation, atomic disk reload, bad files, eviction,
  concurrent ownership, same-name contexts, current-parent inheritance, early
  close, fallback and stale/trusted IPC boundaries, geometry and picking.
- `prepared-native-model-roundtrip-v2.json`: 26 named reads, **21 distinct
  installed model contents**, including tiles, placeables, player bodies,
  heads, equipment and a robe. Every own model field matches the direct parser
  after disk reload; prepared rigid attributes, groups, bounds and picking data
  match cold calculations exactly. Zero recalculations on reload. Only
  hashes/counts enter the workspace; temporary derived files were removed.
- The first native roundtrip caught null-prototype property dictionaries being
  normalized for binary MDLs. The final cache restores them for all formats
  after V8/IPC cloning. The failed v1 artifact remains. This correction came
  after the timing run; do not claim that run profiled the exact final cache
  implementation. The final correctness tests cover it separately.
- `prepared-model-geometry-gpu-v4.json`: **16/16 identical color and point-shadow
  frames**, from a worker-prepared then disk-reloaded authored model, with live
  rotations, scales, positions, alpha and material groups. Current source hashes
  are recorded. No joins or fetches. `model-geometry-prepared-cache-v2.json`
  separately checks 24 frames each for ordinary/shared rigid geometry, skin/
  deformation exclusion, transparency, negative scales and material ownership.
- `prepared-model-final-normal-boot-v1.json`: final packaged renderer boots
  offline, no joins/fetches/errors; model cache is **false**, main batching and
  matrix subtree experiments are disabled, and comparison hooks are undefined.
  `prepared-model-final-proof-v1.json` records normal bundle/source/artifact
  hashes. No new whole-client FPS gain is claimed for this normal build.
