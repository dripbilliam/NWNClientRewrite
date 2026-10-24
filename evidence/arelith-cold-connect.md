# Arelith fresh-content connection test

2026-10-19 local / 2026-10-20 UTC. User explicitly requested an initial connection to `arena.arelith.com:5123`, downloads, and reads of newly downloaded data rather than reuse of existing content. The current original client and local server are left running. No character is uploaded, no gameplay/chat is sent and no original binary, asset, cache or Ghidra project is modified.

## Observed connection and resource advertisement

DNS resolved to `195.201.102.8`. The first encrypted connection completed its key exchange but received BNVR rejection16. The original shared-code `CNetLayerInternal::DisconnectPlayer14023a020` maps TLK reference10452 (`0x28d4`) to BNVR16; the installed original English message is “Your CD Key is still in use. Please retry in 5 minutes.” `CServerExoAppInternal::ConnectionLibMainLoop14055dc90` handles key collisions through that reference. This establishes the native meaning, not which other/stale session occupied the key. No CD-key change or authentication bypass was attempted. The later retry succeeds, with clean disconnect and no character upload (`arelith-initial-login-v2.json`).

Both the public BNXI/BNXR discovery and a separately authenticated `serverStatusRequest` advertise repository `http://nwsync.nwnarelith.com` and primary manifest `1fb727f690a7e0c462f79ef9177f5977c73d756f`. The authenticated requirements name custom TLK `arelith`, no explicit NWM and no separate HAK list. The public module name is `ARE_PGCC`, with server-vault characters. Remote build is8193/revision36/postfix12; the researched local client is89.8193.37-17. The recorded login/advertisement exchange has zero diagnostics. No server-vault selection or world-entry parity is claimed.

This is a separate HTTP repository, not asset streaming on the game UDP connection. A disconnected game session therefore does not by itself establish that NWSync downloads failed. Here HTTP downloads continue independently after a clean game-session disconnect.

## Fresh-content policy and discovered compatibility issue

`scripts/download-advertised-server-content.mjs` creates a unique empty directory under external AppData `NwnReplacementClient/ContentTests`. It uses the production `NWSyncContent` with `nativeDirectory:null` and16 bounded workers. Actual server manifests and NSYC assets remain outside this research workspace; reports retain derived metadata only. Each new object is decompressed and verified against manifest SHA1/size before atomic compressed-cache insertion. The helper is used only for Zstandard decompression; no original SQLite catalog/inventory/blob lookup is enabled. Production `installedNetworkResources` also gains an explicit `reuseInstalledNWSync:false` policy, covered by a test that fails if any original-cache reader is constructed.

The fresh manifest is4,162,620bytes, NSYMv3, with97,820 physical entries and2,462 mappings:100,282 resource references,97,820 unique objects,7,064,452,695 uncompressed bytes and432 `.2da` tables. Its SHA1 matches the advertised hash. Two valid archive keys contain trailing spaces (`pfh0_bicepl062 ` MDL and `vs_okku_hide ` WAV). Our first parser rejected spaces, so the initial download failed before asset transfer (`arelith-fresh-download-v1.json`). The corrected manifest/native-catalog parsers and network resource IPC retain space-padded keys exactly while rejecting control/path characters. Native `CResRef::InitFromCharArray140190d30` copies up to16 bytes without trimming, confirming why these keys must be preserved. The final download starts in another empty directory, rather than reusing even that first manifest attempt.

Public BNXR decoding is separate from authenticated CNWMessage decoding: extension2, nonzero presence, byte-length URL, byte-length primary SHA1, count, then additional entries `(flags,language,byte-length SHA1)`. This order comes from original `HandleBNXRMessage140244ad0`; additional-entry flags/language precede the hash here. `readServerInfoAdvertisement` accepts later unrelated info extensions. Synthetic truncation/flags/language tests and the actual public response cover this decoder.

## Validation status

The full download and read are **complete**. `arelith-fresh-download-v2.json` records97,820 verified objects,3,119,557,358 HTTP body bytes including the manifest,97,821 HTTP200 responses and zero diagnostics/read failures. It ran00:36:25..01:04:46 UTC (28m21s). All432 `.2da` tables and the custom `arelith.tlk` were parsed from freshly downloaded, SHA1-verified bytes. The TLK contains9,062 entries, including4,353 nonempty strings read. Physical table row counts are classes100, racialtypes95, skills29, spells2,036, feat2,691 and baseitems253; these are catalog rows, not claims that every row represents a player-selectable option. Separate partial reads checked98 then321 arriving resources with no failures; those probes verified SHA1 and cache write time and never fetched or touched original profiles. No server/class/spell IDs or URLs are added to production rules.

`smoke-fresh-arelith-context.mjs` passes through the real `installedNetworkResources` → `resolveServerResources` → `openModule` → `loadNetworkObjectRules` path using this same new cache. All six decoder rule tables hash-match the downloaded manifest. Alternate TLK lookup returns the actual custom string, and both space-padded model/sound keys load with matching hashes. This check makes zero HTTP requests and zero original-cache reader calls; resources are ready, with zero diagnostics. It takes about12s to mount/check this complete collection and perform these reads. Installed base KEY catalogs are ordinary fallback inventories; no stock rule data substitutes for the tested Arelith overrides. Results: `arelith-fresh-context-v1.json`.

73 focused checks pass (`arelith-content-focused-v2.txt`), including public discovery, NWSync formats/compression/cache/offline/cancel/precedence, explicit cold-cache policy, session admission, resource IPC and preserved archive names. `arelith-content-build-v1.txt` passes, retaining the existing bundle-size warning. No full suite is run. Final combined acceptance passes `scripts/verify-arelith-cold-connect.mjs` (`arelith-cold-connect-acceptance-v2.txt`). The source/evidence backup is `multiplayer-arelith-cold-connect-20261019-v2.zip`; downloaded game assets stay external. Further game/UI/server-vault work is outside this initial connection test.

Read-only REA dossiers: `backups/animations/rea-arelith-*.json`. Native target SHA256 `3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`. Credentials travel only through the existing one-use encrypted in-memory bridge. Reports contain packet tags/counts, not raw authentication bodies or key material.

## Normal application cache reuse (2026-10-19 local)

The first interactive launch used Electron's persistent application cache,
`AppData/Roaming/nwn-model-viewer-research/server-content`, while the deliberate
cold-download proof above stayed in its separate `ContentTests/.../cache`.
The same manifest was advertised; this was a cache-directory mismatch, not an
Arelith update or failure to persist the original download. The normal cache
initially held779 objects/about30MB. That interactive transfer subsequently
reported resource resolution failure; a connection retry is needed.

`scripts/seed-nwsync-cache.mjs` now reuses the completed owned cache through
same-volume atomic hard links, without overwriting existing targets, extracting
assets into override, changing active manifests or touching original game files.
All97,820 compressed headers and the source manifest hash were checked;
96,393 objects were linked and1,427 already existed by the time of promotion.
Normal decompression/hash/size verification remains mandatory when an object
is demanded. This operation does not claim a second full decompressed hash
audit of every object; the initial cold download performed that verification.

The production cache owner then admitted the complete manifest offline and
read classes, racialtypes, skills, spells, feat and baseitems with normal hash
checks, making **zero HTTP requests**. The normal cache now contains all97,820
objects. Evidence: `backups/animations/arelith-production-cache-seed-v1.json`.
Future joins reuse that persistent cache; changed manifests may still require
new objects. Cache admission may scan files without downloading them. No
production code or server-specific cache path was hardcoded by this repair.
