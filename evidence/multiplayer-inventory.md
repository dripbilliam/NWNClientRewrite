# Native multiplayer inventory replication — 2026-10-18

Latest continuation: [native item actions](multiplayer-item-actions.md) adds
equipment/move/toggle/drop/pickup requests/results and grid/radial UI. The
window-only milestone below is retained as historical evidence.

Goal status: **ACTIVE / PROGRESS**. Inventory-window presentation and replicated
items now work against the unchanged owned vanilla server. Item mutation,
containers, complete inventory UI and concurrent original-client gameplay are
still required; this milestone does not complete inventory or multiplayer.

## Target and original-code evidence

Read-only installed `../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`, x64
89.8193.37-17, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Owned original nwserver SHA256
`98951511ae7d06a251355f12d4f3e4b96269a2414fa3058e641afd70098690f6`.
Existing REA session99283 reused. No native executable/project/live-process
changes, injection, or proprietary asset copies.

Client sender1407be110 writes BOOL open and raw client OBJECT_ID, p/13/1.
Sender1407be060 writes BYTE panel and BOOL primary, p/13/2. Dispatcher140458b90
routes major13 to server140451db0. The server reads/masks the client ID itself:
controlled ID or OBJECT_INVALID routes primary GUI; another ID routes alternate
GUI and SetOwner. SetOpen4be9a0, SetOwner4beab0, SetPanel4beb40 are distinct.
Current application guard exposes the controlled PC only, with session,
current-area generation, playing/ready and canonical-creature checks.

`scripts/inspect-native-network-inventory-window.py` executes both original
senders and the complete original server handler. Captured lower boundaries:
transport, controlled-object lookup and the three GUI mutators.35 cases cover
both scalar formats, owner namespaces, panel values, flags, absent actor/player
and truncated-input rejection. Native defined bits match production encoders.
Fixture: `native-network-inventory-window-observations.json`.

Client G dispatcher1407b3c90 selects repository7b4620 (R/r/A/B), container7b3790
(C/c), equipment7b3f30 (I/i), or character-sheet7b2740 (S). Item reader79fe30
reads canonical ID, appearance79fac0, then active properties76bd30. Existing
baseitems.2DA ModelType and selected build control appearance shape; installed
skills.2DA row count supplies native BYTE107 for the stats skill mask.
G has no per-record length; unknown M/Q owners still diagnose and stop at the
verified prefix. No scanning for a guessed next record boundary.

Character-sheet oracle `inspect-native-network-inventory-stats.py` executes the
complete original7b2740 handler on original scalar-writer packets,160 cases:
both formats, builds34/36.2/37.1/37.17, individual/combined masks, optional packed
combat fields/nodes, signed values, skills, feat lists and class fields. Object
lookup/casts, UI calls, combat constructors/list insertion/final setters are
explicit lower boundaries. Tests compare native scalar memory, node contents,
UI list calls, reader cursors and an independently read trailing marker.

Assembly at7b3234/3280/32d3/3320 establishes **postfix2 for every feat width
check**, including calls whose pseudocode omits the fourth argument. Counts
and IDs both gate at8193.37.2. The original skill flag mask ORs true flags and
does not clear on false; replicated storage preserves that behavior. Unproven
stat/combat fields retain offset names, not invented rule semantics.

## Application ownership and UI

Main-process typed window/panel IPC requires trusted dist main frame, current
session UUID and current area/controlled actor. No raw send API or local item
mutation. `NetworkWorld` imports native IDs into its existing canonical client
GameObjectArray; inventory items are nonspatial proxies. Separate native GUI
channels retain slots/grid coordinates/page/deltas. Equipment replacement and
repository moves update locations without inventing IDs. Import remains
transactional; type conflicts roll back both objects and GUI channels.
Alternate/store owner binding is retained as unknown and diagnosed, rather
than assigning the local actor by assumption.

Inventory button / I opens a presentation-only panel with installed names,
quantities, equipped and backpack lists. Closing/reopening sends native window
requests. Async work is generation-guarded; area/disconnect resets the view;
world pointer input is blocked while it is open. This is an initial list view,
not a claim of original icon/grid/drag/drop/examine/slot UI parity. Item action
buttons and local equipment mutation were not added.

## Real vanilla-server observations and verification

`local-network-renderer-v20.json`: hidden real Electron renderer/native server,
open then close via narrow preload request; join02:51:39/logout02:51:57.
The newly enabled replication returns one639-byte P/5/1 containing three G/I/A
and five G/R/A records. Complete decode of all eight items. Names, model parts,
colors, properties, native slot flags and grid coordinates come from the server.
No character-template inventory import or special module/item path.

`local-network-renderer-v21.json`: actual inventory toolbar button open, close,
reopen; join03:01:45/logout03:02:07. First and final rendered lists match all
eight native IDs, three equipped/five backpack. Closed interval is hidden.
Installed talk-table names resolved, no unresolved tokens. Same canonical PC
0xffffffff;40 registry proxies, unchanged9 tiles/19 scene bindings, no failed
scene objects.57 diagnostics, **0 errors / invalid packets / incomplete records /
inventory UI failures**; protocol/audio/equipment presentation gaps remain
observable. `local-network-renderer-v21-diagnostics.json` preserves that log.
No desktop focus or physical-pointer claim. All test peers logged out cleanly;
owned server PID48532 remains running on UDP5121.

57 focused tests PASS: `network-inventory-tests-v3.txt` (network request/session/
IPC/replication/dialog/door/scene/movement plus native SP inventory input/GUI).
Build PASS: `network-inventory-build-v4.txt`, existing large-chunk warning only.
Credential audit3085 files:0 full private-key hits,4 synthetic fixture keys
counted separately (`network-inventory-credential-audit-v1.txt`). New inventory
window/stats fixtures and sender candidate13 are checkpoint-allowlisted.

## Next work / open boundaries

Original server455f50 separates equip1, drop3, pickup5, unequip7, repositorymove9
under major12. Equip sender7c0d70 writes item ID, target creature ID, slot DWORD;
drop7c0c90 writes item ID and full XYZ. Server queues native actions and sends
cancel/result major12 responses to client79f150. Need original-code request
oracles, those response decoders, guarded UI equip/unequip/drag/drop, actual
server equipment changes and rejection cases. Container major25 handler451810
has target-open1/next2/previous3; normal placeable use must retain native
approach/locks/scripts. Do not bypass gameplay by directly changing server GUI
state. Additional item actions11/12/13, G/M/G/Q, alternate owner binding,
container open/close responses, icons/examine, hotbar and full stats presentation
remain open, followed by combat/casting/effects/audio/concurrent vanilla users.

Post-seal checkpoint: `backups/multiplayer-inventory-window-20261018-v1.zip`,
12227 files /204983130 bytes. Writer70321 exited0; every archived length and
SHA256 verified.31 selected required entries present; forbidden binaries/assets,
character/module files, private key configuration and server profile absent.
This checkpoint note was added after sealing.
