# Native gameplay desktop

The direct multiplayer entry now owns the main in-game desktop in Godot.
This is a playability milestone, not complete original-client UI parity.
JavaScript UI implementations are read-only references. The transitional host
still handles raw protocol, login and typed command serialization; it does not
construct these menus, prepare their artwork or render them.

## User controls

| Control | Native action |
| --- | --- |
| C / I / B | Character record / inventory / spellbook |
| M / J | Area map / journal |
| O | Options |
| R | Request rest from the server |
| F1–F12 | Current shortcut page |
| Shift / Ctrl with F1–F12 | Second / third shortcut page |
| Right-click a creature, object or ground | Context radial menu |
| Drag a menu heading | Move it and raise it above other normal menus |
| Escape | Cancel targeting/radial, close a floating panel, then Main Menu |

Menus can coexist. Their positions persist. WASD remains active unless a text
field has focus; clicks outside menu rectangles can still move/interact. The
radial uses a separate high CanvasLayer and retains original physical root slots.
Its spell families descend to leaf choices. The spellbook also exposes family
choices for dragging onto shortcuts, including domain/metamagic context.

The right-side party HUD displays received membership, HP/temporary HP, original
portraits and action buttons. Character record skills/feats, spell preparation,
36 shortcut slots, effect icons, four journal categories, map exploration/pins,
player attitudes, inventory/containers, stores and a native level-up draft are
connected to native views. Party commands use original quick-chat/associate IDs.
The server owns outcomes, transfers, resources, level availability and acceptance.

The [equipment-area follow-up](NATIVE-INVENTORY-EQUIPMENT.md) now uses the
original INV_EQUIP GUI/MDL positions, box meshes, icon anchors and empty-slot
artwork. Real local-server transfers pass. The [outer-frame follow-up](NATIVE-INVENTORY-FRAME.md)
adds original inventory/container panels, repositories, tabs and natural button
pose sizes. Store frames and complete native window styling remain migration work.
The [native gold follow-up](NATIVE-INVENTORY-GOLD.md) adds original amount/drag
controls and real ground/container transfers, fixes the container-request actor
identity and displays the original barter rejection. Full player barter remains open.

Item Examine now formats disclosed properties through native active
subtype/cost/parameter tables and shows server-provided item facts. Dependent
tables load asynchronously without raising a different window. Headless original
resource/UI checks pass; actual local gameplay review is queued while the user
plays another game. See [Native item Examine details](NATIVE-EXAMINE-ITEMS.md).

Options → Graphics defaults particles **off**. An explicitly saved choice still
wins. The offline capture launcher also defaults off; use -EnableParticles to
opt in. Options → Interface contains the persistent creature-equipment toggle,
which defaults off and is absent from the inventory itself.

## Native owners

- systems/native_game_desktop.gd: menu lifetimes, projections, targeting,
  shortcut validation, radial branches and typed requests.
- systems/native_data/game_ui_rules.gd: received-state projections plus native
  original 2DA/TLK reads; no local prediction of server outcomes.
- systems/native_level_up.gd: seven native draft pages using original progression
  tables, feat prerequisites, domains/school, spells and companions. The server
  must confirm a proposal before the view completes.
- systems/native_ui_art.gd and native_item_icons.gd: original raster/GUI-model
  resources on bounded workers, native original up/hilite/down poses and cached
  Texture2D publication. Direct UI rasters invert original UV row order;
  portrait rectangles crop original padding. World texture conventions are unchanged.
- systems/server_*.gd: reusable native controls; draggable_panel.gd owns layout.
- systems/native_gameplay_ui.gd: chat/dialog/examine/inventory and desktop facade.
- native_session_world.gd: Main Menu, options, local-only functional probes.
- tools/native-session-host.cjs: raw party/quickbar/player/journal/pin state and
  scoped typed requests. Its import guard rejects JS rendering/UI preparation.

Map tiles use original SET ImageMap2D resources through CTL_ICON_AREAMAP,
original CTL_MAP_PIN poses and CTL_MAP_XMARKER. Exploration comes from received
server state. Preparation is asynchronous and cached; no browser map renderer runs.

## Verification

All automated connections in this increment were to 127.0.0.1:5121, running
original Prelude. No Arelith/public server connection was made.

- reports/native-desktop-prelude-v5.json: actual native entry, received record
  details and portrait, simultaneous panels, 36-slot HUD, 13 original map art
  bindings, 9 server exploration tiles, radial priority, WASD with menus open,
  and Craft Trap producing a real server conversation. The waypoint and WASD
  movements are separate checks; the test retains the first accepted distance
  before the second movement changes the character's location.
- Matching .native.json: success, finish acknowledgement and zero remaining workers.
- Native debugger: normal heap, four exception traps, armed, no trapped exception,
  no script/engine/lifetime errors and pinned runtime sources unchanged.
- reports/native-desktop-ui-v12.json: 41 graphical authored-state checks using
  installed original resources, including menu coexistence, original images,
  page rebuilding, spell/item/skill targeting, store stale-view guards and
  level-up proposal/rejection handling.
- reports/native-desktop-rules-v9.json: 15 projection/family/domain/metamagic checks.
- reports/native-particles-default-off-v3.json: 21 real-emitter/options checks.
- reports/native-desktop-text-regression-v2.json: 1,025 existing original TLK,
  token/RGB, chat/dialog/examine and lifetime checks with the native desktop present.
- The skill packet and raw-world transport suites pass 12 tests, including the
  existing 238-case original binary skill-writer/decoder oracle.

Earlier failed/partial runs remain retained. Prelude v1 rejected a real map
orientation format error; v2's menu checks passed but its test completion rule
incorrectly reapplied the first waypoint's distance bound after WASD. Text
regression v1's 1,025 checks passed, but the generic harness required success
instead of its older passed field; v2 reports both. None replaces final evidence.

## Follow-up native action milestone

The [native action and NUI milestone](NATIVE-PLAYABILITY-ACTIONS.md) supersedes
the earlier store/level-up/queue/NUI acceptance gaps below: it includes original
localhost purchases, accepted levels, native combat feedback/cancellation and
scripted menus through raw protocol messages. The evidence below remains the
historical desktop baseline.

## Remaining acceptance

[Native player barter](NATIVE-BARTER.md) now has original trade framing and
owned-server two-player item/gold exchange and refund checks in both roles.
Mixed original/replacement trade and wider edge cases remain unverified.
[Native merchant framing and confirmation](NATIVE-STORE-FRAME.md) now have
original-resource graphical input and real purchase/sale acceptance; original
identify/examine styling and wider merchant edge cases remain open.

Broader [direct-native character creation](NATIVE-CREATION.md) coverage, complete original window chrome, wider
class/feat/item variants, effects/animations and public-server transfers still
need migration or acceptance. Original assets/fonts and main inputs are verified,
but wider server/mod content and physical-device visual review remain necessary.
The follow-up action/NUI evidence above now includes real transactions and
server-accepted advancement through the native controls. This is not a clean FPS
benchmark or full-migration acceptance.

## Rollback

Before: backups/native-desktop-before-v1.zip and adjacent verified manifest.
After: backups/native-gameplay-desktop-after-v1.zip and adjacent verified manifest.
The checkpoints contain authored source only, not original executable/asset bytes
or private settings. Final evidence is indexed by
reports/native-gameplay-desktop-final-audit-v1.json.
