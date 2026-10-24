# Character export / reconnect gap — 2026-10-19

Status: native investigation; no character persistence implementation or new
request has been sent. Full multiplayer goal remains active. Live v130 is
passive in m0q1d and should stay open while persistence is implemented.

Observed v129->v130: server position was retained, while the harness re-uploaded
the original installed wizard BIC. HP45->77, preset backpack items got new IDs,
equipped crossbow and quest key were absent. The product multiplayer form also
uploads the file selected by the user; no export/latest-local-vault flow exists.
This is not proof of a vanilla server persistence failure. Do not overwrite
the installed preset, invent the missing key or serialize partial replication
into a replacement BIC. Server NPC/quest state was not reset.

Target read-only NWN:EE89.8193.37-17 nwmain SHA256
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a.
Evidence files use rea-character-export-* in backups/animations. The pinned
REA session91238 remains live. search_procedures is available through that
session's catalog and accepts pattern/mode literal or regex; avoid requesting
the enormous complete procedure inventory again. Input handler's complete
55537character view is retained in character-export-input-handler-view.

Verified static path:

- Client sender1407bfbe0 sets DL6/R8B31/R9D0/stack-length0 and calls1407c25c0
  at1407bfbf4. The bounded scan independently finds this call. Exact-function
  dossier character-export-client-sender-exact is the intended owner; the earlier
  request at7bfbd0 was inside the preceding function, not this sender.
- Server HandlePlayerToServerInputMessage1404531b0 case31 calls
  SendServerToPlayerModule_ExportReply at140455263. No body fields are read in
  this branch. Do not confuse it with module3 requests or CharacterDownload43.
- SendServerToPlayerModule_ExportReply1404dceb0 calls
  CNWSPlayer::PackCreatureIntoMessage1404bca90, then emits major3/minor10.
- PackCreatureIntoMessage calls authoritative SaveCreature, handles possessed
  familiar/associate ownership and barter cleanup, writes a BIC GFF, and packs
  first-name locstring, last-name locstring, DWORD byte length and opaque BIC.
  Local serialization/filesystem/allocators are boundaries for a future wire
  oracle; no complete SaveCreature port is required to receive this server blob.
- Client module dispatcher1407a4d30 case10 calls14079b1c0. That receiver reads
  the same two localized names, DWORD size and VOIDPtr, rejects read overflow/
  underflow, chooses LOCALVAULT or DMVAULT, calls filename helper1408013d0,
  writes the blob and updates the directory. A pending close flag5FC is cleared
  only after reply processing; this is relevant to disconnect sequencing.
- ExportPlayer14055f020 chooses server-vault SaveServerCharacter for player
  modes3/4, ignores mode2, otherwise uses the same export reply. Input31 has
  its own direct path. Native permissions/configuration must remain authoritative.
- CharacterDownload handler140444c70 is a different major43/minor1 path; do not
  use it merely because its name sounds appropriate for current-character export.

Next: inspect filename helper/callers and exact sender, build original-code
request/reply codec oracles with explicit BIC/file boundaries, then implement
bounded opaque BIC receipt, durable vault storage and a save-before-disconnect
flow that waits for persistence before closing. Preserve SP's stricter import
validation separately: parseCharacter currently rejects saved active effects;
multiplayer must not drop an otherwise valid server BIC for that reason.
CharacterVault currently hashes bytes as entry IDs, so latest-version/selection
lineage must be deliberate rather than guessing by current canonical object ID.
Rejoin using an actual server export and verify changed equipment/HP/items and
canonical ID reassignment alongside the untouched original client/server.
