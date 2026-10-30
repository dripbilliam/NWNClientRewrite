# Character selection without gameplay setup

The reported screen was the prototype lobby, left visible until
`native_session_world.gd` could configure the original chooser from a fully
mounted server gameplay catalog. The user observed approximately25seconds.
That live run had no detailed capture of the intervening work, so the exact
division between server resource readiness, catalog mounting and model/font
preparation is not established by that report.

The pregame UI does not require server gameplay resources. Normal startup now
prepares the original chooser as soon as the independent installed/user-enabled
pregame catalog is published, while Main Menu is open. This includes the
original roster button's unchecked/checked/pressed/disabled artwork before any
roster rows exist. That prevents the first server reply from initiating a second
batch of roster-button preparation.

## Stable frame, changing data

The original GUI/MDL layout, window geometry, fonts and controls stay attached
to the pregame painter. Server resources never replace this frame before world
entry. `character_lobby.configure_native` rebinds only the following data when
the active server context becomes available:

- Native rule-table requests and record projections.
- Active class/feat/skill/spell/portrait tables and custom text.
- Dynamic character/player portraits and feat/spell icons.

`native_character_lobby.bind_data` owns a separate bounded rule asset service.
It cancels/drains retired rule work and invalidates record/caption projections
without replacing controls, resetting the logical character catalog, changing
the selected key, or bypassing selection acknowledgments. The shared original
frame and its GUI model request count remain unchanged. Dynamic images borrow
the active data-art owner, while GUI artwork stays on the installed painter.
Old portrait bindings are invalidated so late installed-image replies cannot
overwrite an active-source portrait on the same control.

Server-vault rows can be presented from the received roster independently of
gameplay setup. Local-file selection still waits for active local metadata and
classification tables. Details can remain pending; their preparation does not
replace the whole screen. A connection change still retires its data work.

The normal chooser is restored/prepared again from the pregame owner after
connection reset. Main Menu remains the startup destination. There is no
automatic public connection or character admission.

## Cold preparation and diagnostics

If character selection is reached before its first native preparation finishes,
the lobby shows a short preparation status with the real scoped Cancel action.
It never exposes the prototype character list and buttons for this phase.
Once ready, later data/image updates do not return the screen to preparation.

The shared builder's source-readiness check considers that view's static GUI
images, font bindings and original button states. Dynamic portraits and unrelated
gameplay asset jobs do not gate its readiness. Startup's real `endpoint=null`
state is accepted by the hidden Server Info page before a server is selected.

Engine logs now include `NATIVE_CHOOSER_PREPARE`, `NATIVE_CHOOSER_READY` and
`NATIVE_CHOOSER_DATA_BOUND`, with process-relative ticks. Server setup logs
separately record receipt, catalog mount time and gameplay UI configuration
time. These make the next live wait attributable without claiming that the
unprofiled25second observation was completely measured.

## Local evidence

Final current-source graphical receipts:

- `native-lobby-prewarm-independent-final-v1`:17 checks. Prepares the original
  chooser with no GameplayUi or server setup; checks cold cancellation, actual
  pointer selection/Play while rule publication is deliberately held, custom
  server class text, stable frame/button identities, unchanged GUI requests,
  selection ownership and worker retirement.
- `native-lobby-prewarm-frame-final-v1`:31 original frame/input checks.
- `native-lobby-prewarm-preferences-final-v1`:26 preference/filter checks.
- `native-lobby-prewarm-keyboard-final-v1`:19 original keyboard/selection checks.
- `native-lobby-prewarm-pages-final-v1`:32 server/player page checks.
- `native-lobby-prewarm-record-final-v1`:28 original record/stat checks.
- `native-lobby-prewarm-feats-final-v1`:61 original feat/skill/spell record and
  retained native-oracle checks.

The actual launcher run `native-lobby-prewarm-startup-v2` opens Main Menu,
prepares the chooser without a server setup, exercises the existing menu/prework
checks, and exits with no native/lifetime error and zero public connections.
Together these are214 native UI checks plus a separate complete launcher check.
`tools/audit-native-character-frontend.mjs` verifies their pinned sources and
rollback manifest. These are local functional checks, not an Arelith latency
benchmark, a connected-server acceptance, or complete UI parity.

An initial staged-frame implementation was discarded following the user's
clarification that server resources do not replace pregame UI. Its intermediate
receipts are historical. Other rejected runs exposed missing roster prewarming,
an invalid freed-node capture in a test, and the disconnected null endpoint.
A feats invocation omitted its required oracle and did not execute its checks;
the final oracle-backed run above supersedes it.
