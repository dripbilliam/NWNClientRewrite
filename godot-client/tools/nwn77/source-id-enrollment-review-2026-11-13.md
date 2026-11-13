# NWN-77 source-ID enrollment work reduction

This is a narrow work-reduction patch in `systems/native_render/static_scenery_batches.gd`, not a batching promotion or FPS result. Source SHA-256 changed from `092a2b21b72fefb7b80d14b291b51b89b12fedeb100f13fd3b916160a41e2870` to `ac8de01acbe2e0bc52566c13b61777322eaaa5fc638ca0e6963de38c31db5f95`.

`consider_tile()` previously called `source.get_instance_id()` to check `members` and again when constructing the enrolled row. It now reads the ID once for both operations. For each newly eligible surface this removes exactly one Object ID lookup; the ID, grouping key, row, eligibility, signals, rejection counts and draw publication are otherwise unchanged. In the prior original-scene optional static merge, 1,086 source surfaces were eligible, so this applies to an entry-time cohort of that scale. The grouping path is opt-in and the default individual path does not call this code. It is not a per-frame savings claim.

The pinned private engine's existing headless batch fixture reported 57 checks and zero failures; the merge fixture reported 46 checks and zero failures. Each engine exited 0 and the wrapper verified no source drift. Both wrappers returned `success:false` solely for the isolated root-certificate-store diagnostic already present in the earlier preflight. Receipts:

- `.cache/native-presentation-parity/static-scenery-agent/terrain-instancing-nwn77-id-cache-20261113-batch/run.json`
- `.cache/native-presentation-parity/static-scenery-agent/terrain-instancing-nwn77-id-cache-20261113-merge/run.json`

`git diff --check` passed. The measured optional static merge ABBA still shows no reproducible normal-client FPS gain, so NWN-77's visual and performance acceptance remains open. No default was changed.
