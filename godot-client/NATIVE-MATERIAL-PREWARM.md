# Native material prewarming and streaming stalls

2026-10-27. Material prewarming is now enabled at graphical client startup.
It prepares20 production material classes, one per frame, and keeps their native
shader owners alive until shutdown. Two authored4×4 white images are used only
as private warmup inputs; they never replace, render as, or modify world textures.
The existing safe render-thread mode and PackedScene instancing remain.

The user returned and asked for a decision after the current offline comparison,
then a manual Arelith test. Stop additional automatic graphics/performance tests
after the default startup verification. Do not make automated public connections
or edit runtime sources underneath their live test.

## Findings and chosen adaptation

Finer template timing separates source installation, collision bounds, ownership,
packing, disposal and cloning. Installation further separates part/node creation,
geometry/material creation, mesh binding and material binding. Bounded top16
template receipts identify the model and original source hash. Post-draw metrics
belong to the next wall interval; inspect both ordinary and postdraw_ phase names.
A top16 subset is not a complete all-model timing distribution.

On the frozen corpus, material_override assignment took roughly27–30 ms for some
first-use material classes. It persists without CDB: actual original ttu01_a02_03
measured28.423 ms, and ttu01_l08_04 measured26.814 ms in unattached runs.
Material-first assignment compiled the same pipelines and did not remove the wait.

The profiler had searched for an obsolete Performance constant prefix and thus
recorded no pipeline counters. The installed4.7.2 API actually exposes five
PIPELINE_COMPILATIONS_* constants. The corrected profiler records cumulative
values and nonnegative per-frame deltas, with a fresh zero baseline on enable.
Historical empty pipeline_monitors lists mean unobserved, not zero compilations.
A supported, data-only RenderingServer callback records actual render/main thread
IDs without waiting on the presentation thread.

The successful adaptation requests material RIDs before entry, using the existing
ResourcePool.material recipe for textured/untextured, opaque/alpha/scissor,
emission and shaded/unshaded combinations. It retains20 material and2 texture
owners in a private pool. No server/model/spell/table data is hard-coded, and
canonical resource lookup/ownership is unchanged. Retaining the bounded owners
prevents first-use shader work recurring during later source installation.
Headless authority tests skip graphical warmup.

Read-only original MdlNodeTriMesh::InternalCreateInstance0x140091b80..140091bdc
allocates a private0xc0-byte PartTriMesh and calls its constructor at the recovered
call site; constructor0x140087fd0 stores the model pointer at0x140088028 and creates
private material state at0x1400880ab. Exact complete recovered code/assembly is in
../backups/animations/rea-loading-static-instance-v1.json, pinned original
NWN:EE89.8193.37-17 x64 SHA256
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a.
This supports separating shared model definitions from private instances. It does
not establish the original client's entire shader startup policy. The Godot warmup
is a measured adaptation, not a claim to have copied an unverified native scheduler.

## Evidence

Separate-process original-model fixture12 checks:
native-loading-prewarm-probe-{reference,candidate}-v1. Three sealed original model
installs retain their textures and geometry. Binding phases23–24 ms become about
0.05–0.13 ms after roughly111 ms of total up-front material/RID work.

Whole-area same-source comparison:
native-loading-prewarm-area4-{reference,candidate}-v1. Both deliver all630 entities,
drain workers/cache and finish with clean complete engine logs and acknowledgments.
The known costly binding in the reference's retained template peaks is29.663 ms;
the candidate's retained top-template binding maximum is0.179 ms. These differently
ranked top16 sets are not paired measurements of every model. The separate fixture
provides the direct per-model comparison. Player ready3042.348→2933.453 ms is a
single observation, not statistical proof of a general entry-time or FPS gain.
Candidate warmup prepares20 classes, then releases all20 materials/2 images.

Current default verification uses native-loading-prewarm-verified-suite:
6236 checks/44 cases, including existing loading/ABI regressions,8 actual pipeline/
thread API checks and both12-check warmup/cold fixtures. The first suite stopped
because PowerShell merged two fixture arguments into one catalog path; the corrected
suite quotes separate arguments. Failed logs are retained and assertions unchanged.
The source/receipt gate is tools/audit-native-material-prewarm.mjs. Its successful
receipt additionally requires the default complete630-entity area, current source
hashes, prepared/drained warmup owners and owned local Prelude19-entity load.
The local test is headless authority/loading coverage; graphical warmup is proved
separately. Original assets remain in the sealed private capture, outside source.

## Rejected alternatives

Prototype cloning:54 exactness/ownership checks, including three byte-exact actual
GPU model comparisons. Only signed-zero representation and autogenerated unnamed
light IDs are excluded from fingerprints; nonzero poses and original streams stay
exact. Complete441/630-entity area comparisons preserve coverage, but clone peaks
rise from about2 ms to7–9 ms and entry does not improve. Production prototype code
and its experimental fixture were removed. Verified authored archive:
native-loading-template-prototype-rejected-v1.zip,
0cf52d0f4d038f23281428567c075b722141fb7ec6b4ca0a953972b9855a3629.

Material-first binding:24 exact original GPU/source/ownership checks pass, but
pipeline counts and approximately27 ms binding stalls remain. Production flag/
branch and fixture removed. Verified archive:
native-loading-material-order-rejected-v1.zip,
a692e271dcf9bddff329addc8999b2fd4e85b527b22768e1d22516cc0b8a7fae.

Separate rendering thread: actual thread IDs prove it is active. The installed
engine labels it experimental, reports a finalize-on-wrong-thread error and two
leaked objects at shutdown. Full630-entity diagnostic also fails its complete
error gate; packing can then absorb the queue wait. It is not enabled by default,
and no warning/error is filtered. Replay and debugger tools retain explicit mode
selection only for future diagnostics.

This work does not remove all packing, cold source/table preparation, startup
pauses, missing captured resources or establish original-client/full multiplayer
parity. The broader loading goal remains active pending further playability evidence.

## Verified handoff

Authored checkpoint `backups/native-loading-material-prewarm-v1.zip` contains
1,426 files and passed manifest readback verification. SHA256:
`5ded20e1e35af6e80b8a5df66387caf8dc92ee8eca47c60fa0d83089711d3e6c`.
The archive predates this self-reference note only; runtime sources are unchanged.

At the user's request, the profiled client was launched for manual server
selection as `native-session-1793134320019`. Startup produced a ready image and
performance JSONL; the initial read-only log check found zero engine/script error
lines, with the process responsive. Particle bitmap/wind warnings exist and are
not suppressed. This startup observation does not establish public-server
gameplay or performance acceptance. No automated server connection was made.
