# Ordered main-draw batching prototype — not enabled

2026-10-21. The performance goal remains **active**. The previous geometry
sharing turn made verified progress. This turn implements and measures a main
submission prototype. Its GPU comparisons pass, but its local dense frame
times regress. **Production explicitly sets `enabled:false`.** Do not describe
this work as an adopted FPS improvement or a completed performance goal.
All native connections are to owned loopback5123/5121. No Arelith connections.

## Mechanism and fidelity

`RendererMainBatches` uses Three's already sorted opaque render list after the
ordinary shadow pass. It combines consecutive compatible rigid Lambert draws;
it never sorts around an unsupported draw. Source geometry, materials, object
hierarchies, gameplay IDs, picking and shadow casting retain their owners.
Transparent, skinned/deformed, negative-scale, custom-state and unsupported
texture draws retain ordinary submission. Unknown render callbacks or texture
upload callbacks keep the whole opaque pass ordinary because they may mutate
later objects. Renderer-owned keyhole callbacks are marked local; those tile
draws themselves remain ordinary. The owned spell-target shader extension is
supported, including its original world coordinates and shared uniforms.

Private combined geometry contains unchanged source float positions, normals,
UVs and a draw index. CPU-computed source model-view, normal and world matrices
are uploaded as float32 uniform arrays, alongside per-draw color/emission/UV
scale. Up to32 draws share an upload, constrained by vertex uniform capacity.
Only occupied uniform slots are uploaded. VBOs grow by powers of two to the
actual vertex count, with an explicit64MiB vertex-data bound. Standard external
`GLBufferAttribute` VBOs update through COPY_WRITE_BUFFER, preserving VAO state.
Hidden private meshes register the buffers during Three's next scene projection;
the creation/growth frame retains ordinary draws. Renderer hooks and lists
restore in `finally`; private materials are hidden after rendering, including
before subsequent override/clipping paths. Partial allocation failure releases
private owners and keeps ordinary rendering until reset.

RGBA byte DataTextures can share array layers when sampling state agrees.
Power-of-two repeat images tile into a common square layer with inverse UV
scaling, without resampling pixels. This preserves texel derivatives, periodic
edges and mip content in the measured GPU cases. Clamp/unsupported images keep
their own dimensions or ordinary draws. Dynamic, compressed, manual-mip and
custom-upload textures remain ordinary. There is no additional texture sampler,
so shadow admission is unchanged. Raw palette storage is capped64MiB, plus its
GPU mip storage; vertex buffers have their separate cap. All arrays, buffers,
materials and source references retire at reset/context loss/disposal.

## Actual GPU and behavior checks

`probe-main-batches.cjs` runs authored meshes with the actual installed native
target-preview shader, loaded read-only into memory. Proprietary shader bodies
are not saved in the workspace. HTTP is blocked, and no game connection is
made. Metadata records the shader resources/hash. The fixture exercises64 point
lights/15 shadows, anisotropic mip sampling, different repeat texture dimensions,
nonuniform and negative transforms, changing alpha/color/UVs, removal/readdition,
fresh position/UV attributes, all four target-preview shapes, real context loss
and restoration, custom callback fallback, material override and global clipping.

All32 final images,32 **primary** point-shadow atlas images, triangle counts
and callback counts match ordinary rendering exactly. The other fourteen shadow
maps are active and affect the final images, but are not separately read back.
The simple authored scene reduces97 draws to roughly13–19 on active batching
frames. Unsupported/fallback frames intentionally retain ordinary calls. VBO
handles, private root membership, palette and vertex byte counters all retire.
`main-batches-v1.json/.png`, final run-v8 and26 focused tests pass. Tests cover
ordered barriers, source streams/poses, palette bytes/samplers, constructor
failure, lifecycle and existing light/shadow behavior. The first fixture run
had missing manual GLBufferAttribute bounds; it is rejected, not a pass.

## Native measurements and rejection

Same authored DensePerf a→b→a fixture,3440×1369,48 wandering multipart NPCs,
20-second steady observations with6-second camera rotation per visit. No public
server input. Each run closes all three area worker pools, GPU preparation
templates, shared rigid geometry leases, shadow proxies and main-batch owners.

| Build/run | FPS a / b / a | Reported p95 ms | Main draws | Render ms |
|---|---|---|---|---|
| Working geometry-sharing v16 |33.29 /38.64 /38.73|33.7 /29.2 /29.0|1906 /1873 /1875|16.5 /12.0 /11.8|
| Initial active batches v18 |23.71 /28.78 /28.28|72.7 /49.3 /50.1|1714 /1688 /1659|23.3 /15.8 /16.0|
| Adaptive/normalized v19 |30.97 /34.99 /34.45|36.2 /32.9 /32.6|1438 /1482 /1480|18.2 /14.3 /14.4|
| Final production OFF v20 |33.19 /35.97 /38.53|33.8 /31.7 /30.4|1858 /1900 /1879|16.0 /12.5 /11.8|

These are medians of rolling sampled metrics. Sequential wandering, visibility,
cache state and profiling vary; they are not matched original-client FPS ratios.
v17 remained on a spell-target callback fallback and gave no batching benefit;
it also overlapped source-map generation during entry and is diagnostic only.
v18/v19 are rejected performance candidates despite correct movement/cleanup.
The initial model reserved32 transforms and16384 vertices even for pairs.
Adaptive storage fixes that waste and normalizes repeat dimensions, but the
remaining short runs and descriptor/state bookkeeping still cost more than
the saved calls. v19 retains82–86 batches for roughly481–517 participating
draws; palette storage reaches64MiB, vertex data roughly2.7MiB.

v19's CPU profile attributes about1.87aggregate self CPU seconds per20-second
observation to main-batch/palette code. Its descriptor, palette and callback
checks are measurable costs. Three's self CPU time falls, but the added work
offsets that saving. The source-map archive for rejected ChuUYlpz and working
B6pHP0rE bundles is preserved; the summarizer selects matching maps. v18's raw
metrics are retained without claiming a source-mapped function attribution.

Final build `index-BcM04PKH.js` explicitly disables the prototype. v20 completes
with zero model/worker/renderer failures, all48 NPCs moving each visit, readiness
11.25/11.43/8.65seconds and no retained batch bytes or proxies. Its p95 still
misses16.7ms. The owned dense server PID7856 is stopped after testing; other
servers are untouched. Main submission, matrix traversal and per-object light
work remain open. Further work must produce a measured improvement before this
prototype is enabled; broader keyhole/texture coverage and less bookkeeping
are candidates, not achieved outcomes.

The final Prelude/academy check passes at94.91FPS,12.2ms reported p95,
4.2ms render submission,2.70seconds to first controlled presentation and
5.39seconds for the transfer. All1424 shared geometry records,65 preparation
templates, shadow owners and batch counters retire. The existing actual
installed keyhole/target-preview/cursor input fixture also passes after adding
hook metadata. Final authored and dense screenshots were visually inspected.
`main-batches-proof-v1.json` and its verifier pass while explicitly recording
`candidateAccepted:false`, `productionEnabled:false` and `goalComplete:false`.
The known main/resume trailing blank-line warnings are pre-existing.
