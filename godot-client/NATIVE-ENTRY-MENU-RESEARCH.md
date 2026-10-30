# Original entry and Options menus — resource/action plan

The later [in-game Options integration](NATIVE-INGAME-OPTIONS.md) implements
the ordinary connected menu, original confirmation and real Export/return
actions. This document preserves the earlier data-plan milestone and its
historical limits. Pregame and full configuration/child flows remain open.

This preserves the earlier data-plan milestone under
[the UI goal](NATIVE-UI-PARITY-GOAL.md). The pregame integration follow-up below
now replaces its generic main/Options frames and connects the supported routes.
The full original entry workflow and replacement settings styling remain
unfinished. General porting remains deferred.

## Three different original panels

| Surface | Original constructor / initialization | Resource | Current evidence |
| --- | --- | --- | --- |
| Main menu |140707f70 /140714140 | `pre_main`, `pnl_mainmenu` | Seven bound buttons; readiness/DM/mode gates; original model/control bounds. |
| In-game Options |140822ce0 /140830b50 | `options_main`, `pnl_opt_gen` | Ten buttons and two labels; Save/Load role gate; runtime captions and Export callback. |
| Pregame Options |1408b9c00 /1408be9f0 | `options_pregame`, `pnl_opt_gen` | Seven buttons and two labels; Storage and child-panel routes; sound/build handling. |

The source GUI files are consumed from the supplied native catalog, including
their models, captions, fonts and placement. The native data plan is
`systems/native_data/entry_menu_layout.gd`. It retains the stored captions
separately from the observed runtime replacements and pairs each original
button with its recovered callback address. Those addresses describe original
evidence; they are never executed as live callbacks by the replacement.

The static `pnl_mainmenu` art bounds cover its decorative logo, not the whole
button column. Normalizing a container to that mesh alone would clip buttons
below it. The plan derives its extent from both the frame and all controls,
keeping the actual source model rectangle and source root placement separate.
The exact original viewport anchor/resize behavior is still unaccepted.

## Original control ledger

| Surface / control | Original callback | Behavior established / remaining work |
| --- | --- | --- |
| Main New |140711400 | Initialization binding and ready/DM/mode availability recovered. Campaign/module workflow still needs tracing and native integration. |
| Main Load |140710b40 | Binding/availability recovered; save browsing/actions remain unfinished. |
| Main Multiplayer |140710fd0 | Checks configured key and login identity before the multiplayer selection panel. Preserve protected credentials and existing admission; do not bypass these branches. |
| Main Movies |140710e40 | Binding recovered; movie list/playback route still open. |
| Main Options |140711c50 | Opens `CPregameOptionsPanel`, hides the main panel and retains a return callback. |
| Main Exit |1407105b0 | Original application shutdown calls; full native dismissal/lifecycle comparison remains open. |
| Main repository/news |140712200 | Binding recovered, but dynamic caption/content and callback body remain open. A blank GUI caption does not establish an unused button. |
| Game Options Game |14082f4b0 | Opens original `Nui::ConfigWindow` with filter0x1441 and hides parent. Modern original behavior cannot be inferred solely from legacy `options_game.gui`. |
| Game Options Video |14082ff90 | Opens `OPTIONS_VIDMODES`, hides parent and installs return callback. Runtime caption ref0x1baf replaces GUI ref5186. |
| Game Options Sound |14082fe80 | Bound address is observed but not an analyzed procedure. Availability follows `g_bDisableSound`. Initializer also deletes its model; exact remaining hit/text presentation needs original-client inspection. |
| Game Options Controls |14082f2b0 | Opens shared control panel constructor1408b94d0. Runtime caption ref0x28ad replaces GUI ref6372. |
| Game Options Load / Save |14082f7e0 /14082fb10 | Bound independently; disabled when original local-host predicate is false. Their complete child workflows remain open. |
| Game Options Save Character |14082fb60 | Caption changes from stored ref50 to0x19a0. Calls1407bfbe0, which sends original `(6,0x1f,0,0)` generic request; then posts ref0xd7 and closes. Actual server export/persistence must still be verified through the native menu. |
| Game Options Resume / X |14082fb00 /140830150 | Bound code entry addresses; first instructions decode but neither has a provider function boundary. Complete return/focus behavior remains open. |
| Game Options Exit |14082f330 | Opens original Yes/No confirmation (ordinary ref0x2844; other-player host branch0xd002), hides parent and uses14082f900 response routing. Additional save/hosting/DM branches remain open. |
| Pregame Game |1408bc710 | Opens the same original ConfigWindow filter0x1441 with its own return callback. |
| Pregame Video |1408bd240 | Opens shared video-mode constructor140822e40; runtime caption ref0x1baf. |
| Pregame Sound |1408bd230 | Bound entry explicitly remains unanalyzed/undecodable. Same sound-enable/model-removal observations; no invented hidden-state policy accepted. |
| Pregame Controls |1408bc670 | Opens shared control panel, with its own return callback and runtime caption ref0x28ad. |
| Pregame NWSync |1408bca70 | Runtime caption is literal “Storage”; opens original `Nui::NWSync::StorageManager`. It is not merely a mods-folder picker. |
| Pregame Close / X |1408bc640 | Both deactivate/delete the panel through the same original callback. |
| Both Options BuildNumber | Initializers above | Runtime build string replaces invalid stored TLK ref; original gray0.4 color. Replacement must identify its own build, not present the original executable's version as its own. |

Callback discovery is not action acceptance. Sound, Resume and X explicitly
retain provider limits; Load/New/Movies/news and several secondary callbacks
require further investigation. The current resource/control inventory also
remains open for modern configuration, storage, confirmations and child pages.

## Availability and original-instruction checks

Main initialization disables all seven controls and sets caption RGB0.5.
Update140717b00 waits for NWSync initialization/migrations. Enable14070e7f0
then enables all seven and sets white text; DM or client-server mode disables
New/Load again. DM additionally substitutes `DM_Load1`/`DM_Load2` for the two
pregame background textures. Replacement readiness must be tied to its actual
resource/service lifecycle; this data projection does not fabricate readiness.

In-game Save/Load uses1406ac430 →1406daa40. True requires all of: ordinary
client-server mode, connected client, an application server present, connection
to localhost and nonzero client field0x5a4. An IP address or being a DM alone
cannot grant the role. The current bridge must disclose the actual facts before
these controls can be wired to that policy.

`../scripts/inspect-native-entry-menu-policy.py` executes unchanged original
instructions offline in Unicorn. Only named lower boundaries (GUI setters,
texture replacement, DM and two network queries) are captured. Four DM/mode
cases record final enabled/color/texture state; all32 combinations of the
Save/Load predicate record result and short-circuit query calls. This does not
exercise a live original window, server, settings file or GPU.

Evidence is retained in:

- `../backups/animations/rea-native-entry-menus-v1.json`:18 original dossiers,
  nine string/xref/vtable observations.
- `../backups/animations/rea-native-entry-menu-actions-v1.json`: nine follow-up
  dossiers and eight explicit callback-boundary/instruction observations.
- `../backups/animations/native-entry-menu-policy-observations-v1.json`:
  original instruction outputs for the36 cases above.

All target original client SHA
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.

## Verification and next integration

`native-entry-menu-plan-v3` passes136 debugger-backed native checks: installed
GUI/models, all source controls/callback references, runtime caption policy,
control-inclusive extent, active placement/frame replacement, missing-source
failures, all original instruction cases and colors. It leaves visible menu
and full parity acceptance false. The initial test assumed the first child was
a movable button; a label's different geometry caused a retained script-error
candidate. Only that verified owned headless test was retired, the test now
selects a named real button, and the corrected runs have no engine/lifetime
errors. Earlier67/132-check versions are historical, not the current receipt.

The verified rollback is `backups/native-entry-menu-plan-v1.zip`.
`tools/audit-native-entry-menu-plan.mjs` checks current source pins, original
evidence, oracle, rollback and explicit limits. The previous player/invitation
checkpoint remains independently accepted for its scope.

Next implement the visible native owners with pregame/current-server catalog
ownership, source raster/font/pose handling, exact original placement and
complete child action routing. Connect Export to its existing authoritative
export service; preserve pending/refusal/timeout feedback and protected-key
handling. Restore original confirmations, capability/role/state availability,
config/storage pages and return/focus/input behavior. Style replacement-only
settings in the same visual system. Direct original-client comparison, scale,
all input/states and actual original-server outcomes remain required.

## Pregame native integration follow-up

`native_pregame_menu.gd` now owns a native pregame catalog, original TLK,
artwork, bitmap fonts and source Main/Options panels before a world exists.
`native_gui_painter.gd` reuses the shared original-model button/label painter
without constructing an inventory or gameplay UI. The native catalog worker
mounts installed resources, user overrides and user-enabled Workshop content
from the existing startup descriptor. It does not borrow an old server's HAKs,
NWSync content, text owner or resource workers. In-game Options continues to
use the active current-server catalog and original role/capability scope.

Supported pregame actions now use their existing real owners:

- Multiplayer dismisses Main Menu and opens the actual server browser. The
  protected-login/admission service remains responsible for any later join.
- Options opens the distinct `options_pregame` source panel. Its Close/X and
  Escape return to Main Menu. Build text identifies the replacement in the
  original gray caption rather than impersonating the original binary version.
- Resolution/UI Scaling and Change Key Settings open their native source
  editors before joining. Cancel/return restores pregame Options. The key
  editor includes all36 configurable hotbar slots; the existing28 unsupported
  original key actions and full display-mode switching remain explicit gaps.
- Game Options opens the existing replacement settings and returns to its
  pregame parent when closed. This does not implement the original modern
  ConfigWindow or certify the replacement-only settings' final visual style.
- Exit emits the actual application-exit route. It does not issue a server
  disconnect in an unconnected context.

Unavailable actions stay disabled with explicit tooltips. New/Load campaign,
Movies, repository/news, and original NWSync Storage are not completed by this
frame migration. Storage retains its original name; it is not silently replaced
with a mods-folder picker. Persistent mods/CD-key settings, complete modern
configuration, campaign/save browsing and those modern local NUI tools still
need native menu integration. Main-menu role/state availability is therefore
not accepted as complete original parity. The blank source repository/news
caption and full original background/intro/anchor/resize behavior remain open.

Further original inspection identifies140712200 as construction of a local
`News::Browser` NUI window with a return continuation, followed by Main Menu
hide. This is a separate local client window, beyond server-created NUI layouts.
Its static dossier is `backups/animations/rea-native-pregame-news-v1.json`.
No news endpoint or public game server was contacted during this investigation.

The actual held-press input check exposed a Godot4.7 button latch across
hide/reopen. The [original Godot button implementation](https://raw.githubusercontent.com/godotengine/godot/4.7/scene/gui/base_button.cpp)
clears a press attempt on visibility retirement while retaining its down-focus
latch; disabling resets both and emits the corresponding release. Source menu
dismissal now briefly disables/restores each button through public APIs,
preserving its true availability and the old presentation-scope guard. The
old release cannot act on a new presentation, and the next new click works.
The first failed input runs and ineffective toggled-state-setter experiment
remain retained diagnostic receipts, not accepted behavior.

Every private pregame catalog/art/font/page worker is joined before its owner
retires. Session reset keeps the independent pregame owner available; application
shutdown and the network-forbidden startup check close it explicitly. Reports
retain its source-catalog mount statistics, main/Options `layout_ready_ms` and
actual worker count. Layout timing is not a claim of complete visible-art
readiness or performance parity.

Final scoped receipts use `native-pregame-layout-final-v1` (136 source/policy
checks), `native-pregame-input-final-v1` (26 actual native input/lifecycle checks),
`native-pregame-ingame-final-v1` (35 existing connected-menu input checks), the
real network-forbidden startup route and `native-pregame-local-final-v1` (170
owned original-server checks). Startup tests additionally exercise existing
model/UI-preparation start/cancel operations. A concurrent startup run exceeded
its existing watchdog and remains a failed receipt; only the separately
accepted run can certify that flow. The acceptance audit retains the exact run
and source hashes in `reports/native-pregame-acceptance-v1.json` when verified.

Native screenshots cover the installed Main/Options panels at the tested
viewport. Browser/login/character-list visuals, full entry actions, direct
original-client side-by-side comparison, backgrounds, sound/preferences,
localization, scales, role states and retained placement remain required.
Neither this milestone nor its passing checks complete the entire UI goal.
