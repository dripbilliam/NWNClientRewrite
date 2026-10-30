# Shared native menu framework

Accounts: [saved login profiles](NATIVE-LOGIN-PROFILES.md) pairs player names
with Windows-protected keys, using one shared native manager from Options,
Player Name and the browser header. Credentials resolve at connection time.

Browser update: [automatic list loading and header refresh](NATIVE-BROWSER-REFRESH.md)
loads the first permitted Internet list automatically and enforces a two-second
refresh cooldown in both the native UI and data service.

Navigation fix: [character Cancel and browser return](NATIVE-MULTIPLAYER-NAVIGATION.md)
keeps native frontend ownership through disconnect and prevents retired lobby
fallbacks. Cancel returns to the native server list on the last active tab.

Game-value formatting: [whole-number display policy](NATIVE-GAME-NUMBER-DISPLAY.md)
fixes remaining JSON-float displays while retaining diagnostic and authored-text
precision. Its receipts cover the changed formatting paths, not full UI parity.

Follow-up: [server-browser responsiveness](NATIVE-BROWSER-RESPONSIVENESS.md)
retains original list rows/labels, updates changed records, skips duplicate views
and hidden fallback work, and formats JSON integer fields without `.0` suffixes.

This consolidates native UI construction and presentation. Controllers still
own their particular game rules, request signals and authoritative state.
It does not complete missing gameplay or certify the entire UI parity goal.

Startup follow-up: ordinary launches now receive `main-menu-open` instead of
the host's unconditional `browser-open`. The native owner hides lobby/browser
controls and presents the original Main Menu. Browser admission remains behind
the Multiplayer action; explicit owned local diagnostic harnesses retain their
browser entry. The complete launcher check `native-main-menu-startup-v2` observes
the ready main menu with both other surfaces hidden, then checks its existing
Options/Multiplayer routes. It exits cleanly with zero public connections.
The earlier `native-menu-framework-` receipts below precede this two-file
startup routing follow-up; they are not fresh whole-source receipts for it.

## Where to make changes

| Concern | Shared owner |
| --- | --- |
| Construct standard controls or a whole definition tree | `systems/native_menu_builder.gd` |
| Define a flexible menu's contents | `systems/native_data/menu_definition.gd`, `client_options_layout.gd`, `game_options_layout.gd` |
| Window title, close, drag, saved position and bounds | `systems/draggable_panel.gd` |
| Colors, fonts, original button/check/arrow/close images and picker variants | `systems/native_client_menu_style.gd` |
| Original GUI buttons, labels, edits, animated bounds and captions | `systems/native_gui_painter.gd` |
| Original GUI-model bounds and hooks | `systems/native_data/gui_model_geometry.gd` |
| A screen's network requests, pending operations and received state | Its existing controller |

Both Client Options and Game Options are constructed by the same
`MenuBuilder.build(content, definition)` entry point. The returned ID map binds
the controller's existing fields to the generated controls. The controller then
connects its action signals and supplies values. Definitions contain no file,
network or gameplay operations. Invalid kinds, duplicate IDs and unsupported
properties are rejected before a definition publishes any controls.

Original replicated menus keep their active catalog's GUI/MDL definitions and
source geometry. The same builder supplies their controls through the painter's
`create_button`, `create_label` and `create_edit` helpers. Existing controls can
still be decorated by `button` and `label`; this preserves specialized widgets
such as draggable inventory slots, scrollbars, portrait previews and map pins.
The original layout-specific parsers remain responsible for their source hooks.

The shared painter now extends Node directly. Inventory extends the painter,
adding its repository, container, equipment and expandable footer behavior.
The dependency previously ran in the opposite direction: unrelated menus
inherited the inventory implementation merely to paint a button. Source-model
geometry is also independent of equipment policy; the older equipment layout
entry point delegates to that common geometry implementation.

Native menus using the helpers include entry/Options/Multiplayer, original
character selection and record pages, connection/profile/password/confirmation
dialogs, key/video settings, examination, gold transfer, character-sheet,
spellbook, journal, player and trade controls. Source-specific actions, capture
revisions, cancellation and server acknowledgments stay with their owners.

## Theme and window lifetime

The active style publishes one tree-scoped Theme and updates registered
draggable windows. A window created later inherits that Theme immediately;
there is no requirement to subscribe each window separately. Closing the style
owner retires its publication. Original transparent panel overrides and their
authored close-button geometry are preserved during theme changes.

The retained experimental character picker has a distinct appearance and
immediate construction. It is now off in normal launches following the user's
request to restore the original-style chooser. Its controls use the common constructor; its primary,
ordinary, selected-row and unselected-row styles are named variants in the
shared style owner. Roster updates choose a variant instead of allocating four
new style boxes for every character on every update.

## Extending a menu

For a flexible menu, use the definition helpers to describe rows, columns,
tabs, labels, buttons, checks, choices, progress and scrolling regions. Give
controls stable IDs when the controller needs to update them. Construct once,
connect actions once, then update the same instances from received state.

For an original replicated menu, keep its source layout parser. Pass each
parsed entry to the painter's common helpers, or decorate a specialized existing
control. Preserve source dimensions and font metrics. Connect its signals to
the owning controller; the builder must not send game requests or predict
server outcomes.

Specialized content still has dedicated code. An item grid, world map or
three-dimensional portrait is not represented as a generic list of buttons.
Server-authored NUI retains its own schema interpreter and event semantics;
this refactor does not reinterpret it as an original GUI layout. Those are
intentional extensions of the shared controls, not a promise of one universal
function containing every screen's behavior.

## Verification

Current local native receipts use the `native-menu-framework-` prefix in
`reports/`. They cover definition publication/instance separation, preference
persistence, theme propagation to existing and late windows, source-frame
override preservation, and actual native input on the migrated menu routes.
The debugger wrapper checks source hashes, native exceptions, engine errors
and resource lifetime. Final accepted receipts are recorded by
`tools/audit-native-menu-framework.mjs`.

No public server connection or performance benchmark is part of this change.
Network-facing menu checks use authored replies and inspect the real typed
request signals. Earlier connected-server gameplay evidence remains a separate
scope. The broader parity goal, including unported original actions, is open.

Intermediate failures are retained: the first framework test incorrectly used
a script-resource method as a static call; a broader legacy settings fixture
loaded an unused complete protocol client and leaked that dependency graph at
exit. The fixture now omits that unused import and reports both its legacy
`passed` field and the wrapper's standard `success` field. Its 21 original
interaction checks remain intact. These failed runs are not acceptance evidence.

The desktop follow-up also found a real off-tree construction path: the store
calls window configuration before adding the window to its parent. Shared
styling now uses the base Theme off-tree and applies the active published Theme
on attachment. The actual late-window/style test covers this order. The broader
desktop fixture now chooses self-compatible cantrips and item powers from the
installed tables for its self-click scenarios; its older hardcoded selections
were rejected by current targeting validation. Gameplay targeting rules were
not loosened. A test invocation missing its required retained chooser oracle
was rerun with that oracle; it is not accepted as an executed test.
