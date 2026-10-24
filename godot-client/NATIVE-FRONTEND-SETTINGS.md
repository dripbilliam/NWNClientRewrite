# Native Main Menu, settings and separate debug window

Status: **native Main Menu/settings/debug core implemented and locally verified;
full UI migration remains incomplete**. UI, then rendering, then combat remains
the user-directed work order. No Arelith connection was used.

The bottom-right Main Menu opens native Multiplayer, Options, Return to game and
Exit controls. Options is also reachable from the party HUD. Its Game tab retains
the options-only creature equipment preference, adds a compact FPS counter
preference, and opens a separate native OS debug window. The admitted world no
longer displays the outer prototype status/debug overlay. Startup uses a dark
background and keeps game chat hidden until admission; existing chat is retained.

The Mods and CD key tab uses `tools/settings-service.mjs` with the existing
`ClientSettings` and Workshop backend. It displays the detected default Workshop
folder, offers Browse and Use default, and lists per-mod enabled checkboxes.
Folder selection scans a draft; Save persists the selection. Enabled HAKs remain
global local content, below selected server content in the existing resolver's
search order. Resource changes require disconnection and apply on the next
connection. Key replacement/removal remains independent of mod changes.

The key editor is masked and bounded. Saving, closing or reconnecting clears the
native draft. Only safe metadata returns to Godot; neither protected ciphertext
nor the saved plaintext key is exposed. Persistence reuses Electron safeStorage
on Windows in the existing application profile, with the existing format and
atomic writer. An in-flight save disables conflicting controls; reopening waits
for that commit instead of publishing stale metadata. Private catalog handles,
connection/view guards and queued store writes prevent stale selections from
changing a replacement owner. Closing the client drains an in-flight protected commit before shutdown. Failure notices do not echo submitted key text.

The native debug Window has Performance, Gameplay, Diagnostics, Inspector and
Resources tabs. It is nonmodal, owns its OS window, restores its geometry, and
returns focus to the game when closed. Closing also updates the persisted Options
toggle. It samples only while visible. Frame interval statistics are distinguished
from GPU timings; Godot render totals include all viewports, including debug UI.
A bounded diagnostic ring continues beyond the retained test report's limit and
aggregates repeated messages. It projects code/reason/count/time, not arbitrary
context or credential objects.

## Evidence

- `reports/native-settings-local-v4.json`: 25 native UI/Windows-store checks,
  with no NWN server admission. This uses authored catalogs and a separate
  temporary credential store, **not the user's saved key**. Real safeStorage
  encryption/decryption, store recreation, key removal and per-mod persistence
  pass. The real application's `client-settings.json` is hash-verified unchanged.
  The original resolver finds the enabled authored HAK resource and rejects the
  disabled one. Debug rendering uses an OS window distinct from the game root.
- `reports/native-settings-party-local-v3.json`: **34 +35 live local checks**
  across saved-character reconnect and six rendered/animated area admissions.
  Connected settings report resource locking, the world frame has no outer debug
  overlay, the separate debug window receives actual playing state, closing it
  returns to a working Options toggle, and the FPS preference controls the compact
  counter. Existing membership, portrait spell targeting/consumption, radial
  examination, MMB/WASD and two A–B–A cycles pass. No settings mutation is recorded
  in these real-profile game sessions. Old backend jobs/world owners retire,
  native exit is0, and no renderer/native-script error is recorded.
- `reports/settings-ui-native-v5.json`: **20 authored native GUI checks**,
  including masked input, immediate draft clearing, empty catalogs, locked
  resources, old-view rejection, persisted debug toggle, Main Menu routing,
  five native tabs and stopped sampling after the window hides.
- `reports/native-main-menu-exit-v2.json`: normal Main Menu Exit before admission closes the native process with exit0 and no errors; its settings owner retires with no pending save. This is explicitly frontend-only evidence and does not satisfy admitted-gameplay acceptance.
- Related native party/buff/NUI GUI regressions pass **18 /17 /15** checks in
  `settings-party-ui-regression-v1`, `settings-buff-ui-regression-v1` and
  `settings-nui-ui-regression-v1`. Engine logs are clean.
- `reports/native-settings-node-regression-v3.log`: **119 tests pass** for
  settings/store/Workshop behavior, pending commit/reopen, private-handle and
  connection guards, safe fixture cleanup, diagnostics bounds/aggregation,
  IPC/resource ownership, the original client's packet oracles and existing
  party/action behavior.

Rendered Main Menu settings, the separate debug Window, and the admitted game
frame were reviewed. Screenshots are `native-settings-local-v4-settings.png`,
`native-settings-local-v4-debug.png`, and
`native-settings-party-local-v3-c3-party.png` in the project root.

The shared IPC change adds one main-process-only lobby-cache invalidation method;
it leaves active session resource owners intact. The corresponding regression
is added to `test/network-ipc.test.js`. Removing those additions reproduces the
previous pinned source hashes, including line-ending normalization. The main JS
entry point, built client and all other reused resource/settings modules remain
unchanged. Checkpoints now include related authored test sources as well as
src/electron files, with the same path/link and archive read-back validation.

Rejected evidence is retained. The first live party regression expected Examine
at the root of an owned companion's wheel. Fully received associate metadata
correctly moves it under Associate actions. The probe now traverses that original
child layer; it does not force a different menu policy. A subsequent visual review
found that focus needed returning from the separate debug window before another
party control click. Closing debug now focuses its parent, and both live sessions
verify the Options close action. Earlier reports remain distinct from the final
accepted lifecycle report.

## Remaining scope

Main-menu artwork/native font fidelity, broader browser/history/favorites and
character creation, offline New/Load/startup, sound/music/voice presentation,
installation selection, remaining graphics/scripted-camera/feedback preferences, full interactive debug
tools and richer inspector controls remain pending. The debug inspector is
currently a read-only projection of received objects. Large catalogs, exhaustive
failure/permission branches, native folder-picker physical-device interaction,
multi-monitor/DPI geometry and exact visual/device parity need broader coverage.

These were functional checks with the project editor preserved. The FPS displayed
in the small authored room is not a clean benchmark and does not accept sustained
moving captured-world performance. Rendering and combat parity remain unfinished.

The creator staging build v30 also passes `reports/native-creation-settings-regression-v3.json`:25 real Windows native-control/store/window checks, no NWN admission, original credential/mod profile unchanged. This live persistence regression uses native button signals to avoid concurrent OS mouse interference; the authored GUI pointer checks remain separate evidence. The hidden DOM lobby is retired before login; original production frontend code is preserved.

The NUI cross-feature regression subsequently found that globally disabling
embedded subwindows to obtain the separate debug window also changed ordinary
gameplay dropdowns and color pickers into OS popups. The project now embeds
ordinary popups and `native_debug_window.gd` explicitly hides and marks only
diagnostics `force_native` before entering the tree. The ordering matters:
changing that flag while the Window's default visible property is true emits
an engine error; the rejected local v2 report retains that failed attempt.
`reports/nui-window-settings-rendered-v1.json` passes21 actual Vulkan checks,
including an embedded parent with a separate nonmodal native debug Window.
`reports/nui-window-popup-rendered-v2.json` passes17 popup checks using the
production project setting, with no test-only embedding override. Both logs
are clean. See [NATIVE-NUI.md](NATIVE-NUI.md) for the local server regression.
`reports/native-nui-window-settings-local-v1.json` also passes25 existing actual
Windows protected-store/workshop/debug checks with no game-server connection
and the original user settings unchanged. The corrected local NUI run passes
57 +59 checks across six animated area admissions and saved-character reconnect.

[Combat feedback Options](NATIVE-FEEDBACK-OPTIONS.md) now adds persistent native
floating-feedback and total-only damage controls, live original formatting,
independent script prompts and current-connection acknowledgements. Twenty
actual local checks, ten new native GUI checks, the 21 existing settings GUI
checks and 122 backend regressions pass. Broader graphics/audio/debug Options
and full fidelity/performance remain open.

[Native camera modes](NATIVE-CAMERA-MODES.md) adds persistent Top-down, Chase
and Stiff chase through actual native dropdown input, original follow/rate
calculations and area-safe manual view preservation. The current test passes
23 local camera checks across three animated admissions, 24 native GUI and
139 backend checks. Scripted camera commands, collision/clear-view behavior
and broader Options remain unfinished.

[NWSync](NATIVE-NWSYNC.md) now has native manifest/download/cache counters,
pre-world cancellation, failure feedback and retired-progress rejection. Four
actual local scenarios cover cancellation, cold/cached/repair admission; the
native downloaded texture is verified. Twelve new GUI, 20 existing lobby and
187 backend checks pass. This does not enable public-server endpoints.
