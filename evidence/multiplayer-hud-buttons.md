# Multiplayer HUD button requests and replicated panels

Target: installed NWN:EE 89.8193.37-17. Original nwmain SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`;
nwserver SHA256
`98951511ae7d06a251355f12d4f3e4b96269a2414fa3058e641afd70098690f6`.
Original binaries and Ghidra project remain unchanged. REA static research
and synthetic original-code oracles use existing read-only inputs.

## Native observations

- Rest writer1407bffb0 calls transport7c25c0 with major6/minor13 and no
  payload. Server1404531b0 branch140454244 checks the controlled creature,
  commandability and existing rest activity before Rest(0,0). The client
  must not heal, ready spells or admit rest locally.
- Start/StopGuiTimingBar1403a5180/1403a5210 use sender1404da310:
  major48/minor1 BOOL active, followed only when active by DWORD duration
  in milliseconds and BYTE type. Client14079ecd0 ->14079ee50 resolves
  type6 to localized string0x1056d (Resting);1406fc2a0 converts duration
  to seconds. Reaching the end of the presentation bar does not complete
  server gameplay.
- Character writer1407bddd0 writes CHAR page then OBJECT_ID,21/1.
  Close caller1406f7e5f uses pageFF; tab caller1406f7ee3 sends the selected
  page. ComputeCharacterSheetUpdateRequired1404b9660 maps0 to general
  character fields,1 to skills and2 to feats. Existing native sheet update
  reader/store remains the authority for these fields.
- Journal server140456d30 subtypes28/10 and28/11 are empty open/close
  subscriptions. Opening sends a full update, closing clears queued updates.
  Sender1404db220 and client1407a1d30 implement28/9 BOOL present, BOOL full,
  INT count and WORD masks plus tag/changed fields. Fields1/2 title/description,
  4/8 date/time,10 state,20 priority,40 picture,80 completed;100 distinguishes
  notes,4000 removes,8000 supplies a whole entry. Client router1407a0c10
  also dispatches world notes1..5, quest add6/remove7/picture8 and notification12.
  Files rea-hud-* retain per-procedure assembly, ranges and pseudocode.
- PvP writer1407c31b0 resolves PLAYER_ID through1406ac110 to the player's
  controlled OBJECT_ID, then sends41/3 OBJECT_ID+BOOL. Server14045ad30
  validates/adopts the request. Client1407a7250 reads two DWORD player IDs,
  BOOL likes and BOOL clear; the second ID controls the displayed attitude.
  Difficulty/admin writer7c3260 and candidate41/1,2 operations are not bound.
- Native client1407b4f70 automap branch200 has a special representation:
  BOOLs[1,0] with DWORD count0 reveals EVERY tile. A nonempty list first
  clears every tile then sets the listed coordinates. [0,0] sends set/clear
  points; [0,1] sends a bitmap. Saved bounded client pseudocode in
  native-hud-client-automap-reader-v1.txt includes the complete branch.
  Prior retained REA evidence IDs expired; the saved view, not a newly
  successful REA retained-ID call, supports this observation.

## Implementation

network_hud_input.js, typed IPC, NetworkGameSession and NetworkFrontend bind
Rest (HUD, R and radial), character subscriptions/pages, journal subscription
and player attitudes. Existing controlled actor, area generation and canonical
target lookups reject stale requests. No canonical resources or reactions
are changed optimistically. Native packets remain the authority.

NetworkPanels projects the journal, character/skills/feats, map, player list
and options. Inventory and spellbook retain their existing typed owners.
NetworkMapView reuses installed MapUi artwork and verified native marker
projection through a private view model, with only transmitted exploration.
It normalizes replicated vector/yaw orientation forms and uses no local AI,
ModuleSession or new gameplay IDs. Source singleplayer map behavior remains.
NetworkTimingView shows native timing messages and waits for server stop;
it never restores spells, HP or uses. Server animation47 selected sitcrossps
during the live rest check through the existing animation path.

Options currently changes the real camera mode/wireframe and disconnects.
Player list supports server-bound Friendly/Hostile requests. These are
functional subsets, not an exhaustive native options/party/character UI.
Journal note editing, party invite/boot, full native layout, map zoom and an
explicit Escape-to-cancel-Rest binding are not implemented in this section.
Rejected candidate senders7c00f0/7bfe30/7c0860 are mouse release, action
animation and UseSkill respectively, not verified Rest cancellation.

## Verification and limitations

- inspect-native-hud-requests.py executes complete original Rest/sheet/PvP
  writers and real message scalar codec, with synthetic client-player lookup
  only. 25 cases match every transmitted bit, including signed pages and
  three canonical IDs. Oraclev1 short leaf range/v2 missing WriteCHAR were
  fixture errors; corrected v3 passes. No original game runtime was modified.
- 64 focused tests PASS (network-hud-buttons-focused-v4.txt), including
  journal full/delta/remove, timing nonmutation, all automap forms including
  empty reveal-all, session scope, player state/object updates, spellbook,
  quickbar drag, native map and existing singleplayer rest resources.
- Buildv5 PASS. Hidden installed-resource DOM fixture UIv6 PASS: eight
  native-art HUD dispatches, immediate Rest, subscribe/unsubscribe, actual
  character page0/1/2 and remembered reopen page, nine explored map tiles,
  camera/wireframe delegates, plus spellbook/domain/metamagic drag regression.
- Live v89 normally closed: actual empty70060d; server48/1 type6 duration17500
  then inactive; newly prepared AcidSplash424 ready0 ->ready1, physical count4
  unchanged. Rest actor47/sitcrossps and PNG inspected. Journal28/10 retrieves
  the actual Academy Training quest,28/11 closes. Zero runtime errors.
- v89 exposed missing Skills page requests and blank fully revealed map.
  Those failures are retained, not treated as successful acceptance. Corrected
  v90/buildv5 shows28 skill ranks, feats and all nine native tiles. Skills,
  Feats, map, options, player list and final spellbook PNGs visually inspected.
  Rolling sample snapshot freezes map/readiness; runtime prefix86 records,
  zero errors, no sampler failure. Compact acceptance JSON combines these
  bounded observations with v89 authoritative Rest/journal evidence.
- v90 remains open for the user; full report is only written on normal close
  and has not been claimed as sealed. Active stdout/stderr/control/live files
  are excluded from the checkpoint. Automated inputs ended after24 seconds.
- One player was present on the local server. No new concurrent original
  client or live remote-player PvP acceptance is claimed. Friendly/Hostile
  transport has original-code oracle and typed session coverage only.
  No claim that combat, multiplayer or every native UI subsystem is complete.

Evidence: backups/animations/network-hud-buttons-acceptance-v1.json,
local-network-hud-buttons-v89.json, network-hud-buttons-readiness-v90.json,
native-hud-request-observations.json and network-hud-buttons-replay-v1.json.
