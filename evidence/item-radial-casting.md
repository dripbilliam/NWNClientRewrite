# Active item wheel and explicit hotbar casting

Target: NWN:EE `89.8193.37-17`, x64 executable SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original install and Ghidra project remain unchanged. Full original instructions
were captured and executed in isolated synthetic data/presentation fixtures.

## Original owners

CGuiItemMenu constructor1409a5940 references vtable140e761d8. Its initializer
1409a59d0 installs callbacks rather than overriding a large set of virtual
methods. Confirmed InitializeItemUseEntries1409a71a0 is truncated by Ghidra's
decompiler at free(NULL); complete unwind-bounded instructions are authoritative.
It installs item spell slots3,5,7, replacing7 with More when there are more than
three cast properties. The first page then contains two properties. More starts
at cast-property ordinal2, not physical property index2. Creator1409a6450 adds
seven properties per page and More at7, preserving physical indices in payloads.
Creator1409a5fe0 uses child spell icons/names and packs the selected variant in
the high WORD. Native nonvariant sentinel is255, not65535.

`item_radial.js` projects these three use-entry owners into the existing menu
presenter. It preserves property15 filtering, slot gaps, spell lookup failure,
icon-construction failure, readiness disabling, assignment differences, first
property70/55/80 trap/lock/heal entries, stack-rule warnings and Learn Scroll
eligibility. LearnScroll maps class INT4fc at1402a6b44. Unlimited costs7/13 show
`*`; other counts use the client's eight WORD cells. Common bases49/54/75/104
suppress their finite badge on the root, but not child/page entries. Local
authority derives that count from the shared native uses-left owner; no client
replication message or network packet is fabricated. The existing equipment,
drop/pickup/split/store menu owners are separate and remain visibly diagnosed
where unavailable. Learn Scroll's action itself is not implemented yet.

Selection callback1409a8530 separates quickbar configuration from activation.
Its targeter constructor1407037f0 and ActivateActionTarget1407039f0 are distinct
from ordinary prepared-spell targeting. `item_targeting.js` projects their
decoded targeting policy, nested spell setup140703ea0, creature veto140703d00,
confirmation140703860 and client UseItem wrapper140805740. The wheel supplies a
blank custom icon. Custom-icon allocation and native targeter lifetime ownership
are separate, and native targeting preview remains explicitly diagnosed.

The selected property's parent spell supplies metadata unless high WORD !=255
and it has children; then the child index narrows to BYTE. There is no implicit
first-child substitution. Auto-self uses active baseitems QBBehaviour BYTEad,
verified from loader14029ff0d..14029ff6d. Value2 or target mask1 follows global
auto-self. Mask9 suppresses auto-self while either inventory/container modal
flag is1. Mask5 does not inherit ordinary-spell auto-self behavior. Registration
keeps the native type/code pairs and duplicate creature5 registrations for masks
with both creature bits. Creature veto re-resolves selected metadata and current
controlled identity; other types use the registered mask. Active property55,
70 and80 register their own target families, not synthetic spell definitions.

Confirmation re-resolves an item target and its possessing creature before
choosing coordinates; other targets preserve the current targeter's vector.
Client UseItem140805740 sends property BYTE and arithmetic high-WORD argument.
Complete writer1407c0610 was also inspected: variant BYTE255 is omitted and the
server input9 decodes it as0. XYZ is present exactly when the FLOAT vector is
nonzero; scale is1.0 at140d8109c. Main's local decoded adapter preserves these
rules, canonical IDs and original actor/area, then queues the existing input9
handler. It does not claim transport serialization or multiplayer acceptance.

## Product connection and validation

Inventory right-click now includes the use entries, localized item title,
active property icons and use badges. Direct entries start the item targeter;
variant/page callbacks rebuild against current item/session/area. Inventory
targets retain the same pending selection. Explicit entries carry native type1
quickbar bindings with property/variant fields. DOM drag/drop reaches the shared
assignment owner, and click/F-key activation goes through item targeting/input9,
action46 and the authored impact script. The overlay stops intercepting drops
during a drag. Canonical inventory state drives quantity/charge refresh instead
of the immutable authored StackSize snapshot.

- `native-item-radial-observations.json`: 986 root,128 property page,96 variant
  executions. Actual original slots, labels, badges, packed payloads, disabling,
  warnings and learning entries are compared. Object/metadata/string/TLK/icon,
  allocation and menu-presentation providers are captured; native heap/GUI
  rendering and allocation exhaustion are not acceptance claims.
- `native-item-target-observations.json`: 654 activation,146 veto,16 confirmation,
  32 client-wrapper executions. Canonical lookup, metadata and lower UI/preview/
  transport providers are captured. Activation uses the wheel's blank-icon path;
  tests compare type registration, flags, point, selected metadata, auto-self,
  veto call order, final submission and cleanup ordering. 2,058 new original
  comparisons in total.
- `live-item-use-ui.json` / `item-use-ui-v3.txt`: unchanged installed wizard
  inventory, Prelude entry-position/startup-off fixture; native AI remains on.
  Real inventory wheel click and F2 keyboard inputs, DOM drag/drop of explicit
  property0/variant255 to type1 F2 binding0xff0000. Potion570/player565, stack
  3→2→1→removed. Three real animation70 events select/play the existing `drink`
  clip; destruction removes the shortcut. No console errors or new runtime
  failures. Known absent plc_w02.pwk is retained separately, not treated as a
  clean-world pass. Screenshots: live-item-use-wheel.png and hotbar.png.
  Healing from injury was separately verified through the actual authored
  potion script in installed-item-casting-v6.json; this UI character starts at
  full HP and heals0 as expected.
- First rendered attempt timed out because the test incorrectly expected an
  empty array. Native queue display retains ten sentinel records; the assertion
  now checks action/specialFFFF. Second run completed all item behavior, then
  caught the existing missing PWK. Its full report/screenshot is retained as
  live-item-use-ui-v2.json / item-use-ui-v2-failed.png. The final run retains that
  known error separately and rejects every new error.
- All1,610 automated tests pass; production build passes with its existing
  chunk-size warning. Prepared-spell inventory targeting regression also passes
  (item-use-prepared-regression-v1.txt): spellbook Light on equipment, F2 Greater
  Magic Weapon on a carried item, the prepared-spell item wheel, real slot
  consumption and right-click cancellation. Engine omissions are empty in that
  report. Electron emits a GPU shutdown message after successful assertions;
  the process exits0. This is not a clean-world or full campaign claim.

Default shortcuts from dragging the whole item still reach an explicit
ui.item-default-activation-unimplemented diagnostic. The full quickbar item
configuration/default-selection owner140867760 must be ported before replacing
that diagnostic. Scroll learning, full script ActionUseItem14050f190, rendered
scroll/wand/variant/daily-item acceptance and target/release/projectile previews
remain open. Script/resource audit remains88 unbound names/22 missing NCS from
v33. Spells, combat and continuous campaign completion remain unproven; goal
stays active.
