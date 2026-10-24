# Native runtime synchronization messages — 2026-10-19

Previous goal turn was progress: native journal/player notices, GUI cue output,
original-code oracle, installed UI/audio validation, source checkpoint and live
v110 coexistence. This turn handles three remaining runtime message families;
the full multiplayer objective is unchanged and active.

Read-only target NWN:EE89.8193.37-17 nwmain SHA256
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a.
Original binary, Ghidra, server and original client are not modified. No assets
or credentials are copied into evidence.

## Evidence and behavior

- SendServerToPlayerDevice_EchoRequest1404d5ef0 writes DWORD length then
  WriteVOIDPtr1402dbc20 (one type15 marker + opaque bytes) as54/2. Main client
  router1407a41a0 reads DWORD/ReadVOIDPtr1402da400 and calls1407bbba0. That
  sender copies the same bytes into client54/3. Original server
  HandlePlayerToServerDevice140448710 minor3 reads them and dispatches
  CNWSPlayer::HandleEchoResponse1404baa90. The latter updates native timer/RTT
  fields1a4/1a8/1ac and smoothing state, not creature position or simulation.
  These are required responses; no local timer value or invented payload is sent.
- SendServerToPlayerSetTlkOverride1404e0210 writes INT STRREF + CExoString as
 52/2. SetTlkOverrideList1404e02e0 writes DWORD count and DWORD/string pairs as
 52/3. Client1407ab2f0 calls SetOverride14019a800 for each entry; it does not
 clear existing entries on a list message. SetOverride removes a key when string
 length is zero, otherwise inserts/replaces it. Native FetchInternal140198c60
 returns early for STRREF0xffffffff before looking at overrides. Other high
 uint32 keys remain valid override keys; gender does not select a separate map.
- Login_GetWaypoint1404dc140 sends empty2/12. Client1407a31b0 case12 obtains
 client internal478 via1406abe50. Empty value succeeds without sending anything.
 A nonempty configured value is cleared in client state before sender1407c21f0
 sends its CExoString as2/13. No waypoint is inferred from an OBJECT_ID, module
 name, character or area. Session constructor supports this one-use optional
 value; the current public connect UI does not expose it and uses native empty
 default behavior.

Bounded server sender scan only supplied candidates; containing procedures and
receiver/owner analysis established the above meanings. Misleading preliminary
evidence IDs (gui-disable/runtime-config/character-ready) retain their actual
native procedure names; do not infer semantics from those provisional filenames.

## Implementation

NativeMessageWriter/Reader now have opaque byte methods with the native type15
marker, growth and byte cursor semantics. The existing64MiB managed allocation
boundary remains explicit. Runtime decoders reject impossible lengths/counts,
truncation, residual fields and malformed framing before applying state.
Echoes are answered in NetworkGameSession during startup or play and are not
forwarded as opaque blobs to the renderer or retained as game objects. Counters
expose completed replies, waypoint requests and accepted override messages.
Normal peer/session lifecycle guards remain in force.

Connection-owned NetworkWorld.tlkOverrides applies records sequentially. Empty
lists change nothing, empty strings erase, duplicate keys preserve last update.
Backend talk-string requests and NetworkText honor overrides ahead of base-file
cache, retain invalid-STRREF early return and drop stale cached base results
when the override revision changes. Quickbar name cache and spellbook/panel/
party view signatures include that revision. Existing server-authored numbers,
spell IDs, slot counts, inventory, stats and active2DA rows are unchanged.
Received history already resolved to text remains history, not rewritten.
Tokens are still resolved by the existing original-derived client parser.

## Validation

54 original sender cases execute complete echo server/client, login waypoint
sender, TLK single/list writers, native scalar/string/opaque codecs and TLK
client2/3 parsing. Capture boundaries: transport, alloc/copy/free/profiling and
SetOverride application.12 echo-client cases also run the complete original
server device handler through captured HandleEchoResponse; all return1 and
pass exact bytes/length. Both format0 and1, zero/1/7/125/130/1024-byte payloads,
embedded NUL/high bytes, high STRREFs, empty/removal/repeated overrides and
optional waypoint text are covered. TLK client parsing is checked in format1;
legacy format0 single-update INT/DWORD type-tag mismatch is not normalized.
Unowned allocator/tail padding is excluded from byte comparisons.

49 focused tests and270 network regression tests PASS. Full buildv2 PASS with
existing bundle-size warning. Installed-resource muted HUD fixture verifies
server-controlled spell label/removal, canonical nonmutation and existing HUD,
spellbook, preparation, inventory, chat and journal/audio behavior. Runtime
fixture passes; its synthetic override is isolated and never sent to the server.
Captured startup packets from sealed v109 are replayed independently.

Current live v110/PID20748 remains the prior build alongside original33744 and
server20964. This source checkpoint precedes reconnect/live acceptance. Native
CC18/11 feedback (observed type71 armor-check/spell-failure notice) remains
unhandled and diagnosed; full feedback/attack/casting log presentation is next.
52/1 resource remapping,52/4 rule/cache reload and unsolicited54/3 reception are
not implemented by this pass. Shared combat/casting/transitions and broader
network audio remain outstanding; this is not full multiplayer completion.

## Post-checkpoint live acceptance

SEALED runtime-sync-v1 checkpoint:14807files/420009850bytes; writer27466
terminal0 consumed, every entry length/SHA256 verified. Independent audit
14808entries/106required/0missing/forbidden/duplicates/new credential candidates;
66changed/new text scanned. These post-seal notes/audit/acceptance are outside.
LIVE v111/PID46784 plays m0q1a alongside original33744 on server20964. Native
echo replies observed=15, login-waypoint requests1 (native empty default/no reply),
TLK override messages1(empty list), zero runtime errors/invalid packets/failed
objects. Only observed unhandled game packet now18/11. Screenshot visually
checked; both canonical players/party portraits persist. v110/PID20748 closed
normally; sealed local-network-system-notices-v110.json:268wire messages/final
phase closed. v111 full report unsealed; no further automated actions scheduled.
Native sender/router tests and installed UI cover nonempty opaque data and TLK
updates/removals; no live server mutation used for those checks. Goal ACTIVE.
Next: CC18/11 native typed feedback. network-cc-feedback71-followup-v1.json has
verified group140778098 (two INTs, no OBJECT_ID), templateCF82 armor/ASF notice.
Original dispatcher770c80 + jump tables77a6e8/77a65c and retained full assembly
client-cc-receiver-dispatch-v1.txt. Do not assume the server writer's generic
optional source-ID condition is a universal client shape. Full feedback/combat/
casting log, shared gameplay and network spatial audio remain incomplete.
Waypoint clear wrapper6acac0 was separately verified to set internal478; that
post-checkpoint REA evidence is in rea-startup-login-waypoint-clear.json.

