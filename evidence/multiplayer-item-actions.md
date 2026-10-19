# Native multiplayer item actions — 2026-10-18

Goal **ACTIVE / PROGRESS**. Equip/unequip, repository movement, server toggle,
success/cancellation results and their inventory UI are connected. Real vanilla
server cycles pass. Ground-item models/picking, held equipment, containers and
the remaining multiplayer acceptance requirements are still open.

## Original-code evidence

Same read-only x64 NWN89.8193.37-17 target as
[inventory replication](multiplayer-inventory.md), SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Owned vanilla server SHA256
`98951511ae7d06a251355f12d4f3e4b96269a2414fa3058e641afd70098690f6`.
REA session99283 reused; no original binary/project/process edits or asset copies.

Server455f50 receives major12 and queues native actions:

| Action | Client sender | Minor | Payload after envelope |
|---|---|---|---|
| Equip to slot | 7c0d70 | 1 | item ID, creature ID, DWORD slot |
| Drop | 7c0c90 | 3 | item ID, full FLOAT XYZ |
| Pick up | 7c0f60 | 5 | item ID, repository ID, BYTE X/Y |
| Unequip | 7c1100 | 7 | item ID, repository ID, BYTE X/Y |
| Repository move | 7c1030 | 9 | item ID, repository ID, BYTE X/Y |
| Equipment toggle/pair | 7c0e20 | 11 | item ID, BOOL second-present, optional second ID |

Create/write/get-message and native OBJECT_ID encoding remain original in the
oracles. Server reads strip the client namespace bit; no replacement IDs are
allocated. Drop adds native FLOAT0.1 to Z before AddDropItemActions. Equip checks
native base item slot flags and cursed/owner conditions. Alternate-owner routing
and action/cancel paths execute in the original handler.

`inspect-native-network-item-actions.py`:195 cases, both scalar formats,
native ID namespaces, slot/coordinate edges, absent item, bad cast/associate,
cursed ownership, invalid slot mask and failed action queue boundaries. Object,
rule and control lookups, feedback, queued actions and cancellation calls are
explicit captured lower boundaries. This does not emulate action execution.

`inspect-native-network-item-toggle.py`:258 original sender/full subtype11
cases. The original handler scans14 current equipment slots, performs pair
checks, then selects among18 slots for queued equip actions. First/second item,
wield type, current slot, allowed masks, absent ownership and optional pair IDs
are exercised. Lookups and queued actions are captured; original slot scans and
branching execute. The client now sends this native toggle for automatic
equip/unequip instead of selecting the first slot itself. Explicit slot dragging
still sends minor1, including the controlled creature ID as client8050d0 does.

Success/cancel writers4da470/510 (drop),4da5b0/660 (equip),4da7b0/850
(pickup),4da8f0/990 (move),4daae0/b80 (unequip) send major12 minors1..10.
Each writes server OBJECT_ID + BOOL alternate-GUI; equip adds DWORD slot.
`inspect-native-network-item-results.py`:240 original writer/full client79f150
reader cases; GUI/actor lookups captured, item lookup absent to avoid simulating
optimistic widgets. Every native read and underflow/overflow check executes.
Decoded results report operation/success/alternate/slot, without changing items.
G/P/A/U replication continues to own item/equipment state.

## Application/UI changes

Main-frame/session-owned typed `itemAction` IPC validates current area generation,
controlled PC and canonical item/location. No local CanUseItem, feat, cursed,
slot-fit, stack, action execution, AI or spell resolution. UI dimensions and
slot masks read the active module/HAK baseitems.2DA. Creature repository storage
10x36/boundary60 is the original constructor37a702..37a71b constant, not a
module-specific rule. Six6-row pages use native major13 panel requests.

Inventory has slot drop targets, positioned backpack items, quantities, page
buttons and native equip/unequip toggles. Right-click opens the existing shared
item radial; Use/equip and Drop submit typed requests. Unsupported activation,
examine, casting and split entries remain diagnosed. Pending widgets clear on
native results. Drag payloads are scoped to the current presentation token and
canonical owner; main process also rejects stale/foreign inputs. No optimistic
canonical mutations. This UI still uses text buttons, not original item icons,
skin or a full paper doll. Paired-item codec is verified but paired quickbar UI
is not implemented.

Original create dispatcher7b23e0 sends type6 to79fe30(param2=0), attaching an
existing inventory item to the current client area. Real server drop confirms
G/R/D, A/type6 **same ID**, then U/6 position/orientation without an item area
field. The port now reattaches that canonical proxy and clears inventory/held
bindings. P equipment appearance records mark held items nonspatial with their
creature owner. D appearance records can contain OBJECT_INVALID; they clear the
previous slot binding without registering an invalid item. A regression caught
and fixed that sentinel case before the final run.

## Real server verification

All runs use the unchanged wizard BIC and unchanged Prelude server; only QA input
selection names/indices are fixture-specific. Production has no spell/module/item
name checks. Hidden real Electron renderer, parsed native game messages, no
desktop focus or physical-pointer claim.

- v22: eight actions via real item double-click/drag events plus deliberately
  invalid equip-slot request. Native unequip/equip/equip/unequip/move/cancel/
  equip/unequip results; three equipped/five backpack at end, same IDs.72
  diagnostics,0 errors/incomplete or invalid packets.
- v23: original toggle works; drop exposes stale inventory area and the QA picker
  mistakenly chooses an NPC appearance item. Retained as a regression fixture,
  not counted as a successful pickup. No claim of a complete item cycle there.
- v24: early session closure after new owner projection hit native empty-slot
  sentinel IDs. Fixed and regression-tested; retained as failed evidence.
- v25: actual inventory item radial equip/unequip, explicit slot drag, backpack
  drag, radial drop, typed ground pickup. Six successful native results for one
  unchanged item ID; back to three equipped/five backpack; pending empty.
- v26: revised visible equipment/backpack layout, drag move, radial toggle twice,
  native page1/back0, radial drop and pickup. Five native success results, same
  item ID and final counts.67 diagnostics,0 errors/invalid/incomplete/inventory
  failures; one explicit ground-model-unimplemented diagnostic. Join03:35:32,
  logout03:36:13. `local-network-inventory-v26.png` visually inspected: both
  columns/grid fit, quantities/page controls visible, no private credentials.

Page switches retain cached item metadata in this capture; displayed page and
visible grid contents must be checked separately from cache length. A focused
v27 run measures actual rendered item nodes for page1/back0 rather than assuming
the server deletes all cached entries. It passes: five visible nodes, then zero
on page1 with all five cached, then the same five IDs visible on page0.
Join03:39:05/logout03:39:17;55 diagnostics,0 errors.

All integration peers log out, server PID48532 remains running on UDP5121.
71 focused tests PASS (`network-item-actions-tests-v10.txt`); build PASS
(`network-item-actions-build-v10.txt`, pre-existing chunk-size warning).
Harness syntax check PASS. Credential audit3128 source/root-note/network-evidence
files:0 full private-key hits,4 synthetic fixture keys counted separately
(`network-item-actions-credential-audit-v1.txt`). Native fixtures, sender12
candidate report and inspected screenshot26 are checkpoint allowlisted.

## Remaining acceptance

Ground-item models and physical world picking are absent and explicitly logged;
the pickup test uses the production narrow IPC against the exact dropped object.
Held weapon/shield models, robe overlay, camera/roof cutaway (dark occluding roof
visible in the capture), original icons/skins/paper doll, item activation/use,
examine/split, cross-page dragging, paired shortcuts, alternate GUI ownership,
container major25/open-close and G/M/Q still need work. Full combat/casting/
effects/audio plus actual concurrent original-client gameplay remain required.
Inventory operations passing does not complete the interoperability goal.

Post-seal checkpoint: `backups/multiplayer-item-actions-20261018-v1.zip`,12299
files /205917308 bytes. Writer56054 exited0 after verifying every archived length
and SHA256.41 selected required entries present; forbidden native binaries/game
assets, character/module files, license configuration and server profile absent.
Inspected renderer screenshot26 included. This note was added after sealing.
