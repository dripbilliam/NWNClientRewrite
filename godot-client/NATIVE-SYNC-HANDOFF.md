# NWSync content replacement across native server transfers

Owned-server A→B→A now verifies distinct NWSync manifests, data replacement,
native image-cache replacement, resource unmounting and cached return. Native
download controls remain gated before admission. Normal-client portal adoption
is still disabled pending native **cross-server content cancellation/failure**
checks. This does not accept full multiplayer, rendering or sustained60FPS.
No online game server was queried or connected.

## Implementation and fixture

The existing NWSync download/cache/decoder, installed resources, resolver and
portal protocol are reused. Each new native session gets its own resource owner.
The opt-in local host reads a strictly checked descriptor for two loopback HTTP
repositories, uses a fresh shared private cache and disables installed NWSync
reuse. Character data and credentials stay in the backend. Only bounded download
counters and native UI test results cross into Godot.

`tools/nwsync-fixture.mjs` retains its original13-resource default manifest,
SHA1 `f0d2810094a755f78d8032139b82c0c63eb71890`. Optional authored A/B variants
provide15 resources each: twelve changed2DA markers, one same-named TGA with
different pixels, one marker unique to that server, and a resource-backed child
JUI. Raw, zlib and Zstandard blobs are used. No original art is copied.

The root menus are created by actual server scripts in authored GodotHandA5/B5.
Their `gd_sync_icon` image and `port_nui_jui` child resolve from the current
NWSync manifest through the real staging/NUI/native resource path. Original skin
and fonts still load from the normal installed resources. The same child JUI
resource name has distinct A/B text, and server callbacks acknowledge edits and
native GUI clicks. The two module hashes are:

- A5: `08b74d119dfde54ae13d6a7a03c0d2da6e6c63ab85292bdab3cccb2bb27c8928`
- B5: `13cb6ea7b6c25e070c98ca932bc4b76d5f04827ce15b3058fd93b2fed4b74aa8`

`reports/nui-handoff-server-fixtures-v4.json` also pins their authored HAKs.
Those HAKs supply the server scripts' child resource; the advertised NWSync pack
contains the client copy. The resolver continues to honor the wire requirements
instead of rediscovering missing HAKs from a local module IFO.

The native observer records each connection's real progress, captures cold
download controls after a rendered frame, and disconnects its signal on shutdown.
The NUI probe samples the actual native texture bytes. JSON number types are
converted explicitly before comparing the expected RGBA values.

## Accepted evidence

`reports/native-sync-handoff-local-v3.json` and its
`native-sync-handoff-local-v3-roundtrip.json` child both pass:

- Three native animated admissions and48 dialogue/examine checks. The underlying
  real character-download/source-release, arrival waypoint, fresh identity,
  scoped character persistence and retirement requirements remain mandatory.
- **14/17/17 native NUI checks**: watched edits, GUI-routed child/acknowledgement
  clicks, original fonts/skin, reused token/handle fencing and concurrent menus.
- All15 mounted resources have the expected SHA1 and length on every admission:
 45 successful resource checks. The other server's unique marker is unavailable
  in all three sessions, proving it is not retained as a fallback mount.
- The same `gd_sync_icon` texture resolves to RGBA[240,170,20,255] on A,
 [40,100,220,255] on B, then the original A pixels on return. Native images and
  download/menu screenshots were inspected.
- Real advertisements select manifests
 `600d9ae8fe700d80de7c9f9dd85f9d30176114e1` and
 `4554dd56dee14abf297409dc776c61f144f4f8bf`. Acceptance matches each
  actual advertisement to its expected manifest.
- Each cold manifest makes exactly16 successful completed HTTP requests: one
  manifest plus15 blobs. A requests finish before its first admission completes;
  B requests occur between the source and destination checks. Returning to A
  makes **zero new requests** and all native progress reports zero downloaded
  bytes. Both loopback repositories close after the run.
- Native progress reaches15/15 on all three admissions. During checking or
  download, character admission is disabled and Cancel remains available. Cold
  screenshots capture the actual enabled Cancel and disabled Play controls.
- All retired native owners/resources are freed, NUI pending resources are0,
  all particle worker epochs close without pending jobs/threads, native exit0
  and disconnectedtrue. No game script/renderer/leak errors. Pre-existing
  missing particle bitmap/wind diagnostics and Vulkan loader warnings remain
  separate from this milestone.

`reports/native-sync-handoff-backend-v1.log` has **175 passing tests**: NWSync
decoding/cache/HTTP corruption/cancellation and native resource ordering; native
portal/lobby/NUI/vault ownership; strict changed-content gates; loopback descriptor
validation; preserved default fixture; and existing presentation checks.

The strict `tools/sync-handoff-evidence.cjs` gate extends the full NUI/character
handoff gate. It refuses mismatched advertisements/hashes/pixels, surviving old
resources, stale progress, early character admission, nonzero return downloads,
partial native gameplay or unfinished cleanup. The outer HTTP evidence separately
checks completed request counts, timing and absence of return requests.

## Reproduction, retained failures and limits

Generate the authored modules once with
`node godot-client/tools/create-nui-handoff-servers.mjs --revision=4 --nwsync-icon`.
Run `node godot-client/tools/test-sync-handoff-local.mjs --report=<unused.json>`.
It manages only owned profiles on127.0.0.1:5121/5122, starts two ephemeral loopback
HTTP repositories, advertises their manifests with empty-server reload disabled,
runs the actual native client, then stops the secondary and restores ordinary
GodotFeedback1. Both repository servers close. The user's editor stays open.

v1 is retained as failed: all14 then-present data resources downloaded correctly
and the texture had the right pixels, but the native assertion compared JSON
numeric variants incorrectly and the child JUI was absent from the advertised
content. The corrected fixture adds the authored child to the manifest and
normalizes numeric types. v2 failed preflight because one duplicate-count check
still expected14; it made no game connection. v3 verifies all15 resources and the
full trip. Failed reports are not promoted or overwritten.

Cross-server cancellation while content is in flight and recovery after required
content failure still need native/local evidence before normal-client adoption.
Earlier initial-login cancellation/cache/repair results remain in
[NATIVE-NWSYNC.md](NATIVE-NWSYNC.md), and peer connection cancellation/failure
remains separately verified in [NATIVE-HANDOFF-RECOVERY.md](NATIVE-HANDOFF-RECOVERY.md).
They are not substitutes for those combined transfer tests. Public servers,
large content sets, full NUI/rendering/weather migration and complete moving-world
performance remain unaccepted. Incidental sparse-fixture FPS counters do not
complete the60FPS goal. No online connections until the user reauthorizes them.
