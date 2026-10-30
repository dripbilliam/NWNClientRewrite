# Native radial menu artwork and interaction

2026-10-27. Original-asset wheel presentation and scoped server actions are
implemented and locally verified. Full radial, UI and gameplay parity remain
open under [the migration goal](NATIVE-UI-COMBAT-MIGRATION-GOAL.md).

## What changed

The380px filled panel and88×72 rectangular caption buttons are replaced by
separate56px circular icon discs,32px original icons, use counts, the original
selection ring and a single outlined hover label. The scene remains visible
between discs. Icons attach to the active catalog's GUI_RA_MENU model hooks,
including its71px diagonal offsets and100px cardinal offsets. The original155px
screen margin replaces the previous192px margin.

The creature root center uses a64×100 cropped original portrait. Descending a
submenu replaces it with that category's icon; clicking the center restores the
previous menu and its portrait/category. Original character-record art now uses
IR_CHARSHEET. Native model/raster requests use the same current catalog as the
rest of the client; rendering and menu construction are native Godot. There is
no JS renderer, browser canvas or prepared image transfer in this path.

Eight-way gestures, keys1–8, Escape/Back, disabled choices, private drag payloads,
request/menu identity and layer100 remain. Clicking a sector between discs also
selects its action. A click outside the155px wheel closes it and remains available
to world movement. WASD handling is unchanged. Hover text ignores pointer events.

`native_ui_art.gd` now gives each target/property binding a generation. A delayed
image for an old menu cannot overwrite a newer cached or asynchronous image;
clearing a binding or freeing its target also retires that authority. Coalesced
reads keep separate listeners. Failed/completed bindings release their tokens.

## Original evidence

Read-only NWN EE89.8193.37-17 x64 SHA256
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a.

`../backups/animations/rea-native-radial-ui-layout-v1.json` retains projected
complete function bodies/assembly and provider identity:

- CRadialMenu constructor1401f7950 selects GUI_RA_MENU. The legacy radialmenu
  resource found during the initial audit is not this active model.
- BuildIcon1401f8400 creates GUI_RA_CIRCLE56, attaches it to the indexed radial
  hook and attaches the icon under it. Disabled icons receive alpha0.4.
- ActivateInternal1401f7f00 clamps placement using round(GUIScale×155), builds
  graphics and selects text attachment hooks according to native preferences.
- HandleMouseMoveCaptured1401f9640 and ShowMouseoverPreview1401fab80 attach the
  selection ring to the hovered icon's circle and expose its text.
- SetCenter1401f9ee0 attaches either the supplied model or a framed icon to the
  center hook. The original GUI_RA_PORTRAIT mesh measures64×100 at100px/unit.

`rea-native-radial-icon-model-v1.json` retains SetEntryx1401fa250 (constructs
CGuiIcon with zero format dimensions), GetIconModel1401e4310 and the virtual
CreateCopyIconModel1401e3b00 (selects GUI_ICON_0X0L). That original model's
icon plane spans−0.16..0.16 in X/Y:32px at100px/unit, matching the port's icon
footprint rather than scaling the raster to the entire56px disc.

`rea-native-radial-text-alignment-v1.json` retains FixAttachedText1401f8ba0.
The port currently uses the original submenu hooks with quadrant alignment and
viewport clipping; its text-edge adjustment is not the complete native nonlinear
preference-dependent rule.

Original installed model SHA256 values used in graphical verification:

| Resource | SHA256 |
| --- | --- |
| GUI_RA_MENU |a938304f3451304557122520add4613eeeb7751ce8065569dc6c8579128f9d8c|
| GUI_RA_CIRCLE56 |9477e2c09ab48f685a660795d8517a18d9973c050562f8ec86ca539563dc40e7|
| GUI_RA_CLEARRING |f61a4bd2401d63f675078e454058cb805d03d637c11765eaf0ec87b2ea4d91d4|

`native_data/radial_layout.gd` composes source hierarchy transforms and projects
the actual hook positions; missing/ambiguous hooks and invalid transforms are
explicit errors. A simple circular fallback keeps actions available while art
is pending or unavailable; diagnostics distinguish it from loaded original art.

## Acceptance receipts

All listed debugger receipts retain normal-heap exception traps, unchanged
source and no engine/lifetime errors. They prove the stated scope, not all UI.

| Run under reports/ | Coverage |
| --- | --- |
| native-radial-original-ui-final-v2 |33 graphical checks: original catalog/model art/hooks, circle dimensions and transparent corners, real circular clicks, hover ring/text, edge placement, stale menu drag authority and late/tall icon layout. Final PNG inspected. |
| native-radial-bindings-final-v4 |8 deterministic native asynchronous artwork ownership/cleanup checks. |
| native-radial-shortcut-final-v3 |14 actual Godot viewport drag/drop and private shortcut/icon identity checks. |
| native-radial-late-layout-final-v3 |90 GUI frames with tall delayed images/long captions; no unbounded minimum-size growth. |
| native-radial-playability-final-v4 |1314 existing native gameplay/UI rule regressions. |
| native-radial-server-actions-final-v3 |21 checks. Owned unchanged original server on loopback5125: real circular clicks examine an NPC, navigate class/level/spell menus and Back, restore the portrait, cast Light and consume exactly one server preparation. Native cast clocks/part and skin deformation are checked. Includes an inspected PNG over the actual local scene. |

No public server connections or original-process modification. The editor and
existing Prelude5121/DensePerf5123 servers are preserved. Graphical launches
use the secondary-screen helper and retain the no-focus flag. These are
functional/visual checks; no FPS improvement is claimed.

Failed receipts remain retained:

- Artwork-binding-v1 found a binding token retained after its target was freed;
  cleanup is fixed and covered by the final binding test.
- Original-ui-v1 passed numeric checks but its screenshot was rejected on visual
  review: the authored probe cleared icons for a replacement menu without
  rebinding them. The probe now performs the real rebinding path before capture.
- Server-actions-v1 called a nonexistent examination close method in the probe;
  it now uses the widget's actual reset API.
- Server-actions-v3 incorrectly compared private AtlasTexture wrapper identity.
  The corrected check requires the same shared original raster and crop.
- Server-actions-final-v1 and playability-final-v2 failed to compile because the
  new comparison needed an explicit bool type. The confirmed failed owned test
  was stopped; the editor was preserved. Final receipts compile and pass.

## Remaining parity work

The follow-up [native feat port](NATIVE-FEAT-RADIAL.md) fixes family/shortcut
variant packing, discarded availability/counters and mode routing, and adds the
core original Special Attacks tree. A local original-server Druid variant changes
shape and its new native body keeps walking across an original clip cycle.

Native submenu mini-icon previews, rubber-band pointer art, radial preference
modes/UI scaling and exact edge-text rules remain. The current action builders
also remain a partial native menu port: full context availability, emotes/skills,
broader special-attack acceptance, possession/party branches and original roles need
coverage. The existing self Rest/Inventory additions differ from the recovered
original root. Do not describe the wheel as a complete native-menu clone.

Other gameplay windows still need their original framing/layout and broader
authoritative action coverage. Shape/weapon/target/combat effects and paired
original-client timing acceptance remain separate; in particular the previously
recorded undisclosed-maximum-HP blood-effect failure is not resolved here.

That blood dependency has since been addressed in the
[private constructor follow-up](NATIVE-BLOOD-VISUALS.md#private-constructor-hp-follow-up).
It does not close the remaining radial/context or mixed-client acceptance gaps.
