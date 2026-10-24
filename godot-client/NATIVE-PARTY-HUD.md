# Native party HUD and player controls

Status: **party HUD core verified on the owned local server; full UI migration remains incomplete**.
The user's working order remains UI, rendering, then combat. No Arelith connection was used.

`systems/server_party.gd` presents the controlled player and received party members
in a scrolling right-hand rail. It uses the existing `networkPartyRows` model:
membership never creates proxies or transfers control; missing creatures remain
unavailable; health is the transmitted current + fieldE8 value, with undisclosed
HP left unknown. Original portraits use the existing resource/context decoder,
and all eight `GAME_HUD_ACTIONS` use installed up/hover/pressed button skins.
Map, inventory, journal, character sheet, spellbook, options and player-list
buttons open their existing native windows. Rest uses the original typed packet
sender; Level Up appears when the controlled player's replicated state allows it.

Right-clicking an available portrait opens the existing radial provider. A left
click selects that creature only while the original spell/script targeter is
active; an idle portrait click sends no movement or possession request. Native
controls submit private view/entry handles. The backend resolves the current
canonical creature and coordinates, checks membership and area ownership, and
rejects removed, replaced or retired owners. The eight skins and portraits are
cached per connection, with four bounded presentation jobs. HP updates preserve
pressed widgets; area changes preserve the HUD; reconnect retires its owners.

`systems/server_players.gd` adds a movable, position-persisted player-attitude
window. Received names/account/DM status are shown, and other-player rows expose
typed friendly/hostile controls through the existing `playerAttitude` sender.
Private row handles also check canonical player identity, target object ID,
controlled actor and area generation. Self-attitude controls are omitted.

## Verification

- `reports/native-party-local-v3.json`: **28 +29 live checks**, two distinct
  saved-character connections, six rendered/animated admissions and two A–B–A
  cycles. Actual native-server AddHenchman/RemoveHenchman records create and remove
  the companion card. Actual GUI portrait selection casts prepared Light on that
  companion; the server reports **2 →1 uses in each session**. Radial examination,
  all menu controls, Rest, MMB and WASD with windows open pass. Native row health,
  membership and controlled ID equal the reused authoritative model.
- All 24 installed HUD skin states and both original portraits load. The rendered
  second-session frame `native-party-local-v3-c3-party.png` was visually reviewed.
- Save/reconnect reads match the preceding exported BIC. Old HUD resources are
  released, retired backend jobs and final pending presentation jobs are zero,
  all six retired world-owner counts are zero, native exit is 0, no renderer or
  native script errors are recorded, and the connection is closed.
- `reports/party-ui-native-v3.json`: **18 authored native GUI checks**, including
  actual left/right portrait input, all eight HUD buttons, unknown HP, original
  image aspect area, HP/level updates without widget replacement, late callbacks,
  40-member scrolling, narrow viewport, distinct buff/lobby input regions,
  outside-click pass-through and resource retirement.
- `reports/native-party-node-regression-v2.log`: **61 tests pass**. These cover
  current and stale party/player handles, canonical positions, bounded pending
  jobs/retirement, protocol validation, required integration evidence, original
  party/command/Rest/attitude packet oracles and existing radial/target behavior.
  Read-only installed-resource access was required for two retained native oracles.
- `party-buff-ui-regression-v1` and `party-nui-ui-regression-v1`: **17 and15** native
  authored checks pass, with clean engine logs.

The fixture `GodotParty1` extends the hashed authored `GodotBuffs1` module, using
read-only installed script API signatures. Its SHA256 is
`99a0b1517dae3f3713c10bc3d97ef8a88e836d161279d98fb0596f7ab6fe1771`.
It attaches/removes the authored speaker with native script calls; it does not
inject party state into the client. `join-local.ps1 -PartySmoke` runs this check
against localhost port5121, after starting that module with the local-server
script. The launcher preserves unrelated games and the project editor.

Rejected evidence is retained. v1's test result was dispatched after normal
gameplay-command validation, so the harness timed out despite exercising the
controls. The result handler now precedes that validation and independent
acceptance prevents early native exit from promoting an incomplete party test.
v2 attempted portrait input while the preceding examination window could cover
it, before waiting for the newly added card's drawn layout. The probe now closes
that previous window, waits for a drawn frame, and requires a newly visible
server examination. Both rejected runs remain unaccepted.

## Remaining scope

Actual second-player friendly/hostile exchanges, broader associates/possession,
larger custom portrait catalogs, encouraged HUD states and exact original font,
layout and physical-device fidelity remain open. The authored attitude GUI and
native packet oracles do not prove a real two-player Godot exchange. Creation,
full native settings/workshop/protected-key editing, separate debug-window tabs,
audio and remaining gameplay-window/NUI branches are still pending. The existing
quickbar inspection/navigation row remains alongside the new HUD controls.

This was a functional UI test with the project editor preserved. Its displayed
FPS is **not** a clean benchmark or acceptance of sustained moving captured-world
performance. Rendering and combat migration remain separate unfinished work.
