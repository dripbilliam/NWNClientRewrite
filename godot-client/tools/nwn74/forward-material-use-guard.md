# NWN-74: avoid repeated material-use marks

The patch in this directory is for the project's customized Godot Forward+ engine source. Apply it to `servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp` in the matching engine tree. It records the previous material pointer within one render list and calls `set_as_used()` only on the first draw of a consecutive run using that material.

`MaterialStorage::MaterialData::set_as_used()` sets `was_used=true` on each render-target cache entry. No cache population or clearing occurs inside `_render_list_template`, so repeating this mark for adjacent draws of the same material does no additional work. The first draw still marks live render-target textures.

## Source identity and verification

- Matching pre-patch source SHA-256: `49fc6ca310573c5a0704e5a6d9dfa4cf769b37d756239f7e49aa9502d1d97705`.
- Patched source SHA-256: `fe8b102c6742d12f8a51a7312bfa8b72596277ee7d2f429fce5c97d6e03846dd`.
- Patch SHA-256: `9afa0172acb7fc0acf70f5b9fdfed5a40964f6d696da7e6d03e917cc200ecf6e`.
- Applying this normalized patch to a copy of the pre-patch file with LF line endings produced the exact patched SHA-256. The reviewed engine source has the same bytes. The accepted engine executable remains unchanged.

In an instrumented dense-scene original-recording replay, the guard reduced `set_as_used()` calls from about 1,253 to 462 per settled frame (791 fewer, 63.2%) with unchanged draw counts. A Vulkan 24-mesh fixture reduced marks from 24 to 2 and rendered byte-identical red and green frames on private control and candidate engines. An exclusive four-leg normal-client comparison found no repeatable FPS improvement: mean frame intervals were 8.21588 ms control and 8.22822 ms candidate; median 7.9585 versus 7.9665 ms, p95 8.8785 versus 8.8965 ms, p99 18.6895 versus 18.839 ms. All four original-scene legs retained complete visual and base-world output with the same source, settings, and engine pair; the outer driver flagged the same sandbox shader-cache and certificate diagnostics in each leg.

The private control rebuild included 25 previously pending translation units relative to the accepted executable; the candidate changed one Forward+ translation unit relative to that control. This isolates the guard in the pair but does not justify promoting that entire rebuilt executable. This submission preserves a measured work reduction for review. NWN-74 stays In Progress for broader render-thread cost and accepted-engine integration.

The bounded operation census is recorded in [forward-census-checkpoint.md](forward-census-checkpoint.md); the matched frame summary is [guard-fps-pair-summary.json](guard-fps-pair-summary.json). The large raw traces and private engine binaries remain local diagnostic artifacts and are not part of this source patch.
