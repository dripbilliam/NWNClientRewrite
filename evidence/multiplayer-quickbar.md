# Multiplayer quickbar and item-use replication — 2026-10-18

Goal **ACTIVE / PROGRESS**. The vanilla server now supplies all36 shortcuts,
embedded item identities and use counts. The client offers three pages, function
keys, assignment wheels and drag-and-drop. Equipment shortcuts send original
requests and wait for replicated results. Spell/item-power/feat/skill activation,
container opening, complete icons, remaining presentation and original-client
concurrency are still required; this is not multiplayer completion.

## Original evidence

Read-only installed x64 NWN89.8193.37-17 nwmain SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`;
unchanged vanilla server SHA256
`98951511ae7d06a251355f12d4f3e4b96269a2414fa3058e641afd70098690f6`.
No original binary/process/project edits or proprietary asset copies.

- G/Q writer4edc50 and client7b4390 update existing item stack/property uses;
  their quickbar index/type bytes do not assign buttons. Native83d580/83ef60/
  83f190 retain canonical identities and WORD counters. The property costs and
  type branches are engine behavior, not particular item/spell implementations.
  `inspect-native-network-item-use-counts.py`:1728 full sender/reader/setter cases
  with formats0/1, missing lookups, property-index truncation and counter edges.
- Server4d9da0, client dispatcher79d980 and complete entry79db00 own30/1 full
  and30/2 single refreshes. Item entries include primary/secondary IDs plus the
  same appearance/active fields as inventory. Native current client has no type9
  branch; saved-character loader398b90 converts9→1. Unknown5/9/26 are explicit
  omissions rather than guessed payloads. `inspect-native-network-quickbar.py`:
  368 original sender/receiver cases, all supported current types. Synthetic item
  cases use absent item flags; actual embedded items are verified by live replay.
- Native UI notify8602a0 selects typed assignment emitters;7bee70 writes
  metamagic54 then domain55. Its ABI arguments5/6 are domain/meta in that order.
  Setter86b680/widget868e70 and server452030/4521d0 confirm the fields. Distinct
  values33/9 avoid mistaking argument position for wire order.
  `inspect-native-network-quickbar-requests.py`:216 complete original client
  packets through the original server reader and actual typed field setters for
  empty, integer, item, spell and spell-like buttons. GUI/network/control/spell
  lookup/allocator services are captured lower boundaries. DM/resource/associate
  and command18 layouts have static evidence only; native server case18 ignores
  the command request. No claim that those actions execute.
- Static active-item reader76bd30 reads available/changed masks, then only the
  changed use bytes, calling83ef60. A refreshed property initially has remaining1;
  only transmitted bits override it. Imports retain prior WORD counts, merge new
  bytes and initialize/update selected cast-property state. Sparse-merge tests
  are replacement regressions grounded in this source, not a full original
  active-item-reader execution oracle.
- Static item widget85bec0 opens containers first. Only equipable items with
  packed property WORD255 route through805500→7c0e20 (12/11), carrying the optional
  paired ID. Active baseitems supplies Container/EquipableSlots; other paths stay
  explicitly unsupported. Existing195 item-action and258 toggle native cases
  cover that packet/server behavior; full widget gameplay is not emulated here.

## Implementation and boundaries

NetworkWorld stages shortcut/items atomically, registers explicit server IDs
without allocating new ones, and preserves item identity/ownership. Q references
missing items are ignored as in the original. Shortcut layout is client GUI
state: the original changes its widget before sending and suppresses notification
during server refresh. This local layout change does not simulate gameplay.

Typed trusted-frame/session/area-generation IPC handles assignment/activation.
An assignment finishing in an old area cannot overwrite the new UI. No raw packet
API or local ModuleSession/AI/script/combat/spell resolver is exposed. Owned items
and existing server shortcut items are checked before assignment. Native item
configuration/count/wield helpers read the selected module's tables and replicated
numeric CanUseItem flag. Domain selection retains effective level minus active
ruleset metamagic cost, as the separately studied native spell menu does.

F1–F12, Shift/Ctrl pages, page buttons, right-click assignment menus, shortcut
moves and inventory drags use production handlers. Async reset/generation guards
discard stale work. Failed target assignment does not clear a drag source. Item
icons remain diagnosed; readable item names provide interim presentation. Native
qb_but66, spell/feat/skill icons and fonts are loaded through active resources.

## Live validation

All sessions could be cleared under the user's authorization. Only the owned
Prelude server profile was restarted; current server PID36824,127.0.0.1:5121.
Installed ranger.bic was sent unchanged. Offscreen GPU execution leaves the
desktop untouched; private inputs use one-use X25519/HKDF/AES-GCM loopback transfer
with credentials in memory, never files/environment/argv.

v44 confirmed pairing/drag/spell assignment but caught a page button retaining
the old displayed page. v45 completed all16 steps; it exposed a nonexistent
clear-slot icon reference. Both are retained as evidence. Finalv46 completes16
menu/key/drag steps,10 native assignment/equipment requests and2471 GPU frames,
finishes playing, then disconnects cleanly. Its runtime journal has **zero error
records**; unsupported presentation warnings remain visible. Screenshot inspected.

Actual server equipment: bow→sword+shield→unequipped→bow→inventory-dropped dagger.
Server G/Q updates explicitly reference newly assigned slots10/12/1 with their
canonical item IDs, proving those assignments reached the vanilla server. Full
replay consumes every object-update boundary. Spell assignment is verified by its
UI, native request and216-case original-server oracle; spell activation is not
yet connected. Final capture/replay assertions preserve relative IDs rather than
hardcoding allocation values. Native tests and an installed-table adapter check
protect singleplayer/shared item helpers and numeric wire flags.

Remaining: native cast/feat/skill/item-power request and targeting paths, ability
availability/count rendering, containers, complete item/dual icons, richer
quickbar actions/locking/key configuration, effects/audio and actual simultaneous
play with an original client. Unknown packets remain recorded.

Focused validation:51 tests PASS (`network-quickbar-tests-v13.txt`), production
build PASS (`network-quickbar-build-v7.txt`; existing size warning), harness/private
input syntax PASS. Credential audit2187 source/evidence/new-capture files,
private hits0. Failed intermediate checks remain available; only terminal passing
checks are counted. A full item refresh also overwrites a prior stack counter
with the server DWORD, while sparse property-use bytes retain unchanged WORDs.

Verified checkpoint `multiplayer-quickbar-20261018-v1.zip`:12864 files,
234369451 bytes. Writer38697 finished with terminal0; every entry length/SHA256
verified. Scope:41 required present, forbidden0. The initial broad scope check
flagged the intentionally retained read-only REA stderr log; its content was
separately checked for credentials (zero hits), and only that exact research log
is allowed. Server profiles, binaries and game assets are excluded. Scope and
postseal notes are outside the sealed archive.
