# Original native inventory equipment — partial UI parity

The Godot equipment area now uses `INV_EQUIP.gui`, original box models, their
distinct icon attachment points and original empty-slot icons. It replaces the
approximate coordinates and full-box item stretching. Item identities, slot
masks, membership, pending actions and outcomes remain server-authoritative.

The [outer-frame follow-up](NATIVE-INVENTORY-FRAME.md) adds original inventory/
container frames, backpack/page controls and per-pose artwork proportions.
Store framing, exact native hover polygons, counts, tooltips and fonts still
need work. This is not a complete inventory clone.

## Original evidence

Pinned original NWN EE89.8193.37-17 x64 SHA256:
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.

- Inventory constructor140854e60 loads `INV_PANEL`, attaches equipment and the
  10×6 repository to their original hooks, and chains six tabs through `next`.
- Equipment constructor140854c30 loads `INV_EQUIP` and imports fourteen tags
  from table140e4ffa0/stride40. The compiled table supplies slot flags, polygon
  names, empty-icon resrefs and icon dimensions. Positions come from active GUI
  offsets and MDL bounds/hooks; no server item/rule list is compiled into the port.
- GUI loader1401feba0/recursive1401ff120 and model loader1401feea0 read the native
  child list, model resrefs and relative placement. The GUI editor's root placement
  is not applied as an offset inside the equipment window.
- Sized icon constructor1401e2f60 and copy1401e3b00 select `GUI_ICON_%dX%dL` and
  replace `gui_replace01`. Godot prepares original private model resources and
  caches rasters by resource/clip/override identity.

Read-only function/assembly evidence is retained in
`backups/animations/rea-inventory-gui-layout-v1.json` and
`rea-inventory-equipment-icons-v1.json`. The fourteen recovered rows are in
`native-inventory-equipment-definitions-v1.json`. The offline native tool
`tools/inspect-native-inventory-resources.gd` produces source-hashed GUI/model
facts without a server or JS renderer. Its v3 receipt retains source hierarchy
and geometry. This is resource/decompilation evidence, not execution of the whole
original graphical client.

The original equipment extent is360×198 source pixels. Belt/glove icon sizes,
the lower-right amulet, armor label and distinct item centers now follow those
resources. Actual item icon dimensions are retained rather than stretched to
the full receiving box.

## Native ownership

`native_data/inventory_equipment_layout.gd` validates original hierarchy,
transforms, drawable bounds, GUI tags/offsets and icon/label hooks.
`native_inventory_equipment.gd` prepares resources asynchronously and retains
one original frame set across view rebuilds. `inventory_slot.gd` centers icons
while preserving existing view IDs, selection, item menus and typed drag/drop.
`native_ui_art.gd` and `native_item_icons.gd` include texture overrides in cache
identity and retain their stale-binding protections. Equal ring icons share a
raster; different same-size icons do not alias.

Creature slots still default off and are controlled only in Options. When enabled,
four targets append below the original equipment area. Sending an item request
never predicts a transfer. Native preparation/icon workers drain at retirement.

## Acceptance

Final debugger receipts have unchanged pinned native sources, normal heap,
four native exception traps, no caught exception and no script/lifetime errors:

| Receipt | Checks and scope |
| --- | --- |
| native-inventory-layout-final-v2 |23 original constructor-table/GUI/MDL/anchor checks, active offset propagation, malformed hierarchy/tag/resource rejection. |
| native-inventory-art-binding-final-v1 |8 deterministic native artwork binding/lifetime checks. |
| native-inventory-rules-regression-v2 |607 original-table icon selection/palette and authored item-routing checks. |
| native-inventory-playability-regression-v1 |1314 existing native gameplay/UI rules and routing checks. |
| native-inventory-equipment-ui-final-v1 |24 graphical checks: actual original models/icons/fonts, real pointer selection/right-click item menu, independent overrides, rebuilds, optional slots and worker cleanup. PNG inspected. Actions here use authored state. |
| native-inventory-radial-art-regression-v1 |32 graphical original radial resource/layout/input checks after the shared artwork-cache change. |

`native-inventory-equipment-actions-v1` separately passes67 real unchanged-server
checks on owned loopback5125. Its completed native snapshot confirms the new
14-slot skin is ready without artwork errors. Actual unequip/re-equip, merchant
purchase/charge/closure, casting, advancement, rendered attack facing, impacts
and cancellation pass. Native exit0; debugger armed/no exception; workers0;
public connections0. The known live scene wind warning and terrain wedges remain.
This is not an FPS benchmark or full mixed-client/UI/combat acceptance.

Failed receipts remain retained. Resource-v1 used a nonexistent byte-array hash
method. Layout-v1/v2 and graphical UI-v1 needed explicit Dictionary types; the
confirmed failed v2 headless probe was stopped and is not accepted as unchanged
source evidence. Layout-v3 contained two incorrect expected icon centers, corrected
from the original MDL hooks. Rules regression-v1 had607 passing assertions but an
old `passed`-only schema; the test now also reports `success`, with assertions intact.

The graphical probe uses the existing192-case `reports/native-item-icon-oracle-v1.json`
stock icon fixture. It does not prove every custom server layout. No original
process was modified. Graphical tests launch on the secondary monitor without
focus; editor, Prelude5121 and DensePerf5123 are preserved. The5125 wrapper owns
and cleans up only its test server.

Rollback: before `backups/native-client-presentation-hp-v1.zip`; after
`backups/native-inventory-equipment-v1.zip`. Read-back manifests retain digests
and individual source identities.
