# Container controls, live looting UI and GetIsOpen

Target NWN:EE89.8193.37-17 x64 nwmain.exe SHA256
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a.
Original installation and Ghidra database remain unchanged. Fixture module
substitution occurs only in memory; no proprietary asset/archive is saved here.

## Native container input and pages

`container_input.js` maps full decoded GuiContainerMessage140451810..451b27
and NextPage1404be8a0/PreviousPage1404bec00. Subtype1 reads requested OID and
checks overflow/underflow, closes the old item/placeable with the actual
controlled object's ID and flag0, then looks up the requested owner. Placeables
are accepted; an item requires a repository and direct possession by the
controlled object. A valid but denied item retains the prior owner ID. Failed
lookup or unsupported type clears it through the real owner setter. Unknown
subtypes return1. Page subtypes2/3 operate on primary retained container state.

Page helpers qualify only placeables with repositories. They clear PRIMARY LUO
listA0 before arithmetic, use BYTE dimensions/page count and preserve unsigned
next-page comparison and BYTE wrapping, including exceptional zero-page cases.
Previous page at a nonzero page does not divide. Canonical local client,
repository and GUI owners are used; no UI-owned container-ID registry exists.

The original-code oracle has146 full input and98 page cases, with two comparison
tests: inspect-native-container-input.py, native-container-input-observations.json,
container-input-native-v1.txt/container-input-tests-v1.txt.

Installed probe opens placeable16/player565 via actual UseObject, closes through
normal container input, verifies observer0/last-close caller565 while main
inventory stays open, fills its active repository through ordinary
CreateItemOnObject until real expansion5→10, and tests cache reset plus
next/next/previous wrapping and separate main-inventory closure. Filler count is
dynamic because the authored OnOpen script can create loot. Startup/AI disabled,
authored callbacks retained, all initial load diagnostics retained. Final
container-input-installed-v2.txt/installed-container-input-v1.json passes with
zero new errors. The first probe reached missing engine443 and is preserved.

## GetIsOpen443

The stock nw_o2_generallow callback required GetIsOpen. Full command140527490
first looks up the object, casts to door twice if available, otherwise casts
to placeable twice. Doors use GetOpenState1404207f0; placeables are open exactly
when common animation DWORDd8 equals75, not merely observerCount>0.

The door getter returns3 without changing cache when field498 is zero. Otherwise
animations22/50/51/72 update cached BYTE42c to0/1/2/3; other animations preserve
the cache. The query's cache mutation is implemented. Missing objects/other
types return0. The normal VM layer still owns argument errors; original wrapper
pop failure -639 and push failure -638 are captured, not silently accepted.

script_object_queries.js and ModuleSession now bind the shared owner without
module/script exceptions. inspect-native-is-open.py runs the full original
command and original door leaf for726 cases; is-open-native.test.js passes.
Native assembly/decompile and is-open-native-v1.txt/is-open-tests-v1.txt retain
the evidence. The installed authored callback now completes.

## Presentation and interaction

`container_ui.js` renders installed GUI inv_container and each referenced MDL
control/skin: pnl_container, native label/arrows/close/X, and inv_box_7x5.
container-ui-resources-v2.txt records layout metadata, bounds and hooks. Panel
bounds360×217 and grid232×166 come from actual models. Grid icon hook offset1px
and native seven columns yield33px pitch. Item rectangles use active baseitems
InvSlotWidth/Height and actual repository coordinates, not compacted list order.

The player contents view now uses canonical10×6 repository pages and the native
SetPanel input instead of the old six-column compacted list. Bag clicks submit
UseObject, page arrows submit native container input, and grid drag/drop submits
inventory subtype9/action13. Primary close uses the native container handler;
main inventory has its own status input. GUI messages and regular refresh read
canonical ownership after actions; there is no optimistic item movement. A
per-session UI drag nonce prevents stale payloads from applying to a new session
with reused object numbers; it is not a game OBJECT_ID or a wire field.

Acknowledging an already-visible inventory initially reopened the panel and
closed its active radial. Scroll-learning and default-item regressions caught
this; the acknowledgement now opens presentation only when no panel is visible.
The native state transition still completes normally.

## Rendered verification and remaining limits

smoke-live-container-ui.cjs builds an in-memory authored library fixture with
real installed armor/bag UTIs plus30 distinct-tag lightweight items. Native
repository expansion creates two pages. Actual world right-click Use opens the
window; original native arrows wrap both directions. Browser mouse gestures
initiate intercepted HTML drags; CDP delivers those captured payloads through
production listeners. Chest→player, player→bag, bag→player retain the same IDs;
native close controls leave/close the main inventory as appropriate. No direct
session hook or forged DataTransfer is used in the final test.

Final container-ui-live-v7.txt/live-container-ui.json/.png passes and the image
was visually inspected during implementation. All post-load diagnostics are
retained with zero new errors; the existing non-DM vault's dungeonmaster.bic
import rejection is retained in initial diagnostics. Preview sun is enabled for
inspection. v1 caught CSS custom-property assignment, corrected with
setProperty. v2 incorrectly classified equal-size fixture items by width/order;
fixture tags now identify them. v3 DOM drag wiring passed; v4 added actual browser
mouse initiation; v5 added tags/diagnostics, v6 added expanded-page arrows and
strict diagnostics, v7 verifies the acknowledgement fix. Failed images/logs are
retained.

All1,703 tests pass (container-ui-full-tests-v3.txt), production build passes
with existing chunk warning (container-ui-build-v6.txt). Rendered regressions
also pass: body-bag/wheel/NCS/revisit, spellbook/radial/hotbar/cast/counterspell,
scroll-learning/spellbook/duplicate/stack/destruction, and default-item hotbar
assignment/drink animation/consumption/shortcut cleanup. See container-ui-*
regression-v1/v2 logs; scroll/default v1 failed on the acknowledgement bug and
v2 passes. All owned processes are terminal.

Item icons, original global window anchoring, fonts/grid-origin/rendering parity
and original client sender/packet serialization remain unproven. The actual
presentation gap is logged as ui.inventory-presentation-approximate. Native
primary inventory owner login initialization remains unmapped; no invented
assignment is added. Main-inventory fallback closure can therefore still use
the retained constructor INVALID owner; native container CloseButton uses the
actual controlled caller and is verified. Alternate container presentation has
canonical-state support but lacks a rendered alternate-character acceptance test.
Ground pickup, default equipment/container hotbar activation, corpse equipment
stripping, lock/trap owners, other spell/combat and full campaign gates remain.
This is functional looting/UI integration, not complete native UI or game parity.
Full spell/combat/campaign goal ACTIVE.
