# Interface and input

Original screens must preserve their choices, actions, states and usable geometry. Client-specific screens follow the original style. The installed GUI scan parsed 104 resources/1,243 metadata controls; that is not a completed runtime action audit. Programmatic HUD, generated frames, nested widgets and server-authored NUI are additional surfaces.

## Framework and data

Native gameplay UI is coordinated in `systems/native_game_desktop.gd` with native resource/art/text owners. Use original models, fonts, images, attachment hooks and active server text/rules. Preserve intended aspect ratio and sampling.

Multiple movable windows, saved positions, front ordering, WASD, middle-camera control and world clicks outside menus remain requirements. Audit selected/disabled/pending/error states, keyboard, focus loss, scrolling, drag/drop, cancellation, scaling and sounds. An original-looking button must also reach the correct original-server action.

## Remaining work

| Surface | Current boundary | Tracking |
| --- | --- | --- |
| Inventory/containers | Core actions work; alternate associate actions disabled; nested/equipment/timing edges open | NWN-22–23 |
| Merchants/barter | Buy/sell/identify and local trades work; quantities, interruption and original-client trade open | NWN-24–25 |
| Quickbars/radials/skills | Many bindings work, including type-43 cancellation; all types/roles, tool outcomes and nested input still incomplete | NWN-26–27 |
| Spellbook | Prepared moves/exchanges work; original sticky pickup, cancel/focus-loss and drop gestures open | NWN-28 |
| Record/Examine | Original frames/details exist; complete combat qualifiers, disclosure, geometry and states open | NWN-29 |
| Party/HUD | Core actions and received indicators work; roles, possession, locator and queue/tooltip edge acceptance open | NWN-30–31 |
| Chat/text | Authoritative chat/replies work; full history, commands, formatting and provider context open | NWN-32–33 |
| Speech/nameplates | Working receipt/lifetime/layout; exact typography, overlap and broader caption restoration open | NWN-34 |
| Conversation | Long-text clipping corrected in scoped fixtures; complete styles, voice/cinematic/skip and input open | NWN-35 |
| Map/journal | Original frames and pin/note basics work; populated messages, large content and role/lifecycle coverage open | NWN-36 |
| NUI | Many controls/callbacks work; styles, popups, classic-modal membership and pending-resource recovery open | NWN-37 |
| Settings | Resize fix and key editing exist; complete effective options and video-mode selection open | NWN-38 |
| Cursors | Original resources/common world policy connected; full roles, LOS/range, hardware and exceptional-scale coverage open | NWN-39 |

Find links and acceptance criteria in [parity](parity.md). Original fixture count or artwork alone never completes a row.

## Important distinctions

- Later frame, learning, Delete, tooltip, Cancel Polymorph and recommendation fixes supersede older “not implemented” notes.
- Complete classic-modal membership is not established merely by assigning a CanvasLayer. NUI windows need original membership/capture evidence.
- The corrected resize path defers viewport updates beyond the outer resize signal; full mode-control/OS comparison remains separate.
- Native talk parsing requires certified providers and receipt-time context. Missing FullName, class/race/world/player data stays explicitly unavailable; do not infer hidden stats.
- Exact STB/FreeType glyph appearance and original-client pixels are still separate from logical font-size/layout tests.
- Whole-character glow is the user's current preference; the older exact per-Part highlight requirement is superseded.

Original GUI resource inventory and per-control research remain searchable in the [archive](archive.md), especially `NATIVE-UI-RESOURCE-INVENTORY.md` and `NATIVE-UI-FRAMEWORK.md`.
