# World radial menus

Target: NWN:EE `89.8193.37-17`, executable SHA-256 `3B7CB1252E0EDB2CE22D7971F333AADE027039AE30A45B4BC64732C3E6BEC73A`. Sources: existing executable, read-only live Ghidra decompilation/disassembly, installed GUI models/icons and English `dialog.tlk`. No binary, assets or Ghidra database were changed. Transcripts and renderer captures are under ignored `backups/animations/`.

## Observed native entry and door behavior

`FUN_1406f10e0` dispatches world right-button input after `CGuiMan::HandleRMouseDown` (`0x1401f58b0`, call `0x1406f1106`). Picker `FUN_1406eae20` receives right-button mode at `0x1406f11be`; the target ID is retained at `0x1406f124e`, and object virtual slot `+0x148` is called at `0x1406f1257`. Ground fallback calls `FUN_14084def0` with the hit position. PE vtable entry `0x140e530b0` connects the door slot to factory `FUN_14086d9e0`; it constructs through `FUN_1409b0060`, then builds through `FUN_1409b00e0`.

Door root entries observed in `FUN_1409b00e0`:

| Slot / direction | Action | Icon | Callback / creator |
| --- | --- | --- | --- |
| 0 / N | Examine | IR_EXAMINE | `1409b05e0` |
| 1 / NE | Cast | IR_CAST | lazy `1409b04f0`, argument 1 |
| 2 / E | Open or Close | IR_OPEN | `1409b0670` |
| 3 / SE | Trap | IR_TRAP | lazy `1409b04f0`, argument 2 |
| 4 / S | empty | — | — |
| 5 / SW | Bash | IR_BASH | `1409b05b0` |
| 6 / W | conditional Lock / Unlock | IR_LOCK / IR_PICKLOCK | `1409b0610` / `1409b0640` |
| 7 / NW | permission-dependent DM override | conditional | `1409b06a0` |

Slot 2 registers at `0x1409b031e`. Its callback re-resolves the target at `0x1409b0684`, then tail-calls `FUN_14086e810` at `0x1409b0695`. That helper sends open/close action words based on current state, bypassing normal-click linked traversal described in [door click evidence](door-click-gameplay.md). Close uses the same hand icon as Open. Cast/Trap/Bash/Lock disable while open; animation ID `0x48` disables slots 1–7. Trap also checks trap/skill fields; Bash checks an actor flag. Locked/lockable meanings of client `+0x184/+0x188` are inferred from icon/tooltip branches pending replication setters. English TLK verifies Open `0x2e8`, Close `0x5ba`, Lock `0x3b3`, Unlock `0x3b4`.

## Observed shared lifecycle and input

- Constructor `0x1401f7950` creates eight entry arrays and uses `GUI_RA_MENU`. String-label `SetEntryx` (`0x1401fa250`) stores receiver/callback at `+0x138/+0x140 + slot*16`, argument at `+0x1b8 + slot*8`, and icon at `+0x6e0 + slot*8`. Numeric-tooltip overload `0x1401fa3a0` is verified through callers; its decompilation is incomplete.
- `CreateSubMenu` (`0x1401f8960`) invokes lazy creators and retains children. `DisableEntry` (`0x1401f8b30`) sets flag bit 1; `HandleMenuAction` (`0x1401f9350`) checks it before choosing a child or invoking a callback.
- `Activate` (`0x1401f7e80`) / `ActivateInternal` (`0x1401f7f00`) clamp to scaled 155-pixel margins, build entries/previews, capture the mouse and establish modal ownership. Configurable centering, button mirroring and cursor warping also exist.
- `HandleMouseMoveCaptured` (`0x1401f9640`, atan2 call `0x1401f9687`) calculates pointer-minus-center and scale-normalized rounded radius squared. Boundaries 400/3136/22500/90000 yield center/cancel/select/submenu/exit bands at radii 20/56/150/300. Installed `GUI_RA_MENU` hooks independently confirm N, NE, E, SE, S, SW, W, NW slot order.
- Right up `0x1401f9b10` latches click mode after an unmoved center release or commits a selection; right down `0x1401f9ad0`, left handlers `0x1401f9270/1401f9300`, keyboard `0x1401f90e0`, Escape `0x1401f9620` and timer `0x1401f9010` handle subsequent selection/back/cancel/hover.
- `BuildIcon` (`0x1401f8400`) uses `GUI_RA_CIRCLE56`; `LoadGraphics` (`0x1401f9cd0`) handles entries/previews. Installed icons are TGA resources. `Deactivate` (`0x1401f8a00`) hides previews, releases capture/modal ownership and cleans up the tree.

## Observed other builders

- Creature role dispatcher `0x14098e550` selects self (`0x14098ec00`), owned associate, external creature (`0x140993790`) or DM variants. Self exposes Character Sheet, Cast, Attack/Disengage, Special Attacks, contextual slot 4, Issue Command, Special Abilities and Emote. `IR_SKILLSELF` tooltip `0x2050` is Cancel Polymorph. External creatures expose Examine, Cast, Attack/Disengage, Special Attacks, conditional Animal Empathy/Pick Pocket, Special Abilities and Talk; corpse, party and barter cases differ.
- Emote creator `0x140990fa0` calls `0x140994130`; successive pages are `0x140991fe0` and `0x140991010`. Their 21 leaves include Bow/Greet/Cheer, Nod/Look Far/Scratch Head, and Read/Drink/Meditate/Worship/Sit/Fall. First two pages use slot 7 for More Emotes. Cheer variants share a label/icon. PE tables `0x141297500/0x140e46cf0` plus English TLK independently confirm labels.
- Issue Command creator `0x1409914b0` calls `0x1409945d0`: slots 2 Attack Nearest, 3 Follow, 4 Stand Ground, 5 Guard, 6 Heal Me. Other slots depend on associate count/identity/context, including inventory/trap/unlock requests.
- Placeables `0x1409b19d0` use Examine/Cast/Use/Trap/Bash/Lock with gates. Items `0x1409a59d0` and `0x1409a7ee0` branch on ownership, equipment, stack and merchant state. Quickbar `0x1409ab4d0` belongs to a separate UI workflow.
- Ground `0x14084def0` stores hit position and creates slots 1 Cast, 2 Move To (`IR_MOVETO`, callback `0x14084f5e0`), 3 More Actions (`IR_TILEACTION`, TLK `0x10520`), 6 Special Abilities; DM Jump/Jump All require permission.

## Replacement and open work

`radial_menu.js` implements eight-slot modal presentation, hold/drag/release and click-latched input, lazy children, center/back, Escape/outside cancellation, scaled positioning, disabled entries, keyboard selection and installed icons with label fallbacks. Browser cursor warping is unavailable, so an unmoved opening gesture latches click mode even when clamped. Hover delay is an approximate 150 ms; native timer units/configuration remain unverified. Labels are always visible rather than configurable previews.

`radial_actions.js` supplies door/placeable/creature/player/associate/item/ground families. Known flags gate entries; emote pages use observed slots. Spells/feats/abilities accept paginated actor data and show an explicit placeholder when unavailable. Unimplemented leaves emit `[Radial placeholder]` console requests with action, actor/target/area IDs, subsystem and hit position, plus HUD feedback. Item/associate providers await actual inventory/ownership loading.

Door Open/Close re-resolves state at selection and enters an explicit shared queue intent. Approach, arrival-time validation, events, animation and collision are shared with ordinary use. Linked doors close from the radial while default use still requests unsupported traversal. Open doors retain a bounded closed-DWK interaction region when their leaf disappears into a wall; nearer scenery still occludes it. This approximates native hit tests/priorities. The player capsule is right-click selectable while default use picking skips it.

The HUD Player actions button provides self-menu access when scenery occludes the capsule. This is a replacement convenience pending the native character/portrait UI.

**Open:** exact skill/faction/party/possession gates, complete merchant/DM/quickbar workflows, learned spell/feat trees from character rules, trap/key/inventory/combat/conversation/examination systems, associates, polymorph and emote animation selection. Ground Move To remains a logged placeholder despite existing object-use route planning. This is the shared world interaction foundation, not a complete native GUI or gameplay reimplementation.

## Validation

- `npm test`: 54 passing tests covering all providers, compass/bands, lazy pagination, native emote pages, ground slots, structured placeholders, explicit linked Close, player picking and open-door occlusion.
- `npm run build`: passes; existing large-bundle warning remains.
- `scripts/smoke-gameplay.mjs`: nine installed Angmar's House/Brogan's Arm doors pass approach, open and explicit close with one state event per operation.
- Renderer harness `scripts/smoke-viewer.cjs --check-radial --full-scene` exercises actual pointer input, linked Close, held selection, icons, console placeholders, modal movement/back/Escape, creature/placeable/player menus, emote pages and ground actions. Capture: ignored `backups/animations/radial-door.png`.
