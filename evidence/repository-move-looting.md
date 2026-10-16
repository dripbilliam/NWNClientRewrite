# Repository transfer and placeable inventory disturbance

Target NWN:EE89.8193.37-17 x64 nwmain.exe, SHA256
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a.
The original install and Ghidra database remain unchanged.

## Original owners and integration

`src/repository_move.js` maps full AddRepositoryMoveActions140380090..380196,
AIActionRepositoryMove1403c9960..3ca886 excluding instrumentation, full decoded
InventoryMessage140455f50 dispatched to subtype9, and ClearAction13 through
its full original cancellation/shared tail. Action13 has OID/OID/BYTE/BYTE
parameters and no request area gate. Its lower AddAction result is ignored.

Execution preserves the controlled-familiar/ruleset and exact-one life gates,
ActivityManager2, client/DM lookup, direct possession and physical repository
identity, item/placeable/alternate-creature destinations and sources, nested
container rejection, cursed/master/PC handling, repository membership exact1,
same-repository movement, container close before transfer, original coordinates
and quantity capture, remove/add/restore ordering, raw nonzero AddItem success,
SetPossessor, BYTE page selection, GUI messages and encumbrance updates. No
distance or open-window gate is invented where this owner has none. Canonical
IDs are retained; UI inventory arrays are derived projections of native
equipment/repository IDs, including after rollback.

`repositoryMove` in item_repository.js maps full MoveItem14046ac90..46ad7b:
per-node canonical object-array lookup and exact identity, then CheckFit,
BYTE coordinate writes and no membership/possession change. Failure leaves
coordinates untouched. The decoded input does initial overflow before reads,
then OID/OID/BYTE/BYTE, overflow/underflow, repeated controlled-object lookup,
creature cast, canonical item lookup/cast, ActionManager2 and AddMove. Rejection
gets the message owner before sending RepositoryMoveCancel. Cancellation13
has its own optional cancel message before the shared lock/time cleanup; it
does not roll back a completed transfer.

ModuleSession now queues normal repository inputs bound to the original
controlled record; CombatRuntime dispatches/cancels action13 using concrete
repository, ownership, GUI and encumbrance owners.

## Installed failure and disturbance owner

Real chest transfer reached an unsupported placeable script-event27 delivery.
The creature-only gate had rejected it as noncreature perception. Original
placeable branch1404b3789..37b9 →3878 writes caller19c, GetInteger(0)→1b4,
GetObjectID(0)→1b0, then RunEventScript5(flag0). It does not call the creature
SetLastHostileActor owner. This now has its own live receiver. Placeable GFF
script import also reads OnInvDisturbed; original Load1404b5a1b..5a2c requests
that key. Creature ScriptDisturbed import remains separate.

Original ground pickup is a distinct owner: AddPickUpItemActions14037ff50 and
AIActionPickUpItem1403c67b0. Their decompiles were captured for later work; they
are NOT substitutes for container transfer and are not implemented here.
AddTakeItemActions1404ab2c0 and GuiContainerMessage140451810 are also separate.

## Validation and limits

Read-only `inspect-native-repository-move.py` executes778 original executor,
72 request,43 full subtype9 input,48 full cancellation and432 full cell-move
cases. A further72 cases execute the bounded placeable script27 branch with
integer/object getter and script-call boundaries captured. Total1,445 original
observations;6 comparison tests. Final captures repository-move-native-v4.txt
and native-repository-move-observations.json; repository-move-tests-v5.txt passes.
Early failed oracle v1 had fixture vtable/action-clock offsets wrong and a null
actor repository violating initialized-creature invariants. v2 corrected those;
v3 expanded branches/cell movement; v4 added bounded disturbance observations.
The first JS comparison needed the native rejection-path message-owner fetch;
it was added, not omitted from expected traces.

Installed `probe-installed-repository-move.mjs` passes player565, chest385 and
item386 using actual UseObject, pending-input drain, action13, scheduler,
repository and SetPossessor owners. It checks acquisition/module getters,
canonical identity, inventory projections and disturbance history. An in-memory
OnInvDisturbed marker replaces an originally empty callback and queries all
three disturbance getters through ordinary NWScript, storing their results
with real SetLocal owners. Authored module item callbacks remain active.
Invalid coordinates254/254 cause native AddItem's FindPosition fallback, not
failure. A real active UTI bag574 is filled with35 real lightweight1x1
nw_hen_bodpers UTI items with distinct native tags via ordinary CreateItemOnObject
and queued transfers. The genuinely full, unexpandable bag rejects the incoming
item; rollback restores the same ID, membership and coordinates and emits
cancel. The item is then returned to its authored chest/coordinates.

Final repository-move-installed-v7.txt/installed-repository-move-v1.json pass
with zero new error diagnostics; all24 initial load diagnostics retained,
including the pre-existing missing plc_w02 PWK. Earlier failures are preserved:
v1 searched an empty area; v2 expected a queued transfer to bypass the existing
UseObject500ms wait; v3 incorrectly expected invalid coordinates to force failure;
v4 overconstrained the filler template. v5 real transfer/full-bag pass; v6 adds
history assertions; v7 adds NCS callback validation. Startup/AI are disabled.

All1,700 tests pass, production build passes with the existing chunk warning,
and rendered wheel → UseObject → authored DestroyObject → delayed body bag /
pick / area-revisit regression passes. Logs: repository-move-full-tests-v1.txt,
repository-move-build-v1.txt, repository-move-body-bag-ui-v1.txt. All owned
processes are terminal. Preview sun in the render fixture is inspection setup.

Actual container-window presentation and drag/drop/take controls remain
unfinished, as do original client sender/packet serialization, primary GUI
owner login initialization, ground pickup, corpse equipment stripping, locks,
trap26 and other spell/combat/campaign gates. This checkpoint proves the native
transfer path and installed state/VM integration, not rendered looting or
campaign acceptance. The full goal remains ACTIVE.
