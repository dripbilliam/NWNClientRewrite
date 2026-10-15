# Quickbar assignment and scripted locking

Target NWN:EE89.8193.37-17 x64. Installed PE SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Read-only Ghidra and full unwind-bounded, hash-checked PE disassembly were used.
No game files or Ghidra annotations were changed. Active rules and canonical
object IDs drive the runtime; campaign tags occur only in regression fixtures.

## Native observations

- InitializeQuickbar `0x140396ab0` creates36 zeroed records, each0x60 bytes,
  owned by creature pointer field+0x4e0. GetQuickbarButton `0x140392f60`
  requires a nonnull array and index less than36. The replacement represents
  fields, not native process pointers or a network packet memory layout.
- SetQuickbarButton_Item `0x1403a3fe0` stores type1, primary/secondary canonical
  object IDs at+0/+4 and integer parameter+0x50. Spell setter `0x1403a4030`
  stores type2, multiclass INDEX byte+9, spell integer+0x50, metamagic byte+0x54
  and domain level byte+0x55. GeneralINT setter `0x1403a3f80` stores its type
  and integer; spell-like setter `0x1403a4090` uses type44. Unrelated fields
  survive setter calls. Clearing resets type/int without zeroing old item IDs.
- HandlePlayerToServerGuiQuickbar_SetButton `0x1404521d0..0x140452b95`
  resolves the player's controlled creature. Item decoding calls its setter
  at `0x140452380`; spell class/spell/metamagic/domain decoding checks GetSpell
  at `0x1404523fa`, then calls the spell setter at `0x140452424`.
  This establishes typed assignment payloads, not completion of network input.
- LoadQuickButtons `0x140398b90` reads QBList, capped at36 records. Item IDs are
  reconstructed through QBItemInvSlot or QBItemReposX/Y, optionally through a
  container at QBContReposX/Y. Secondary item fields use QBSecItem*. Property
  indices default0xff and are packed low/high16. QBMultiClass is a class index,
  not the classes.2da row ID. QBMetaType and QBDomainLevel are bytes. Saved
  type9 becomes item1; feat1000..1003 becomes65000..65003. Legacy special type10
  maps selected integer values to skill/feat entries and retains unmapped ones.
- SaveQuickButtons `0x1403a1da0` writes QBList using inventory/equipment
  coordinates for items. Persisting an item's current session ID as its saved
  identity would be incorrect. QuickbarButton_RemoveItem `0x14039bf80` scans
  all36 type1 entries and clears entries whose primary OR secondary item matches.
- Missing QBList invokes CreateDefaultQuickButtons `0x140389310` for PCs.
  Its complete automatic choice policy has not been ported; that path now
  records quickbar.defaults-unimplemented rather than inventing a default.
- The newly reported failure was SetLocked, engine324, in
  `m0q01a0bimelc1@0xd8`. ExecuteCommandSetLocked
  `0x140543580..0x1405436d4` resolves a valid object, writes the raw INT to
  door+0x424 (`0x140543627`) or placeable+0x378 (`0x14054364f`), creates a
  CScriptEvent (`0x14054366c`) with type28 for nonzero or29 for zero, and
  enqueues it at `0x1405436c2`. Event ID10 is verified from the referenced
  native constant. Caller is VM self; target is the canonical object ID.
  Enqueue occurs for valid objects even when no lock state was changed.
- Door EventHandler `0x14041e760` handles28 by storing last locker at+0x4a4
  and running script6;29 stores last unlocker+0x4a8 and runs script10.
  Installed NWScript event-context constants identify door10006/10010 and
  placeable9006/9011. Placeable callback indices use these API constants;
  placeable last-caller storage offsets were not independently established.

Raw evidence: `backups/animations/ghidra-quickbar-*.txt`,
`ghidra-locked-door-event.txt`, `native-setlocked-event-type.txt` and
`native-quickbar-lock-asm.txt`. Pseudocode cleanup truncation is resolved using
the latter full PE instruction capture where necessary.

## Implemented behavior and boundaries

The authoritative quickbar is the PC's36-record nativeQuickbar4e0 array.
Native QBList import/export, typed item/spell/skill/feat records, native legacy
conversion and item removal replace the previous selected-world-object bindings.
Inventory/equipment entries, spell lists and feats can be dragged to a slot.
Slots can be moved; right-click opens the existing radial presenter with active
items, class spells, feats, ranked skills, pagination and clear. Shift/Ctrl
temporarily select rows2/3. Native spell/feat icons load from active resources.

The category arrangement, pagination and HTML drag/drop presentation are local
UI decisions. Native client drag gesture details, all special assignment
categories, metamagic/domain choice editors, item icon composition and complete
original radial layout parity remain open. Stored domain/metamagic fields are
preserved; newly offered choices currently use domainLevel0.

Per-character IndexedDB stores a local QBList overlay separately from campaign
saves. Items resolve against newly imported live objects; source provenance
prevents a shortcut to unsaved loot silently binding a different imported item
at the same coordinates. This does not save acquired items or campaign progress.
Special associate references and server-authoritative layout synchronization
require their remaining owners.

Click/F-key activation emits the distinct typed request with canonical actor,
area, target, item IDs or class-index/spell/metamagic/domain fields. Existing
main UI item/spell/feat/skill execution adapters still report ui.action-unimplemented.
This pass validates assignment and request dispatch, not successful casting or
item use from the hotbar. Unsupported requests remain visible in diagnostics.

SetLocked now stores raw door/placeable state immediately and queues each native
lock/unlock event, including repeated unchanged states. Deferred callbacks expose
GetLastLocked/GetLastUnlocked and the correct script owner/event context.

## Validation

- 1298 tests and production build pass. New tests cover field ownership, bounds,
  independent36-record allocation, inventory/equipment/container identity
  restoration, roundtrips with changed IDs, legacy conversions, secondary-item
  removal, typed activation payloads, radial pagination and deferred lock events.
- `scripts/smoke-quickbar-lock.mjs` executes the original Prelude NCS resource
  that failed. Door state changes1 to0; deferred unlock records caller22. The
  installed wizard's36 saved quickbar records import/export. No script failures,
  engine-unimplemented records or session diagnostic errors occur in this scope.
- `scripts/smoke-quickbar-ui.cjs` drives an isolated Electron profile using the
  actual inventory/spell/feat UI. Item/spell/feat drag/drop, radial assignment,
  slot movement, both modifier rows, radial clearing, F2 typed spell dispatch,
  IndexedDB completion, full reload and same-character restoration pass.
  Native spell icons finish loading and no renderer errors occur.
  Captures: quickbar-assignment-ui.json/png/txt and
  quickbar-lock-installed-smoke.json under backups/animations.

The GUI fixture disables module startup to isolate assignment. It is not an
original-campaign playthrough, combat/casting acceptance test or multiplayer
compatibility claim. Existing unrelated omissions remain recorded.
