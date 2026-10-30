# Compact scenery option

At the user's request, the compact leaf Part implementation is retained as a
persistent option: Main Menu → Options → Graphics → **Compact scenery
(experimental)**. Default off. A short note explains that it uses fewer scene
nodes, FPS gains are unproven, and it applies when the next area loads.

`rendering/compact_scenery` in native options stores a validated boolean. Changing
the checkbox does not rebuild existing placements or alter in-flight batches.
The native raw-world full area boundary updates the shared pool's construction
policy. New connection/area construction uses the saved choice. Both policies
have separate template identities; immutable original resources remain shared.
`world.pool.static_part_layout` exposes the actual applied policy. Explicit
diagnostic `--static-parts=compact|separate` overrides the startup preference
without silently persisting it; actual user checkbox changes still persist.

The restored candidate is the hash-verified authored version from
`native-loading-compact-parts-rejected-v1.zip` (SHA256
eb8f498a8c0e8956c5504fee5f051f76c861abe73980bea08662bfe3dca660b2),
with the native options integration added. Physical Parts/render surfaces,
original vertices/textures, hidden collision, parent transforms and private state
are preserved. Only eligible mesh leaves absorb the redundant wrapper. Skins,
animated meshes, dangling features, non-leaves, emitter/reference/light Parts
keep the prior path. Original source/override resolution is unchanged.

## Validation and performance scope

`native-loading-compact-options-ui-v1`:36 checks cover real native checkbox
input, default off, persistence/reconstruction, explicit diagnostic precedence,
malformed settings and existing particle/profiling/interface controls. The
Graphics screenshot was visually inspected; the control and explanation fit.
`native-loading-compact-options-exact-v1`:70 checks preserve byte-exact GPU pixels
on three sealed original models, physical hit results, packed instance isolation
and clean teardown. `native-loading-compact-options-cache-v1`:16 cache/ownership
checks. All use normal-heap CDB with complete engine/lifetime error gates.
`native-loading-compact-options-area4-v1` finishes all630 original entities with
actual compact policy, all workers joined, finish acknowledged and no engine
errors. Additional owned local validation is recorded in its scoped audit.

Earlier full comparisons removed about23% of total scene nodes; they did not
establish a steady FPS improvement. The 3–4% higher short sampled frame means
also do not establish a statistical regression. Node count is not measured total
memory consumption. Memory/transition comparisons remain future work, and the
broader loading/playability goal is not complete. See the historical experiment
note for complete observations and source/data boundaries.
