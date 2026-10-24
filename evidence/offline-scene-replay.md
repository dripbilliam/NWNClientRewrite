# Private room capture and offline replay — 2026-10-22

The user authorized recording the manually connected heavy Arelith room so
performance experiments can use it offline. They finished recording, then
authorized closing the replacement client. No automated Arelith connection
or outgoing gameplay request is part of replay.

## Captured evidence

The sealed private AppData capture is
`scene-7082141e-8484-4619-b774-59e12a8034ce`, under the application's
`scene-captures` folder. Native resource payloads stay there, outside this
workspace. `runtime-logs/performance-queue/scene-capture-v1/validated-capture.json`
contains metadata only. The first abandoned, empty capture is not used.

The 139,379,139-byte capture contains 1,298 events over 57,672 ms, including
149 camera samples, 102 object-update messages, 11 NUI creates and 186 NUI
binding updates. Context 1 has 1,533 successful resource keys, 160 recorded
misses and 411 texture selections. Its event-file SHA256 is
`36586d78ad5f60c2862db8c4789a6919da79620630e1e7e73322a202c100f058`.

All event frames, monotonic sequence/time values, context bootstrap and camera
fields validate. Rebuilding the canonical NetworkWorld imports all messages
without warnings: area `udcityhubint`, ID 2147625684, 939 registry objects,
the controlled character and 11 NUI windows. This checks decoded state, not
rendering or content completeness. Captured view counts rise from 685 objects /
734 models to 896 / 1,044, showing continued presentation work after playing.

## Boundaries and implementation

`electron/scene_capture.mjs` admits decoded scene messages and camera data,
excluding chat/authentication/raw peer traffic. Worker-side bounded writes
freeze first successfully consumed resource bytes per context, hash them,
deduplicate privately and seal a checksummed event file. Recording failures
cannot change the original resolver's successful values or exceptions. Queue
or disk overflow marks the archive incomplete.

The archive reader reproduces recorded misses; uncaptured requests are
explicit coverage failures, with no installed or network fallback. Each
read returns independently owned bytes and checks its size/hash. Timeline
verification completes before SceneReplay exposes events. Playback uses
arrival times, without waiting for async renderer preparation. Loading states
gate resource availability so early UI requests cannot access resources before
their recorded admission. Outgoing gameplay actions are rejected locally.

The private replay preload has no live connection or server discovery bridge.
The launcher imports no NetworkPeer/session implementation, blocks external
web requests, uses a temporary profile/cache and refuses to compete with other
game/Electron instances. Recorded camera position, orientation and target are
interpolated after the gameplay camera and before frustum/lighting work.

## Current validation and limits

Fifty focused capture/replay, IPC and diagnostic-profile tests pass. The isolated
replay build succeeds without changing normal dist during that build. Source
contract refresh must record current normal-dist identity: its pre-existing
`index-DOqjcyKQ.js` hash is
`7448b09d205748ab44fe0174a765e36729fa4c88433fcfa33f9c739f87db3a66`;
the earlier pinned `index-iKrqbPaC.js` is no longer present. No normal build was
performed by this replay preparation.

`replay-v1.json/.png` renders the actual room entirely offline at 1424x921,
with the final recorded camera pose. Exploratory steady diagnostics show
about 16.5 FPS / 60.7 ms frame intervals, 36.2 ms render submission, 9.5 ms
camera work and 8.3 ms particles. These are **not accepted baseline or gain
evidence**. The strict acceptance report is failed: 897 objects / 1,061 models
differ from the last recorded partial-loading sample, one model failure and
uncaptured requests remain. All 1,351 emitter entries and 700 failed emitter
entries match the recorded counts; matching pre-existing failures is not proof
of correct particle rendering.

Capture v1 did not intercept resolved talkString reads or loose audio fallback.
The explicit `--allow-text-gaps` exploratory option uses labelled placeholders
and keeps the completeness gate failed. It never silently supplies invented
text or marks missing content as a performance improvement. Capture can also
end while renderer requests are still pending; the final live view is not a
proof of settled model counts. These coverage gaps must be addressed before
using the room as an accepted whole-client comparison.

The revised resource-admission check is verified in `replay-v2.json`: the room
again renders, the exact final camera/buffer match, emitter counts match, and
the same content-completeness gates fail. Its exploratory steady sample is
17.2 FPS / 58.3 ms intervals, 35.4 ms submission, 8.6 ms camera work and
8.1 ms particles. There are no console errors; text/resource gaps remain
explicit. This is repeatability evidence for the slowdown, not a controlled
candidate comparison. No rendering optimization is promoted by these runs.
The active >=60 FPS goal remains far unmet.

## Frozen offline supplement and complete import

The user subsequently requested using this capture as the continuing primary
performance workload, preserving appearance, with source backups at substantial
changes. A real active goal was created with the complete performance/fidelity,
local-server and no-automated-Arelith requirements retained.

The cached server manifest
`1fb727f690a7e0c462f79ef9177f5977c73d756f` matches all 918 overlapping captured
resource hashes, with zero mismatches. The offline freezer imports only the
missing requests into separate private supplements, never modifying the original
recording or replacing its recorded expected misses. The freezer reads local
cache/installation/Workshop bytes; replay itself still has no such fallback.
Both manifest SHA1 and asset checksums are verified. Supplement provenance must
match the parent's event checksum.

`supplement-v1.json` freezes all 72 first-pass gaps, plus the real base/custom
talk tables (17,126,973 bytes). `supplement-v2.json` freezes two newly discovered
texture dependencies (14,068,789 bytes including repeated talk tables). The
supplements remain under private AppData, referenced by metadata reports only.
Authored CPU tests check original-key/miss precedence, foreign-parent rejection,
independent resource ownership, audio type selection and base/custom native TLK
record semantics. Thirteen capture/replay tests plus four diagnostic tests pass.

`replay-complete-v1.json` has zero uncaptured resource requests, zero text gaps,
zero object-model failures, zero scene-failure diagnostics and zero console
errors. It renders 898 objects / 1,077 models and 1,357 emitter entries, of which
700 retain their prior failure state. Independent final canonical membership is
885 active placeables +8 creatures +4 doors +1 ground item =898 renderable IDs.
The captured final partial-loading view has only 896 objects /1,044 models and
1,351 emitter entries; **the old exact-view-count parity report remains failed**.
The complete import is not original-client visual parity or a performance win.
Its settled inventory is retained for a future controlled fixture comparison.

The owned renderer CPU profile is source-mapped against its exact immutable
`index-BtO0iwKH.js` build in `replay-complete-v1-cpu-summary.json`. Over 16.6 s,
sampled self time includes Three render/project/uniform work, hierarchy/matrix
traversals, particle work and shadow submission. Sampled sources include about
4.63 s in Three's renderer module, 2.03 s in Three core, 0.82 s particles,
0.71 s main batching and 0.70 s shadow traversal. Inclusive values overlap;
profiling adds overhead. Its roughly 10 FPS diagnostic run is exploratory,
not an accepted FPS comparison. No dropped lights/effects or shader arithmetic
change is justified by these figures alone.

Verified source checkpoint: `backups/captured-room-baseline-20261022.zip`,
3,247 source/evidence/authored-bundle files, 8,396,711 bytes, SHA256
`a4eca9a6759053cca8cb8be64af58950737d468c7607e955d1c3de6f78762726`.
Each ZIP entry was reopened and checked against its source manifest. No native
binaries, private asset payloads, profiles or credentials are in this checkpoint.
Use `scripts/checkpoint-performance.ps1` with a new readable name before the
next substantial rendering architecture change; it refuses overwrite.
