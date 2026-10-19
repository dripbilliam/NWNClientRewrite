# Creature death, corpse scheduling and equipped loot

Single-player progress on the ACTIVE spell/combat/campaign goal. This increment
connects the existing independently verified corpse and body-bag owners to actual
creature deaths. Complete combat, spell and campaign acceptance remains open.

Read-only target: NWN:EE89.8193.37-17 x64,
`../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
No original game assets, executable or Ghidra project were modified or copied.
REA dossiers and original-code observations are under `backups/animations/`.

## Native owners and integration

`item_copy.js` ports complete CNWSItem::CopyItem `140466910..140466e60`.
It rejects populated source repositories before changing the destination;
copies the native localized/string/scalar/appearance fields; replaces script
variables when requested; assigns only nonempty source property pools; and
appends fully copied effects with fresh effect IDs. It preserves destination
object identity. Native droppable/pickpocket/cursed/price-cache cells are not
copied. This selective copy is deliberately different from cloning an authored
UTI record. Existing empty source repositories are reconstructed with native
dimensions and expand0. The destination tag is removed/reinserted in module
lookup in original order.

`item_part_colors.js` ports complete get `14029dd60..14029dd83` and set
`1402a0ff0..1402a1065`. Six nullable channels each contain19 BYTEs. Missing
channels return255;255 does not allocate a missing channel. Source-null channels
leave existing destination colors intact during CopyItem. The item loader reads
typed `APart_%d_Col_%d` fields and native Hidden468; live canonical projections
retain names, appearance, descriptions and palette data even on copied objects
with no cloned authored record. Explicit nondefault per-part colors still report
an unimplemented rendering diagnostic; data preservation is not rendering parity.

Native `CopyScriptVars140491310..140491413` replaces destination variables.
Primitive/location/object-ID values use the shared local map. Structured JSON
and Cassowary ownership remains explicitly unsupported. Self-copy of a nonempty
effect array is rejected as a diagnosed original unbounded-growth domain.
Public NWScript CopyItem is still unbound: its wrapper
`140512600..1405128e5` has been researched, but container/creature/store placement
and failure paths require separate binding/validation.

The corpse transfer adapter now uses this internal copy for equipped gear.
Creature source description uses the native first-name localized value
(`GetFirstName140390b60..140390b78`), rather than concatenating first/last names.
Existing body-bag transfer/repository/gold/spatial owners are reused.

`lethal_damage.js` ports bounded creature branches of OnApplyDamage
`140429617..140429902` and world branch `140429c15..140429c95`. Lethal damage
constructs a fresh death19 payload instead of treating damage38 integer0 as the
spectacular-death flag. Signed SHORT HP, signed INT damage, truncating half-max
comparison and strict HP<-10 determine spectacular death. Ordinary creature
death uses the native blood-string visual selection; world death does not.

Complete OnRemoveTemporaryHitpoints `140438d60..1404391ad` uses repeated life
queries, signed temporary-HP subtraction and distinct dying/dead branches.
New death constructs19 with invalid creator and is deferred through event5;
it is not recursively applied before the temporary effect is erased. The dying
branch recomputes ambient animation, clears commandability, sends module event32
and closes panels through existing providers.

OnApplyDeath captures the cleanup flag at `14042acf8..14042ad1c` before
OnDeath/XP. Its tail `14042b2dc..14042b513` now invokes the existing native corpse
coordinator after effect purge. Spectacular death schedules3000ms and visual119;
ordinary corpses use unsigned decay; lootable bodies spawn a linked proxy bag.
Encounter active counts, possession/PC gates and cleanup event11 follow existing
native owners. Event11 `14038f07a..14038f220` transfers loot, removes the source
from area/spatial state and destroys its owned gear and canonical object. Bag
area insertion remains a separate event17 after exactly1000ms.

Rendered testing exposed a placeable-caused death failure during XP attribution.
ApplyDeathExperience `1403814d0..140381aa6` reads placeable creator at+3ac,
not an invented common trap field. The runtime now reads the shared live cell.
Initial placeable import reads typed DWORD TrapCreator/default INVALID at
`1404b4e9b..1404b4eba`, matching the complete runtime UTP loader. No-creator,
stale/full-width IDs and live ownership have focused regressions. Door/trigger
creator adapters remain separate open work; no default is fabricated for them.

## Independent validation

* `inspect-native-item-copy.py`:436 original CopyItem cases plus300 palette
  accessor cases PASS. Original instructions execute with captured lower
  allocation/string/localized/repository/variable/property/effect/visual owners.
  CopyEffect payload ownership is an independently checked lower boundary.
* `inspect-native-lethal-damage.py`:1593 original lethal branches plus272
  COMPLETE temporary-HP removal cases PASS. HP/cast/ambient/GUI/module/event and
  allocation boundaries are captured; construction, thresholds, metadata, blood
  selection, signed subtraction and call order execute original instructions.
* Existing corpse oracle:108 cleanup flags,432 schedules and3456 event11 cases.
  Those owners were already verified; this increment supplies real providers.
* `installed-creature-corpses-v3.json`:seven death paths PASS using installed
  Prelude, cleric, goblin, real OnDeath and active tables. Ordinary, spectacular,
  NoPermDeath, lootable, damage, massive damage and temporary-HP death verify
  exact delay-1/delay and999/1000 boundaries, canonical source lifetime, new bag
  and copied item IDs, gold17 transfer, localized description and player identity.
  Seven equipped PC-item copies also preserve properties/effect payloads with
  fresh effect IDs and independent palette arrays, without copying native flags
  or cache fields that the original excludes. Controlled fixture fields and
  isolated general AI are recorded; these are not campaign playthroughs.
* `installed-corpse-onhit-v2.json`:nine prior on-hit/lifecycle paths PASS,
  including level drain reaching death. All diagnostics are retained.
* Full suite1983/1983 PASS before the final placeable accessor/import regression.
  After that narrow fix,56 relevant tests PASS, including two new regressions;
  production build PASS. Logs `creature-corpse-full-v3.txt`,
  `creature-corpse-focused-v3.txt`, `creature-corpse-build-v4.txt`.
  The full suite is a checkpoint check, not repeated for each small edit.

`creature-corpse-ui-v4.txt` / `live-creature-corpse-ui.json` PASS in the bundled
Electron client: actual rendered radial Use executes authored in-memory NCS,
goblin24 plays kdbck/base8/animation220 with no clip failures, then its canonical
record/render/animation binding disappear. Dynamic bag577 has the same position,
is pickable through the actual radial, and persists after leaving/revisiting.
Death/bag PNGs were visually inspected. The existing preview sun is enabled;
lighting parity is not claimed. Process exited0; GPU shutdown text is retained.

The UI report retains unrelated errors: rejected DM vault import, missing
plc_w02 PWK and area-entry DoSinglePlayerAutoSave512. The focused corpse sequence
passes; this run is explicitly not an error-free campaign or autosave test.
First two UI attempts are retained: the actual placeable death path exposed the
unbound creator field, then the missing initial-import cell. Neither failure
was hidden by changing the fixture's effect creator.
The third attempt reached the death clip, removal, rendered bag and real bag
radial selection. Area revisit then exposed stale original creature placements
being rendered despite canonical destruction. Scene loading now filters these
placements through live canonical lifetime/area membership while preserving
their original source keys; it cannot renumber the surviving actors.

## Remaining gates

Loot GUI/pickup/save, general death preamble details, dominated/charmed/other
associate cleanup, ordinary damage dying presentation, PC death GUI, public
CopyItem placement and door/trigger XP creators still need work. Active spell
audit remains53 unbound commands/22 missing scripts at the previous checkpoint.
No assertion that the whole spell ecosystem, combat or campaign is flawless.

Verified checkpoint `backups/creature-corpses-20261017-v1.zip` contains10887 files,
156691250 bytes. Every archive length and SHA256 verified by the checkpoint
writer; log `creature-corpses-checkpoint-v1.txt`, terminal exit0. This verification
note was added after sealing. Goal remains ACTIVE; single-player first.
