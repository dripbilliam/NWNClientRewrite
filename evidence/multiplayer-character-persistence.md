# Native character export and durable vault — 2026-10-19

Implementation toward the active full multiplayer goal. Live v131 received and
durably saved original-server exports after equipment changes and a Light cast.
Fresh saved-entry reconnect acceptance passed for equipment and stacks. Original binaries,
running original client/server and Ghidra databases were not modified.

Target NWN:EE89.8193.37-17 nwmain SHA256
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a.
Native path and retained function dossiers: multiplayer-character-export-
investigation.md. Exact client sender1407bfbe0 calls1407c25c0 at1407bfbf4 with
major6/minor31 and null/zero body. Server4531b0 case31 calls ExportReply at
140455263; writer1404dceb0 emits3/10 after authoritative PackCreatureIntoMessage.
Client module dispatcher1407a4d30 case10 calls receiver14079b1c0, which reads
two localized names, DWORD size and opaque BIC and waits before pending close.

Original-code oracle executes the complete client sender and server pack block
1404bceb5..1404bcf27 with original locstring/DWORD/VOIDPtr codecs.20 cases cover
format0/1, custom/reference names and0/1/7/128/4097byte synthetic blobs. BIC
serialization, filesystem, virtual name getters and transport are explicit
boundaries. The ten format1 replies decode byte-exactly. This is not a complete
SaveCreature emulation. The pack block's VOIDPtr writer1402dbc20..1402dbccc is
included rather than replaced by a JS-format assumption.

NetworkGameSession accepts bounded server exports and passes them to an owned
durable vault. It does not run SaveCreature or synthesize BICs from replication.
Only saved metadata crosses to the renderer; opaque BICs remain in the backend.
Active effects and all unknown valid GFF fields remain byte-exact. SP's stricter
parseCharacter import policy is unchanged. Requests coalesce until persistence
finishes; timeout leaves the connection open and prevents a late reply from
satisfying a new request. A late genuine export can still be saved. Storage or
decode failures remain diagnosed; user-initiated unsaved disconnect is explicit.

Application-owned vault: immutable SHA256-named blobs plus atomic entry pointers,
with file sync before publication. Entry IDs are UUID storage keys, not canonical
OBJECT_IDs. Names never become paths. Previous blobs remain available, corrupted
files fail integrity checks and a failed entry commit retains the prior pointer.
Regular app storage is under its userData/network-characters; QA uses workspace
runtime-logs/network-character-vault. Neither writes the original install.
These vault IDs/version pointers are a replacement storage adapter, not a claim
to reproduce native filename helper1408013d0's collision suffixes. That native
helper strips non-alphanumerics, falls back to0, and finds an unused local resref.
Server-vault selection/admission and the separate43/1 download path remain open.

Multiplayer UI can select a saved entry or an explicit BIC file. Export Character
sends the native request; regular disconnect/window close wait for a durable
export before ending an admitted session. Failed save retains the connection;
Disconnect without saving permits an explicit escape. No default preset is
silently substituted for an exported character. Reconnect reads the selected
vault BIC, retaining its storage lineage while the server assigns new object IDs.

Validation:53 focused codec/vault/session/IPC checks and307 network regression
checks PASS, buildv2 PASS (existing bundle-size warning). Actual Chromium UI
fixture passes selection, duplicate-save guard, durable wait, failure retention,
stale session/refresh guards and text-safe names. Visual inspection caught a
horizontal overflow, corrected by shrinking form tracks and wrapping buttons.
The fixture waits for painted frames; the final image was visually inspected.
Native close timeout/crash/disconnection cannot guarantee an export from a
server that is already unavailable. No complete multiplayer acceptance claim.

## Installed-server export check

v131 used the ordinary inventory double-click handlers to equip the existing
Light Crossbow +3 (slot16) and99 Bolt +3 (slot8192). Authoritative inventory,
equipment and the held crossbow model agreed. Production export IPC sent70061f
and received a40494-byte valid BIC from the vanilla server. Its equipment
struct types and item fields retained those slots and stacks byte-exactly.

The ordinary quickbar/canvas Light self-cast sent native6/18 and received
native start/release feedback. Two exported Light memorization records changed
from Ready[1,1] to[0,1], with no local BIC generation or spell-slot mutation.
Export metadata stayed in one vault entry, with immutable pre/post blobs.
Normal window close saved the same post-cast digest again; the server recorded
the replacement leaving while the original player stayed connected.

The first QA window then closed during a pending renderer inspection. Its
once(close) listener had already been removed when the production save-before-
close listener retried close. No sealed v131 full report exists. Frozen passive
summary network-character-export-frozen-v131.json and the equipment/spell proof
files retain bounded evidence; they are not a full wire acceptance claim.
The harness now prevents repeated close until inspection, disconnect and report
publication finish. This changes only the owned QA harness; production retains
its save-before-close path. The already-disconnected orphan harness was stopped.

v132 rejoined by that vault entry, with no preset file selected. The server
assigned new item IDs (crossbow2147484668 ->2147484672, bolts2147484667 ->
2147484675), retained equipment slots16/8192 and all99bolts, and our held model
used the new canonical crossbow ID. The original character remained connected
at86/86HP. Re-export and normal close both succeeded. The sealed report has
104samples,38wire messages, two native export requests and final phase closed,
with no failure, sampleFailure or disconnectFailure. Its inventory screenshot
was visually inspected. Active original-client shared combat remains untested.

The re-export contains Light Ready[1,1]. This is not proof of preserving spent
slots across admission: the original server restores them on this path.
Read-only nwmain server implementation CNWSPlayer::LoadCreatureData1404bb450
reads spells with a restore flag, then, when that flag is zero, calls
CNWSCreatureStats::ReadySpellLevel1404123b0 for levels0..9 at1404bbe2a.
The helper resets spontaneous counts from rules and sets memorized records'
ready DWORD to1. The source of that loader flag is retained as its actual
server-state offsets; its configuration meaning has not been established.
This code plus the live export difference supports server-owned restoration,
not client-side refilling. The byte-exact pre-join vault blob still has[0,1].
Evidence: rea-character-rejoin-load-creature.json and
rea-character-rejoin-ready-spell-body.json. No new client spell policy was added.
