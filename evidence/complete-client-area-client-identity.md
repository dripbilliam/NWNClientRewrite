# Assembled ClientArea messages and client identity readers

Target NWN:EE `89.8193.37-17`, unchanged nwmain.exe SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original instructions/Ghidra are read-only; no original asset/binary copies,
injection, actual network sends or Ghidra edits.

## Complete sender composition

`scripts/probe-live-complete-client-area.mjs` composes the decoded ClientArea
sender with normal live AreaMessageRuntime packing and the actual scalar,
text, ID and send-envelope owners. All five installed Prelude areas work in
explicit fixture modes0/1. Loading screens use installed active loadscreens
data and shared RNG. The complete packet contains the outer header and body;
it replaces neither the legacy local transition adapter nor real transport.
PLAYER_ID42/language0/expansion support are declared fixtures, separate from
canonical controlled object565 and negotiated capabilities.

`scripts/inspect-live-complete-client-area.py` executes the unchanged original
sender1404cd9d0..1404ce035, full packer140363200..140364661, ambient/sound
packers, real scalar/text/ID writers, atan2f and send-envelope owner
1404dc490..1404dcb46 together on the same loaded-data snapshots. All10
messages match every defined bit and all final writer state. The native
send boundary receives the complete bytes with envelope80/4/1. Server,
table/GFF/lookup/feature/logging/net boundaries remain captured fixtures.
The normal writer's undefined padding remains explicitly masked.

Reports: live-complete-client-area-v1.txt/live-complete-client-area.json,
native-live-complete-client-area-v1.txt and
native-live-complete-client-area-observations.json in backups/animations.
Existing header-only oracle files remain intact for earlier reader checks.

## Actual client reader distinction

ReadOBJECTIDClient1409737c0..1409737e8 returns the raw DWORD and advances
the cursor even when the read exceeds its declared byte range. It preserves
the high wire namespace bit. The existing server reader clears that bit.
`NativeMessageReader.readObjectIdClient()` therefore remains a separate API;
it does not silently place proxy IDs into the local canonical registry.

ReadCExoLocStringClient1409735f0..1409737b4 resets optional sound ResRef
and duration outputs before reading the reference BOOL. Literal strings use
the actual CString reader. References read gender1bit and DWORD STRREF,
set shared talk-table gender, then perform lookup. Lookup status0 warns and
returns empty; any nonzero status uses the returned text and requested sound/
duration outputs. Text preserves embedded NULs while normalizing leading NUL.
`readLocalizedClient` supplies explicit TLK/gender/warning owners rather than
inventing a successful lookup. This is not full native TLK parsing/loading.

`inspect-native-client-message-identity.py` executes both unchanged readers
with real writers/setup/scalar/string readers.312 cases match IDs, strings,
capacities, cursor state, diagnostics, shared gender and optional outputs.
TLK queries, optional ResRef copy and allocation remain captured boundaries.
Report:native-client-message-identity-v1.txt and corresponding observation JSON.

## Receiver research frontier

Exact diagnostic string140e3e528 has a verified instruction reference at
14076ddbd in handler14076d910..14076f5f4. The client functions are unnamed
in this Ghidra database, explaining earlier name-search misses. The case1
entry is14076dc43. Ghidra pseudocode ends prematurely at a free(nullptr)
call; the complete assembly continues through loading screen setup, four
FLOATs and BOOL at14076e29e..14076e2fc, overflow check, then area loader
1407dba70 at14076e315. The loader's complete range is1407dba70..1407dea0e;
it obtains the client message through1406abf90, reads raw client ID and
resource/name, then the remaining area data and scene dependencies.

Captures: native-client-area-receiver-search-v1.txt, xrefs-v2.txt,
native-client-area-receiver-asm.txt, ghidra-client-area-receiver.txt,
native-client-area-load-message-asm.txt, ghidra-client-area-load-message.txt,
native-client-message-identity-readers-asm-v2.txt. The initial references to
the containing string prefix produced no match; exact symbol text did.
No AreaReady sender string matches were found. The known server ready
handler expects Area subtype3; client emission/scene timing remains unproven.

## Validation and limits

1,423 tests pass (complete-client-area-all-tests-v2.txt); build passes
(complete-client-area-build-v1.txt). Prior rendered git-area-transfer-ui-v1
checks still cover radial casting, Follow/Stand, stable-ID companion transfer
and dismissal; this change adds unconnected client reader helpers and no UI
flow. Original executable hash rechecked unchanged. Autosave omission remains
recorded. Full receiver/ready transport, production client lifecycle and
continuous spell/combat/campaign acceptance remain open. Formal goal active.

Verified backup report:backups/animations/complete-client-area-checkpoint.txt.
