# Teleport loading and remaining performance work

## Existing live log, read only

`backups/animations/teleport-load-timeline-v1.json` summarizes the existing
`runtime-2026-10-22T01-58-37-127Z-352af876-0cdd-491c-a300-17caed16806c.jsonl`
with its SHA-256 and inspected source hashes. No external connection or input
was made during this analysis. The running user client was preserved.

Area 2147625684 (`udcityhubint`) starts approximately 02:02:35.294 UTC.

| Stage | Elapsed work |
|---|---:|
| Tileset | 117.5 ms |
| Rules | 376.6 ms |
| Tile sources | 198.2 ms |
| Tile instances | 30.1 ms |
| Walkmesh | 55.3 ms |
| First object sync pass | 6,021.8 ms |
| Area GPU variants, later | 2,495.7 ms |

The area shader event completes at 02:02:45.505. The model-source tail
continues: 260 model preparations exceeding 250 ms complete in the first
70 seconds, the last at 02:03:43.854 (68.56 seconds after the start).
Examples: `pma0` 3,967.3 ms; `c_scabbard_plt` 5,545.2 ms. These are elapsed
model/resource/texture preparation times, including scheduling and awaited
workers/IPC; they are not pure file-read or GPU times. They overlap and must
not be summed. Model counts are not object counts.

Source inspection confirms a head-of-line dependency: `NetworkScene.sync`
iterates objects and awaits each model, multipart preparation, held items and
attachments before advancing. `ResourcePrefetch` overlaps at most two source
requests, not whole-object shader preparation/assembly. The local player is
prioritized. `prepareModels` already prepares multipart sources with bounded
concurrency and compiles their variants together; that does not remove the
outer object-by-object dependency. `initial-objects` means the first sync pass,
not that all subsequent replicated objects have appeared.

Area replacement creates fresh `ModelSourceCache`, worker pools and
`NetworkScene.assets`; retirement disposes the old sources. This prevents
cross-context stale resources, but also loses reusable preparations. Cross-area
retention needs resolver/content identity and retirement accounting, rather
than a global cache keyed only by resource name.

The log lacks per-object network arrival and first-visible timestamps. It
therefore demonstrates a long client preparation tail, but cannot apportion
the entire delay between server delivery and client scheduling. Do not claim
that all objects had already arrived or that shader compilation consumed the
whole minute. Next loading measurements should record those boundaries and
object source/GPU/assembly queue times, then test bounded preparation across
objects and resource-context-safe retention locally. Preserve stale/deleted/
changed-object guards, local player priority, animation ownership and cleanup.

## Other measured work in this continuation

The combined target-preview/keyhole fixture exposed duplicate inherited target
shader hooks. The production fix in `target_preview_shader.js` recognizes its
own inherited hook and avoids duplicate declarations/cache tags. Both binding
orders have a regression check. `wide-static-batch-v3.json` passed 32 real GPU
images, checked shadow atlas output, live mutations and context recovery with
the installed shader text read in memory. Earlier v1 compilation failure and
v2 no-batch result remain recorded as failures. This fix is not proven to be
the cause of the user's teleport delay.

Increasing the uncompressed texture-array floor/budget alone made zero batches
in the native local scene: all 622 eligible tile draws use compressed DXT1
textures. `dense-local-batch-pool-ab-v1.json` regressed and remains disabled.
`dense-local-batch-eligibility-audit-v1.json` captured the texture metadata but
then failed in the measurement harness; its overall run is not a pass.

The opt-in compressed array prototype preserves encoded DXT1/DXT3/DXT5 blocks,
every authored mip and partial-block selectors without resampling. It remains
off in production. `compressed-static-batch-v3.json` passes all four S3TC
formats, severe repeat/minification, 32 GPU frames, shadows and lifecycle checks.
`dense-local-compressed-batch-pool-ab-v1.json` binds the exact QA bundle/map in
`compressed-batch-pool-ab-source-v1.json/.map`. In four alternating native local
pairs, 622 tiles formed 20 ordered batches with 5,592,512 pooled bytes and
1,622,016 vertex-buffer bytes. Median main draws fell 1,985 to 1,401. Across
phase metrics FPS was 30.57 to 31.46 and work 30.86 to 29.21 ms; paired FPS
changes were +10.84/+9.47/-0.60/+0.85%. However, first activation hit 656 ms
and bookkeeping still cost about 2.2 ms/frame. Native shadow maximum was the
default 3, not the user's target setting 1. This is insufficient for adoption
or the overall 60 FPS goal. Next batch work needs cold preparation and reduced
per-frame descriptor/hook work without stale materials or unsafe draw ordering.

The later half-resolution diagnostic `dense-local-resolution-ab-v1.json`
overlapped the user's separate replacement client (live log above; process
inventory confirmed it remained running). Treat its whole-client timing as
confounded, not a controlled pixel-cost comparison. Buffers did change from
3440x1369 to 1720x684 and return, but no performance conclusion is accepted.
No resolution reduction is enabled. Earlier QA sample fields reported stale
batch counts in disabled phases; actual draw counts and enabled-phase counts
remain useful. The diagnostic field now reports zero when disabled; this
QA-only correction does not retroactively change those source-matched runs.

## Current verification and cleanup

`loading-followup-focused-tests-v1.txt`: 30 focused checks pass, including
target/keyhole composition, all compressed formats/mips, version 1-to-2 source
refresh, existing main batches, model preparation and shared picking.
`loading-followup-normal-build-v1.txt`: normal build succeeds, comparison env
absent. `loading-followup-normal-boot-v2.json` verifies the packaged renderer
offline, no joins/fetches, no renderer errors, matrix subtree disabled, main
batching disabled and comparison hooks absent. The proof JSON binds current
source/artifact hashes. No new whole-client FPS gain is claimed for this final
normal bundle. The owned DensePerf UDP5123 server was stopped; the user client
and other local servers were left running. Overall goal remains active and
acceptance is unmet.
