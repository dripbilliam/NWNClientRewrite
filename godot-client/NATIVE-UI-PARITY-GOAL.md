# Complete native UI parity — current priority

Requested 2026-10-28. Active; completion is unproven.

Latest character-picker direction,2026-10-29: restore the original native-style
chooser for normal launches. This supersedes the redesign appearance exception
recorded below. The experimental redesign stays off unless explicitly requested
by a diagnostic argument; original source layouts and working chooser actions
remain the production path.

The [independent pregame chooser](NATIVE-CHARACTER-FRONTEND.md) now warms the
installed frame and roster artwork at Main Menu. Server data updates its rows,
records and dynamic images without replacing the UI or waiting for gameplay
setup. Local functional/launcher evidence is separate from live latency.

User-requested consolidation,2026-10-29: [shared native UI framework](NATIVE-UI-FRAMEWORK.md)
separates reusable window/control/theme construction from screen-specific actions.
Client Options and Game Options use definitions; original GUI adapters use the
common painter/builder while retaining active-source layouts and server semantics.
The approved picker uses named shared style variants. Full UI parity stays open.

User correction,2026-10-29: [main-menu presentation consistency](NATIVE-MENU-CONSISTENCY.md)
removes prototype/source switching, shares original artwork and fonts with client
settings, fixes literal News text and checkbox backface visibility, and preserves
source menu/navigation/input. Full original configuration and all UI parity stay open.

The [Customize preservation groundwork](NATIVE-CHARACTER-CUSTOMIZATION.md)
records the original portrait → appearance → information flow and implements
existing-BIC cosmetic edits without regenerating equipment/history/spells.
Native source/corpus tests pass; the editor controls, storage/refresh lifecycle,
role/scale/visual acceptance and Customize availability remain unfinished.

The [local Delete follow-up](NATIVE-LOCAL-CHARACTER-DELETION.md) connects the
original confirmation, bounded message, native profile/Workshop file mutation,
installed-row alias dismissal and scoped catalog refresh. Original instruction,
native input/file and local-server regression scopes are recorded separately;
the connected original-style and production picker Delete paths now have real
IPC and authoritative local-server follow-up evidence. DM roles, sound,
Customize and full UI parity remain open. A real locked-row signal error found
by that integration is corrected and independently regression-tested.

User exception,2026-10-29: [character selection is being redesigned](CHARACTER-PICKER-DESIGN.md).
It may differ visually from the binary and must open immediately with a
considered visual hierarchy; a selected-character3D preview loads independently.
Original-compatible actions, active server resources and native ownership
remain required. This exception does not relax other original UI surfaces.

The [last-seen character appearance follow-up](NATIVE-CHARACTER-LAST-SEEN.md)
connects the new production picker, portrait rows and original keyboard ownership
with a native disconnect appearance cache. An owned original vault-only server
supplies actual equipped appearance, then a reconnected prejoin native picker
shows that cached gear with an explicit label. Full-app lifecycle/portal coverage,
Delete/Customize, full chooser acceptance and the entire UI inventory remain open.

The [animated GUI sampler correction](NATIVE-GUI-ACTOR-SAMPLER.md) removes
the repeated chooser tab outlines through original texture clamp settings on
the actual actor meshes. Complete artwork/state/caption/scale parity remains
open; this is a rendering integration correction, not full screen acceptance.

The [native local character catalog follow-up](NATIVE-LOCAL-CHARACTER-CATALOG.md)
decodes BIC row names/classes/portraits in a native worker and applies the active
original Pregen-table policy, including its unavailable-table fallback. The39
installed BIC corpus and owned-local UI actions pass scoped checks.
[Profile/Workshop vault discovery](NATIVE-LOCAL-VAULT-DISCOVERY.md) now follows
original alias precedence. Full vault edge cases, local mutation, tab artwork/state and full
role/scale/original-client comparison remain open.

The [pregenerated preference follow-up](NATIVE-CHARACTER-PREGENERATED.md)
restores the original default/read/save lifecycle through native storage and
source checkbox input. Graphical round trips and owned-local authoritative
checks pass. Local metadata acquisition, permitted local mutation, visible tab
outline/state investigation and full original-client comparison remain open.

The [focused chooser edit follow-up](NATIVE-CHARACTER-CHOOSER-EDIT.md) fixes
Enter/Escape/Tab and other edit keys leaking to unrelated handlers or Godot
focus traversal, using original constructor/dispatch/key evidence. Graphical
input and owned-local authoritative checks pass. Pregenerated persistence is
the next chooser gap; full UI and original appearance acceptance remain open.

The [automatic chooser selection follow-up](NATIVE-CHARACTER-AUTO-SELECTION.md)
implements original first-row rebuild behavior and exact current BIC/input
ownership in diagnostics. Native graphical input, entry routes and an original
owned-local server run pass scoped checks. Full appearance/state/role coverage,
local mutation, the retained startup exception and the whole UI audit stay open.
This supersedes the earlier milestones' pending fresh graphical/local checks
for the source covered by this follow-up; it does not accept complete UI parity.

The [chooser cursor-key/title follow-up](NATIVE-CHARACTER-CHOOSER-KEYS.md)
connects original row navigation/scroll policy and the localized record caption.
Headless native input and rule regressions pass; a headless Player List artwork
check failed and remains unaccepted. The manual client is preserved. Automatic
first selection, fresh graphical/local checks and the whole UI audit stay open.

The [pregame Character detail-list follow-up](NATIVE-PREGAME-CHARACTER-DETAILS.md)
replaces the interim description with original-generated stat/alignment rows,
active class BAB data, source text/scroll attachments and fixed list-row advance.
Original instruction and headless native input scopes pass. Fresh graphical/local
validation, wider Character modes and the complete UI audit remain unfinished.

The [pregame Character numeric follow-up](NATIVE-PREGAME-CHARACTER-NUMBERS.md)
connects typed BIC statistics to original ability/HP/AC/alignment/XP display rules.
Original instruction and headless control scopes pass. Graphical/local admission
validation of this change, full Character detail content and complete UI parity
remain open; the user's running manual client is preserved.

The [pregame Spells follow-up](NATIVE-PREGAME-SPELLS.md) connects the fourth
record tab to typed native BIC books, original known/summary rules and active
server text. Original instruction, graphical and owned-local input scopes pass.
Complete Character statistics and full original-client/UI/state comparison
remain open, along with the retained startup exception. Full UI is unaccepted.

The [pregame Skills follow-up](NATIVE-PREGAME-SKILLS.md) connects the original
tab/list/help/value controls to typed native BIC data, active native class/race/
skill tables and original-validated pregame calculations. Local pointer checks
and regression scopes pass. Spells, complete Character statistics, full original
comparison and the retained startup exception remain open; full UI is unaccepted.

The [pregame Feats follow-up](NATIVE-LOBBY-RECORD-FEATS.md) connects the original
mode-zero record tab/list/help/scrollbars to native BIC identities and active
server rules. Original instruction observations and local native input pass
scoped checks. Skills/Spells/derived stats and complete original comparison
remain open, as does a retained native startup exception; full UI is unaccepted.

The [native character preview follow-up](NATIVE-CHARACTER-PREVIEW.md) moves BIC
preview decoding/projection into an owned Godot worker, with raw byte transport,
selection/connection guards, active native text refresh and bounded cleanup.
The isolated original local server verifies the actual native preview before
Play. Derived combat statistics and remaining record tabs are still unfinished;
this does not accept complete chooser or UI parity.

The [original GUI model sampler follow-up](NATIVE-GUI-SAMPLER.md) carries active
TXI clamp/filter/mipmap metadata through GUI preparation, saved prework and native
model-viewports. It removes the reviewed chooser gray bands and verifies original
instruction policy and native pixel cases. An older sealed GUI corpus lacks TXI
payloads and retains a failed regression; full visual/state/UI parity is open.

The [pregame/gameplay presentation follow-up](NATIVE-GAMEPLAY-PHASE.md) separates
early shared resource preparation from visible gameplay canvases and input.
The chooser/creator stay available, while chat/HUD/shortcuts wait for admitted
play and world reveal. Separate source phase, native input and owned-server
checks are recorded there; the complete UI inventory remains unfinished.

The [owned native lobby live follow-up](NATIVE-LOBBY-LIVE.md) verifies the real
second-participant roster and stop/reopen lifecycle before ordinary admission.
Live review also corrected JSON float suffixes in integer GUI fields. Native
graphical, startup, protocol and owned gameplay checks pass; one retained
intermittent blood-pixel failure remains unaccepted. Full UI parity stays open.

The [chooser Server Info and Player List follow-up](NATIVE-LOBBY-PAGES.md) adds
source-native page owners, real roster subscription/update/removal/stop wiring,
basic/extended metadata, original dialog font and received server-status mapping.
Native input/pixel review, protocol tests and owned local gameplay regression
pass. Its subsequent owned live follow-up verifies a fresh two-participant
roster; original-client comparison and the wider chooser/UI requirements remain
open.

The [native character chooser step](NATIVE-CHARACTER-LOBBY.md) replaces the
admitted generic chooser with PRE_PLAYMOD/source rows, original portrait sizes,
native scrollbar and a partial embedded record. Scoped selection/double-click,
New/Cancel, active-server labels and lifecycle checks pass, with startup and
owned local-server regressions. Record/server/player pages, local metadata and
editing, keyboard and complete original visual/state/role comparison remain open.

The [server-row activation follow-up](NATIVE-SERVER-ACTIVATION.md) adds source
mouse-down selection, double-click and Enter through Connect/password, with
canonical acknowledgment and cancellation guards. Headless checks and fresh
graphical/startup/owned-local-server checks pass (385 scoped checks). The user
authorized replacing the finished manual session. Full UI parity remains open.

The [server-list input and label follow-up](NATIVE-SERVER-LIST-INPUT.md) adds
original one-row cursor navigation across transport pages and restores unbounded
Details captions. Headless and original-instruction checks pass; the activation
follow-up also verifies these changes graphically and against the local server.

The [native Server Details follow-up](NATIVE-SERVER-DETAILS.md) adds the original
Details and password owners, extended BNDS/BNDR metadata and scoped cancellation.
It replaces the earlier interim Details notice. Full browser and UI parity,
including remaining visual/state/role audits, is still unfinished.

The [native server-page follow-up](NATIVE-SERVER-PAGES.md) replaces the main-flow
generic Internet/History/Favorites form with source page/tab/column/viewport and
scrollbar presentation and connected actions. Sort direction/priority transitions
match4,608 original-instruction cases. Game-type filtering, complete details and
admission dialogs, status text and the full role/scale/visual audit remain open.

The [native server-filter follow-up](NATIVE-SERVER-FILTERS.md) adds the source
filter modal and persistent authoritative occupancy/module choices. Its modern
row predicate matches4,480 unchanged-original-instruction observations. The main
server-list pages remain generic; the entire browser/UI goal stays unfinished.

The [native Multiplayer entry milestone](NATIVE-MULTIPLAYER-ENTRY.md) restores
the original intermediate menu, accepted-name prompt policy, modal Direct return,
visible refusal notices and cancellation of pending browser providers. Hosting,
LAN and the original browser's complete pages remain unfinished. This is another
scoped native UI step; the entire goal remains active.

The [UI cancellation follow-up](NATIVE-UI-CANCELLATION.md) fixes the comprehensive
startup timeout for the tested content by forwarding Cancel into native catalog
discovery. The graphical check now passes its unchanged20-second watchdog and
art gate, including original entry routes and model/UI preparation cancellation.
Cold/reused menu pixels and owned original-server regressions pass. This is
scoped lifecycle/UI behavior, not complete UI parity or overall loading/FPS parity.

The [native connection UI work](NATIVE-CONNECTION-UI.md) now presents original
Player Name, its OK notices and Direct Connect, with binary-matched correction
rules, real Save As Default persistence and scoped pending/refusal/retry behavior.
Native screenshots were reviewed and the real native admission route passed
against the owned original local server before170 gameplay regressions. The user
authorized replacing the manual replacement client for those tests; original
NWN was preserved. Its original startup timeout is superseded by the cancellation
follow-up above for the tested catalog. Other scales/original-client comparison, full
browser/CD-key/connection/selection migration and the entire UI audit remain open.

The [pregame integration follow-up](NATIVE-ENTRY-MENU-RESEARCH.md) gives Main
Menu and pregame Options their original artwork/fonts and an independent native
catalog before joining. Multiplayer, Video, Controls, replacement settings,
return/cancel and Exit reach actual owners; an interrupted held press no longer
swallows the next click. Campaign/Movies/News/Storage, complete configuration,
background/role/gesture/scale comparison and browser/login/character-list visual
migration remain open. Disabled unported controls are explicit gaps, not parity.

The [gold/stack amount-control follow-up](NATIVE-INVENTORY-GOLD.md) corrects
decimal-prefix parsing, original arrow repeat timing, typed character admission,
focus/cancellation and a source-anchor title clipping defect. Original executed
arithmetic/parser/timer cases, native control input and owned local-server
transfers are scoped evidence. Other edit/clipboard/IME behavior, roles, scales,
shared button audio and the broader source-label audit remain required.

The [item context milestone](NATIVE-ITEM-CONTEXT.md) replaces the rectangular
inventory popup with original-data item wheels and native item-power pages and
family selection. Merchant right-click is enabled; item-family drag can reach
quickbars; split and learn processing use original-compatible requests and
authoritative outcomes. Requested trade wheels are explicitly an extension:
original8823d0 suppresses the standard barter-cell wheel. Current trade serial,
item signatures and received lock state gate their Examine/Remove actions.
Original context/power/packet oracles, native visual/input checks and owned local
server regressions are scoped evidence. The linked remaining-work list and the
rest of the entire UI inventory remain required; this is not complete parity.

The [native cursor milestone](NATIVE-MOUSE-CURSORS.md) replaces generic live
world hover shapes with active-catalog original TGA cursors, common object and
inventory hover/drag selection, and original spell/skill/item/feat/script target
cursor policies. Server-selected target cursor IDs are preserved; valid native
inventory target clicks route to canonical requests, and invalid world targets
stay in selection mode. Original instruction oracles and native pixel/input,
startup and owned loopback checks cover this scoped work. Full associate/DM,
directional/map/modal, software/override scale, lobby and live hardware cursor
parity remain open. Item wheels have the separate scoped implementation above;
their complete role/state/gesture audit remains required.

HUD startup no longer waits for every rule table. `native_gameplay_ui.gd`
dispatches portrait/token/keymap data first, installs movement bindings when
Keymap arrives, and lets `native_game_desktop.gd` prepare original party/HP and
quickbar geometry while remaining rules load. Pending slots issue no actions;
rule-dependent menus remain disabled while Map/Rest/Options can work. Current
HP/name data comes from the received actor. A source-font notice explains the
remaining menu preparation and retires on full readiness. UI table projection
uses the existing read-only decoded source path rather than copying aliased row
graphs at both cache levels; mutable consumers retain copy isolation.

`native-ui-startup-held-final-v1` holds an actual feat worker read open and
checks native HUD pixels, early bindings, disabled pending shortcuts, menu
availability and the complete-rule handoff. Party/quickbar/desktop, original
Keymap and owned loopback gameplay checks accompany it. This is a startup
dependency correction, not an Arelith loading-time or complete UI acceptance.
Per-table queue/read/decode/worker/completion observations now appear as
`ui_startup` in profiled session logs. Most complex menus and queued chat still
wait for full rule/text readiness; narrower dependency groups and the user's
exact slow public-server resource still require verification. No automated
public connections were made, and the manual session was preserved.

[Change Key Settings research and native data plan](NATIVE-KEY-SETTINGS-RESEARCH.md)
now recovers original named table rows, four-page geometry, physical capture,
language fallback, duplicate handling and pending/commit/discard policy. Native
data checks compare unchanged original instructions and sealed table baselines.
See the integration follow-up below for the current visible-page/input scope.
The user also requires editable bindings for all36 hotbar slots, preserving
the original F1–F12/Shift/Ctrl defaults with persistent custom chords and
cross-action conflict handling. This extension must activate the real server
shortcut path and is not complete merely from reproducing original settings.

The [native key editor and hotbar integration](NATIVE-KEY-SETTINGS.md) now opens
through Options with pending/cancel/commit/default behavior, persisted keys,
real input routing and all36 editable hotbar slots. Actual loopback-server
movement and spell use pass;28 unsupported original actions and full key/UI
comparison remain open. A [separate UI preload](NATIVE-UI-PREBAKE-RESEARCH.md)
now prepares unopened menu artwork, layout models and fonts, with progress,
cancellation, input-validated disk reuse and custom-resource coverage. Four
legacy source/reader issues and new variable-size layouts remain explicit.
Complete context-cursor and item-wheel role/state/gesture comparison across
player, container, store and trade inventories remains unfinished. Preparation
is not full menu parity.

The [barter button-state correction](NATIVE-BARTER-BUTTON-STATES.md) now renders
the original animated UV states for Offer/Accept. Actual local-server peer
acceptance and retraction, individual flags and exchange/refund outcomes pass
scoped checks. The complete barter/UI audit remains open.

[Entry/Options research and native data plan](NATIVE-ENTRY-MENU-RESEARCH.md)
recovers the three distinct original panels, source controls, runtime captions
and menu/host availability against unchanged original instructions. The
[in-game Options integration](NATIVE-INGAME-OPTIONS.md) now has its original
frame, native input, confirmation, actual Export acknowledgement and child
return. Pregame entry/Options and full configuration, resolution, key settings,
storage and host workflows remain unfinished. Scoped integration is not full
menu or UI acceptance.

The [native Resolution/UI Scaling page](NATIVE-VIDEO-OPTIONS.md) now opens
from in-game Options with source artwork, read-only native mode enumeration,
real scale Apply/OK/Cancel, retained placement and input/camera preservation.
Its [research](NATIVE-VIDEO-OPTIONS-RESEARCH.md) verifies437 original float cases.
Real mode changes/fullscreen, pregame integration, direct original-client
comparison and the complete video/UI audit remain unfinished.

[Native Players and invitation UI](NATIVE-PLAYERS-FRAME.md) now uses original
resources and connects player selection/Tell events, independent attitudes,
party actions and source invitation controls. Actual native input and owned
two-peer original-server checks pass. Administrator controls, full original-client
visual/gesture/role/state comparison and the complete UI audit remain open.

[Area-map framing and notes](NATIVE-AREA-MAP-FRAME.md) now use the original
generated frame, three zoom levels, pan indicators and pin editor. Actual native
input and an owned original server verify pin GUI events and personal-note
creation/edit/deletion. Direct original-client visual/gesture/role comparison
and complete map parity remain open.

[Native journal](NATIVE-JOURNAL-FRAME.md) replaces the generic panel with original
Active/Completed/Personal Notes pages, sort/expand controls, timestamps and
persistent editable notes. Native input, window coverage and actual local-server
quest lifecycle pass scoped checks. World/DM journal actions, original-client
comparison and full journal/UI completion remain open.

The [conversation milestone](NATIVE-CONVERSATION-FRAME.md) replaces its generic
panel with original resources, received speaker portrait/name, separate text
scrolling and source-derived sizing/selection policy. Native input and actual
original-server dialogue start/reply/end/abort pass scoped checks. Full visual,
font, role and interaction variants remain open; the goal is not complete.

The [original resource inventory](NATIVE-UI-RESOURCE-INVENTORY.md) now enumerates
all104 installed GUI resources and1,243 controls, plus the separate programmatic
character-sheet investigation. It is metadata evidence, not a full action audit.
The [spellbook structure research](NATIVE-SPELLBOOK-RESEARCH.md) now recovers
both windows, tabs, linked known rows and nine-column memorization slots. Its
native data plan is checked. The [spellbook integration](NATIVE-SPELLBOOK-FRAME.md)
now replaces the generic frame, adds grouped known/prepared views and original
help artwork, with native input and existing authoritative local action checks.
Exact gestures, state/role variants and full original-client comparison remain open.
The [preparation follow-up](NATIVE-SPELL-PREPARATION.md) adds original slot
move/exchange policy, authoritative pending ownership and58-input/106-local-action
checks. Original pickup/cancel/world-drop routing and full UI completion remain open.

The [native character-sheet frame milestone](NATIVE-CHARACTER-FRAME.md) replaces
its generic in-game frame with original resources and restores the server-gated
Level Up control. Full character-sheet content, resize/state parity and the
remaining UI inventory are still open; this is not goal completion.
Follow-ups recover [record values](NATIVE-RECORD-VALUES.md) and
[record-entry admission/order](NATIVE-RECORD-ENTRIES.md) against offline original
instruction oracles. Complete record detail content and resizing remain open.
The [resize follow-up](NATIVE-CHARACTER-RESIZE.md) adds actual footer input and
world-anchor viewport updates. Exact original limits/states and complete record
content/disclosure remain unaccepted.
The [quickbar frame follow-up](NATIVE-QUICKBAR-FRAME.md) replaces stretched
generic slots with original model hooks/poses, default dialog labels/counts and
bottom anchoring. Full quickbar states, layouts, tooltips and original-client
comparison remain open.
The [party HUD frame follow-up](NATIVE-PARTY-FRAME.md) adds original portrait,
action, member, vertical-health and level-overlay geometry with fixed self HUD
and a separate roster. Locator/state/leader and role/disclosure/input variants
and original-client comparison remain open.
The [health-variant follow-up](NATIVE-PARTY-HEALTH.md) maps received poison/
disease flags to original clips and verifies exact original finite mode/time
arithmetic. Live affliction/role/disclosure and full HUD comparison remain open.

Every UI surface replicated from the original NWN binary must look and function
the same in the relevant game mode. Matching appearance includes layout,
artwork, proportions/cropping, fonts, colors, text, spacing, scrolling, tooltips
and every control state. Matching function includes the available actions,
what each button does, contextual availability, input, feedback, dismissal,
drag/drop and actual server communication. A generic usable replacement is
not an accepted final implementation of an original screen.

Replacement-only menus and tools must be styled coherently with the base game.
Their unique functions can remain unique; their windows and widgets must stop
looking like unstyled Godot forms. Server-authored NUI retains the original
client's layout, binding and skin behavior rather than having its design replaced.

**General porting resumes only after the entire UI completion audit passes.**
Backend work necessary to make a UI action function correctly is within this
goal. Unrelated combat expansion, rendering experiments and general migration
are deferred. The previous [UI/combat goal](NATIVE-UI-COMBAT-MIGRATION-GOAL.md)
remains unfinished backlog and historical evidence, not completed work.

## Definition of completion

1. Inventory every current UI surface, child dialog, contextual variant and
   control, and compare it with original resources and binary behavior. Discover
   omitted controls/submenus by inspection; the initial list below is not a cap.
2. For each original screen, recover its layout, fonts, artwork and state rules.
   Verify the visible result at native and supported scaled sizes. Fix stretched
   assets rather than accepting approximate rectangles or screenshots alone.
3. For every control, record its action, availability, input, request/local
   setting change, authoritative outcome, refusal, pending state and feedback.
   Exercise these paths. No dead buttons, placeholder panels or predicted
   gameplay success count as complete.
4. For unique screens, define and apply a base-game-derived style to every
   widget and interaction state. Match the original conventions without adding
   fake native controls that have no implementation.
5. Verify windows together: dragging, retained positions, front ordering,
   modal/selection overlays, focus, keyboard shortcuts, tooltips, scrollbars,
   clipping, resize/UI scale and reopening. Preserve movement/camera behavior.
6. Verify real local-server results and relevant role/content variants. Validate
   original protocol compatibility and mixed original/replacement clients where
   applicable. Native input tests and original-resource rendering support this;
   narrow passing suites do not prove the whole UI complete.
7. Audit every surface and action against current source and retained evidence.
   Anything missing, approximate, untested or weakly evidenced remains open.
   Only an audit with no such gaps permits general porting to resume.

## Initial source audit

No row is accepted as fully complete. "Partial" means scoped implementation or
evidence exists; it does not grant complete visual or functional parity.

| Surface | Current entry points | Initial finding / required follow-up |
| --- | --- | --- |
| Main menu / in-game menu | `systems/native_main_menu.gd` | Generic panel/buttons. Recover mode-specific original appearance and actions; verify dismissal and focus. |
| Options, rendering controls and preferences | `systems/native_render_settings.gd` | Custom tabs and Godot widgets. Original-option parity plus native styling for unique settings; verify persistence and all toggle effects. |
| Multiplayer server browser / direct connect / credentials | `systems/server_browser.gd` | Generic forms and lists. Original layout/state/action audit, progress/cancel/refusal states and protected-key controls. |
| Character list, previews, local/server vault and downloads | `systems/character_lobby.gd` | Generic panels/lists. Original selection/preview/actions and download/connection lifecycle presentation. |
| Character creation | `systems/server_creation.gd`, `native_creation.gd`, `native_data/creation_rules.gd` | Server-table-driven native flow exists; original pages, widgets, help, recommended choices and all navigation states require parity. |
| Level-up | `systems/server_level_up.gd`, `native_level_up.gd` | Real server acceptance exists; generic form presentation and full page/control parity remain. |
| Party / portraits / health / HUD buttons | `systems/server_party.gd`, `native_party_frame.gd`, `native_status_bar.gd`, `native_game_desktop.gd` | Original frame/hooks/health/level overlay and fixed-self roster have scoped native-input acceptance. Locator/status/leader, group/associate/DM/disclosure variants, exact tooltips/fonts/input and original-client comparison remain open. |
| Quickbars and assignment menus | `systems/server_quickbar.gd`, `native_quickbar_frame.gd`, `native_game_desktop.gd` | Original model table/hooks/poses/font/count frame has scoped native-input acceptance. Full states, tooltips, alternate layouts, assignment families/variants and original-client comparison remain open. |
| Buffs / debuffs / action queue | `systems/server_buffs.gd`, `server_action_queue.gd` | Functional native widgets exist. Verify original placement, ordering, art, visibility, tooltips and cancellation feedback. |
| Chat, combat log and floating text | `systems/server_chat.gd`, `server_floating.gd`, `native_gameplay_ui.gd` | Native text handling exists. Audit original tabs/channels, formatting, controls, shortcuts, history and server feedback. |
| Context radial menus | `systems/server_radial.gd`, `native_game_desktop.gd`, `native_data/feat_radial.gd` | Original discs/hooks/icons and scoped actions verified. Full context/role trees, previews, preferences, rubber-band art and state/input parity remain. |
| Inventory / equipment / creature slots | `systems/server_inventory.gd`, `native_inventory*.gd` | Original layouts and scoped actions verified. Complete state/tooltips/drag/drop/font/scale audit remains; creature toggle stays in Options and defaults off. |
| Containers and inventory paging | `systems/inventory_repository.gd`, `native_inventory_frame.gd` | Original framing/grid and real transfers verified in scoped cases. All container/page/close/context variants still require acceptance. |
| Gold / amount controls | `systems/native_gold_transfer.gd` | Original dialog/drag and local transfers verified. Audit keyboard/hold/repeat/cancel, all destinations and failure states. |
| Merchant and confirmations | `systems/server_store.gd`, `native_store_frame.gd` | Original panels, tabs, grid, wording and real transactions verified. Original confirmation scrollbar artwork/basic input have scoped acceptance in [NATIVE-SCROLLBAR.md](NATIVE-SCROLLBAR.md). Repeat/step/font, callbacks and wider transaction variants remain open. |
| Player barter | `systems/native_barter*.gd` | Original panels and two-peer item/gold exchange verified. Mixed clients, stacks, range/control/area changes and full feedback/state coverage remain. |
| Examine / Identify | `systems/server_examine.gd`, `native_examine_frame.gd` | Original basic/item frame, carried-item icons/portraits and real paid/free identification have scoped acceptance in [NATIVE-EXAMINE.md](NATIVE-EXAMINE.md). Refusal, timeout, stale merchant generations and changed session cleanup are checked. Original scrollbar artwork/basic input have scoped acceptance in NATIVE-SCROLLBAR.md. Body formatting, repeat/step/font and wider target variants remain open. |
| Character record / abilities / skills / feats | `systems/server_character_sheet.gd` | Generic native layout with working data/actions. Recover original tabs, fields, icons, details, selection and all states. |
| Spellbooks, preparation and spell families | `systems/server_spellbook.gd`, `native_spellbook_frame.gd`, `native_game_desktop.gd` | Original main/memory/help framing, grouped class/metamagic/level views and47 native input checks are connected;99 existing local-server actions pass. Exact gestures/world drop, all preparation states, domains/spontaneous/roles, sorting and original-client comparison remain unaccepted. |
| Map and pins | `systems/server_map.gd`, `native_map_frame.gd`, `native_map_panbar.gd`, `native_map_note_editor.gd`, `native_game_desktop.gd` | Original generated frame, three zoom/icon levels, source pan controls/editor, explored-only tiles, retained placement and scoped native input pass. Original local server verifies GUI event target and stored personal-note add/edit/delete. Original-client visual/gesture/role comparison, DM teleport, reload/persistence and all variants remain open. |
| Journal | `systems/server_journal.gd`, `native_journal_frame.gd`, `native_data/journal_state.gd`, `native_data/journal_notes.gd` | Original native frame, retained record state, sort/expansion/timestamps, notes editing/persistence and local authoritative quest lifecycle pass scoped checks. World/DM journal routes, notes filename compatibility, complete original-client visual/input/role comparison and all states remain open. |
| Player list / party and attitude controls | `systems/server_players.gd`, `native_players_frame.gd`, `native_party_invitation.gd`, `native_data/players_layout.gd` | Original native frame/rows/source invitation popup, selection/Tell events, independent attitudes and party controls pass scoped native-input and actual two-peer server checks. Administrator/hosting availability and Boot/Ban, exact gestures/tooltips/fonts/default keys, wider role/disclosure/content/connection states and direct original-client comparison remain open. |
| Conversation | `systems/server_conversation.gd`, `native_conversation_frame.gd`, `native_data/conversation_layout.gd` | Original programmatic frame, speaker/portrait/fonts, sizing and reply ownership have scoped native-input/policy/local-server acceptance. Direct original-client comparison, large fonts, exact style/spacing, manager placement, role/secondary-count/cinematic/navigation variants and full parity remain open. |
| Targeting, cursor and area previews | `systems/server_targeting.gd`, `server_cursor.gd`, `native_game_desktop.gd` | Audit every original status/icon/preview/cancel/availability state and its interaction with windows. |
| Server NUI | `systems/native_nui.gd`, `nui_*.gd` | Native skin/protocol implementation has scoped evidence. All widget types, layout/bindings/events, draw states, resources, scrolling and interaction contracts require full audit. |
| Loading, connection errors and cancellation | `systems/native_loading_screen.gd`, lobby/browser owners | Functional loading/cancel work exists. Original visual conventions, progress, failure, transition and early-dismiss behavior require acceptance. |
| Unique diagnostics / inspector / exports | `systems/native_entity_inspector.gd`, render settings and native windows | Preserve their useful actions; replace generic presentation with a consistent native style. Verify optional separate debug-window/tab behavior. |
| Auxiliary popups, confirmation/input dialogs and tooltips | Shared owners plus call-site discovery | Inventory every caller and variant. Cover buttons, default/cancel keys, focus, stacking, long text, invalid input and retirement. |

This list was checked against the current desktop, gameplay UI, entry-menu,
settings, lobby/browser, store and examine owners. It is an initial audit, not a
claim that every original UI resource or action has already been enumerated.

## Required control record

For each surface keep: original resource/function evidence; supported modes and
server data scope; every control and state; input and action mapping; real
request/outcome/error evidence; visual artifacts and scale/crop checks; shared
window/input checks; remaining differences; and verified rollback checkpoint.
Keep appearance and behavior acceptance separate until both pass. Do not assign
an overall completion percentage from the number of existing widgets or tests.

## Preserved constraints

- Native Godot rendering and gameplay UI; JS is reference only apart from
  existing protocol/download services. Use active server resources and rules.
- Simultaneous movable windows, retained positions and correct front ordering.
  Preserve WASD, middle-mouse camera use and click movement outside menus.
- Creature slots default off, with their toggle in Options. Particles default
  off; Compact scenery remains opt-in. Keep performance diagnostics.
- Normal play shows the game, with optional debug tools separate from it.
- Owned local servers and sealed captures only; no automated Arelith/public
  connections. Preserve other games, original clients and manual sessions.
- Launch on a secondary monitor without taking focus or capturing/warping the
  physical mouse. Keep Windows-protected keys out of logs and checkpoints.
- Preserve verified backups at notable changes. Do not promote a drastic
  renderer/loading replacement without the previously required user approval.

## Work order

First establish the complete surface/control ledger and common original widget
rules. The Examine/Identify frame and action checkpoint is verified; finish its
original description formatting, wider font coverage and remaining scrollbar input rules without
expanding general gameplay. Then replace the remaining generic original-game screens,
starting with the frequently used HUD, character sheet, spellbook, dialogue and
entry/options flows. Audit all remaining and unique surfaces, then run the
cross-window/content/role/scale completion gate. General porting follows only
after that gate is fully satisfied.

Original bitmap fonts now have a scoped native checkpoint in
[NATIVE-BITMAP-FONTS.md](NATIVE-BITMAP-FONTS.md): framed caption binding,
source atlas/metrics, CP1252 shaping and local original-server action regression.
This does not complete the font, Examine or full-screen parity audit.

The next item-content step is scoped in
[NATIVE-EXAMINE-CONTENT.md](NATIVE-EXAMINE-CONTENT.md): original stat blocks,
inline localized fields, disclosure gates and server-owned armor category.
Exact original-client formatting and wider target/property states remain open.

[NATIVE-SCROLL-INPUT.md](NATIVE-SCROLL-INPUT.md) records the shared held-input
follow-up: original arrow/page timers, font-relative steps, body/rail wheel
agreement and focus-loss drag rollback. Partial-line page extents, all visual
states, GUI sounds and original-client comparison remain open. Continue the
larger screen inventory/layout work without treating this widget milestone as
full UI acceptance.
