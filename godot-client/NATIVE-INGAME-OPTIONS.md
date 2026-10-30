# Original in-game Options — scoped integration

The later [native video-page integration](NATIVE-VIDEO-OPTIONS.md) enables
Resolution/UI Scaling with real windowed scale actions. Resolution-disabled
statements below describe this earlier Options checkpoint.

The HUD Options action and in-game Escape menu now use the original
`options_main` panel, source button models/hooks, original bitmap captions and
runtime wording. The panel has its own original Yes/No exit confirmation,
returns to the current native settings child, resumes gameplay and routes
Save Character through the existing authoritative export service. The generic
pregame entry and full child/configuration pages are still unfinished.

## Ownership and actions

`native_entry_menu_frame.gd` prepares source GUI/model metadata on native workers
and borrows the active session's original artwork/font owner. It consumes the
current native catalog, including server replacements. `native_main_menu.gd`
owns actions, connection capability gates, dragging and saved placement.
`native_session_world.gd` connects the HUD, current settings, export service,
actual save acknowledgement and disconnect request. The menu retires before
its borrowed session resources.

The title/build labels are unbounded original CGuiLabels: their source alignment
anchors apply, while ignored stored Width/Height must not clip the title or
force a wider panel. The source panel is429x447. The replacement build label
identifies Native Godot rather than claiming the original executable's version.
The original Sound model is removed by initialization and its callbacks are
literal RET0; legacy GUI metadata does not add a new active Sound button.

Save Character dismisses the menu and sends the existing original-compatible
export request. Busy/disconnected context disables duplicate export and exit.
Success feedback follows an actual server BIC save acknowledgement. Exit opens
the original confirmation without disconnecting; No/Escape restores the parent,
Yes requests disconnect, and Resume/X only dismiss. Closing the current Game
Options child restores its parent only in the same live connection scope.
Held clicks cannot retarget across connection/area/controlled-character changes.
The title drags, position persists, and clamping includes scaled panel bounds.
WASD, outside clicks and outside middle-mouse input remain available.

Host Save/Load, Resolution/UI Scaling and Change Key Settings are still disabled
until their actual owners are integrated. This is a capability gap, not parity
with every original context. Game Options currently reaches the existing native
settings page; the original modern `Nui::ConfigWindow` is not accepted as ported.
Pregame main/Options/Storage, original host and DM branches, full key/default
focus/tooltip/role variants and direct original-client comparison remain open.

## Evidence and verification

Original client SHA256:
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
The [entry research](NATIVE-ENTRY-MENU-RESEARCH.md) indexes original initializers,
callbacks, runtime captions and36 offline original-instruction policy cases.
The additional read-only evidence files are
`rea-native-entry-menu-sound-v1.json` and
`rea-native-entry-menu-frame-v1.json` under `../backups/animations`.

The current acceptance indexes413 scoped checks:

| Receipt | Checks |
| --- | ---: |
| `native-barter-menu-regression-v1` |35 actual isolated menu input |
| `native-entry-menu-layout-current-v1` |136 source layout/original policy |
| `native-barter-desktop-regression-v1` |41 desktop input |
| `native-entry-menu-settings-current-v1` |38 settings preferences |
| `native-entry-menu-retirement-current-v1` |20 resource retirement |
| `native-entry-menu-layers-current-v1` |16 window/input layering |
| `native-entry-menu-server-v5` |127 owned original-server actions |

The server receipt includes actual HUD menu entry, settings return, exit No,
server export/persistence acknowledgement and feedback, then Resume into the
same world. It also preserves existing combat/inventory/Identify/level-up
baseline checks;127 is not a count of distinct Options actions. The test uses
the unchanged original server and an isolated fixture on127.0.0.1:5125,
protected test credentials and no public connections. Native exit is0,
workers drain, source pins remain unchanged and no native exception or
script/lifetime error occurs. The existing wind-sampling warning remains.
Normal/confirmation/125percent screenshots were inspected; physical mouse
and manual sessions were untouched. Full original-client visual parity is
not established by those screenshots.

Earlier failed compile, fixture-access and concurrent-source-change receipts
remain retained and excluded. Older passing receipts describe their own
historical source. `tools/audit-native-ingame-options.mjs` verifies current
pins, source/root-owner identity, original evidence, cleanup and rollback,
then writes `reports/native-ingame-options-acceptance-v1.json`.

Rollback: `backups/native-ingame-options-v1.zip`, read-back verified. It includes
the shared current worktree, including independent prework/settings changes;
this scoped menu acceptance does not certify their broader functionality.
The [entire UI goal](NATIVE-UI-PARITY-GOAL.md) remains active.
