# NWSync admission in Godot

Status: native download/cache/mount/progress/cancel flow verified against the
owned NWN server and a loopback HTTP repository. Public-server authentication,
Arelith handoffs and large public content sets are separate, unaccepted work.
The launcher still permits only `127.0.0.1:5121`.

The native lobby now shows manifest loading, resource counts and received MiB,
then retires those controls when content is admitted. Cached content has a
separate checking label. Character selection remains gated by the real session's
resource resolution. Cancel works throughout the resource stage, including
after the initial login promise has already resolved. Failed required content
has visible feedback and can be cancelled before retry. Connection replacement
rejects old progress. Repository URLs, cache paths and provider objects stay in
the backend; only bounded counters enter the native progress UI.

NWSync cache/manifest diagnostics also reach the native debug/report owner,
alongside the existing backend callback. Successful corrupt-cache repair is
therefore recorded independently of its HTTP request and verified resource hash.

The existing `electron/nwsync_content.mjs`, `nwsync_reader.mjs`,
`installed_network_resources.mjs` and resource resolver are reused unchanged.
Their NSYM v3 catalogs, raw/zlib/Zstandard NSYC decoding, SHA-1/size verification,
bounded parallel downloads, atomic content-addressed cache, required/language
manifest selection and original resource priority feed the same resolver used
by native presentation. Existing original-client SQLite stores are read-only;
the helper process handles SQLite and Zstandard outside the presentation loop.
Private-cache availability uses its hash inventory at admission, with byte/hash
verification and repair on resource demand. No per-frame download work moves
into Godot.

Distinct manifests across real owned-server A→B→A are now verified separately
in [NATIVE-SYNC-HANDOFF.md](NATIVE-SYNC-HANDOFF.md), including native image-cache
replacement, old resource unmounting and a zero-request cached return. Combined
transfer/content cancellation and failure/retry remain required before enabling
normal-client adoption. These are localhost results, not public-server parity.

The original JS client and its resource/session modules were preserved. Native
changes are in `tools/native-lobby.mjs`, `tools/resource-progress.mjs`,
`systems/character_lobby.gd` and the local host. The lobby also ignores a local
preview read that finishes after character admission, and test auto-play waits
for the actual preview rather than racing it.

## Actual local evidence

`reports/native-nwsync-local-v8.json` passes all four scenarios. The installed
read-only NWN server advertises manifest
`f0d2810094a755f78d8032139b82c0c63eb71890` from an ephemeral `127.0.0.1` HTTP
repository. Thirteen authored resources include raw, zlib and Zstandard blobs,
twelve 2DA markers and a TGA texture; no installed artwork is copied. Installed
NWSync reuse is disabled and test caches are isolated external temporary folders.

| Scenario | Actual HTTP evidence | Native result |
| --- | --- | --- |
| Cancel during download | Four pending HTTP responses aborted | 8 checks; no character read or world admission; retry available |
| Cold login | One manifest plus 13 resources downloaded and completed | 10 NWSync +16 dialogue/examine checks; animated moving admission |
| Cached login | Zero HTTP requests | Same 10 +16 checks and all 13 mounted resource hashes verified |
| Corrupt cached blob | Exactly the damaged blob downloaded again on demand | Same 10 +16 checks; all mounted hashes and texture pixels correct |

All four clients exit 0 and disconnect with no rejected commands, engine errors
or leaked objects/resources. Native screenshots capture the actual progress bar
and decoded downloaded texture. These frames use the authored room and are not
performance benchmarks. Verbose Vulkan overlay-loader warnings remain separate
from game errors and do not establish a rendering regression.

`reports/nwsync-lobby-ui-v1.json` passes 12 rendered Vulkan checks, including
actual pointer cancellation, determinate/manifest progress, cache labeling,
failure/retry controls and admission gating. The existing native lobby regression
passes 20 checks in `reports/nwsync-character-lobby-regression-v1.json`.
`reports/nwsync-backend-v4.log` passes 187 backend checks with no failures/skips:
NWSync decoding/cache/HTTP corruption/cancellation, read-only SQLite reuse,
resource ordering, typed progress, stale owner rejection, preview/admission race,
strict evidence gates and existing camera/gameplay-service regressions.

The owned fixture's original GodotFeedback1 module remains byte-identical
(`0923e003ef612d80e5b1423661b05ab6492cbc4ff95edf7e9857751b3fe2a237`).
`scripts/local-multiplayer-server.ps1` accepts explicit loopback-only fixture
URL/hash parameters, verified against installed server option strings
`-nwsyncurl`, `-nwsynchash` and `-reloadwhenempty`. Disabling empty-server reload
for this test keeps the actual advertisement present across all four logins.
The test restores the ordinary GodotFeedback1 server without advertisement
parameters and closes its HTTP server; test clients/readers are gone. The editor
and other original-client instances are preserved.

## Retained failures and scope

Earlier local reports are retained. v1 exposed the late preview/admission race.
v2/v3 reached the world and passed the NWSync checks but failed shutdown because
a camera lookup script's static initializer retained its resource. Replacing
that initializer with an immutable constant releases it; the retained original
camera oracles still pass 10,434 command/location/attachment comparisons and
16,593 core comparisons. This is a lifetime fix to the camera work in progress,
not acceptance of its complete live command behavior.

v4's cached login and v6's post-cancel login received no NWSync advertisement
after the local server automatically reloaded its empty module; the required
authored resources were consequently absent. v7 disables that fixture reload
and records a real advertisement on each admitted login. v5's cancellation was
performed but its test completion used an area-only message before any area
existed; that test renderer was explicitly stopped. v6/v7 use the pre-world
message path. Failed runs are not promoted or rewritten.

v7 passed the complete functional lifecycle. v8 repeats it with native cache
diagnostic forwarding, including the actual corruption/repair entry in the
Godot report. The warning-only verbose Vulkan loader messages are retained.

This milestone does not verify every malformed repository, compression
dictionary, large catalog, interrupted application restart, disk/permission
failure, public authentication, master-server transfer or NWSync-provided
animated model. General downloaded resource lookup is shared with native model
preparation; this actual fixture proves mounted tables and a rendered texture.
Large-room fidelity and sustained moving-scene 60 FPS remain open. No Arelith
connection was made.

Reproduce with an unused filename:
`node godot-client/tools/test-nwsync-local.mjs --report=unused-name.json`.
It replaces only the owned local test server, runs four native clients in
sequence and restores GodotFeedback1. The complete migration goal remains active.
