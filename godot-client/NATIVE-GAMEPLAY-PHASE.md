# Pregame and gameplay presentation ownership

The active native catalog prepares one gameplay UI owner early. Its painter,
fonts and native TLK/2DA readers are also borrowed by the independent original
PRE_PLAYMOD character chooser, character creator and loading screen. Preparing
those shared resources must not display the gameplay chat/HUD or enable gameplay
shortcuts before admission.

`native_gameplay_ui.gd::set_gameplay_visible` now gates the gameplay CanvasLayer,
including directly attached NUI windows, and both independent context-wheel
CanvasLayers. It retires gameplay text focus and disables hidden canvas input
trees and the sibling shortcut/cursor input owners. Shared resource workers and
received-state preparation continue. The creator and chooser have independent
canvases and remain available. The gate does not clear window placements, the
chat draft or authoritative state. Hidden gameplay UI contributes no pointer
blocking region.

The live renderer starts the gameplay canvas hidden and explicitly hides it
before each new area generation. The first reveal requires the controlled model
to be ready and the loading overlay's input gate to be released. The session
additionally requires the received `playing` phase; sealed offline replay has an
explicit exception to the live-lobby requirement. Once revealed in the same
area, later appearance/reference preparation does not withdraw the HUD or steal
chat focus. The existing Ctrl+Shift+L loading-screen dismissal remains
presentation-only and cannot fabricate controlled-model readiness. Ordinary
authoritative server admission gates and requests are unchanged.

The session's renderer status/debug text is now limited to an existing world
with detailed profiling enabled. Pregame source screens own their statuses;
they no longer show a stale “Indexing native game and server resources…” label.
This is not an implementation of the still-required separate debug-tool window.

Original reference: the chooser resource/controller ownership is recorded in
[NATIVE-CHARACTER-LOBBY.md](NATIVE-CHARACTER-LOBBY.md) (CPlayModulePanel7143f0,
PRE_PLAYMOD and the attached record pages). The source gameplay frame/HUD
inventory is in [NATIVE-UI-PARITY-GOAL.md](NATIVE-UI-PARITY-GOAL.md). This change
corrects the replacement's sharing/lifetime error; it is not evidence of full
original-client phase, gesture or visual parity.

Verification receipts:

- `native-gameplay-phase-graphical-v2`:22 checks using real original-resource
  preparation, native viewport keyboard/pointer events, separate chooser and
  creator presentation, hidden active wheels, focus release, retained placement
  and draft. The chooser screenshot was reviewed; gameplay chat is absent.
- `native-gameplay-phase-headless-v4`:20 matching non-rendering checks.
- `native-gameplay-phase-policy-v1`:17 cases against the actual inherited
  renderer/session predicate, including loading, received phases, appearance
  preparation, replay and closure. These use authored readiness owners, not a
  simulated server outcome.
- `native-gameplay-phase-startup-v2`:12 original-resource startup/menu routes.
- `native-gameplay-phase-local-v2`:18 live roster/pregame checks,7 native
  admission and170 unchanged gameplay checks against the owned original local
  server. The roster observer has not submitted a character; admission is checked
  separately. Final gameplay diagnostics must show the canvas and chat visible.
- The six session/roster/discovery/private-participant service files are rerun by
  `tools/audit-native-gameplay-phase.mjs` (46 checks).

The acceptance audit verifies current source pins, native debugger receipts,
window/worker lifetime, owned endpoint and rollback hashes. The final set is312
scoped checks. It cannot establish entire UI parity. The first headless attempt
was unable to read the original installation under restricted permissions and
produced setup errors. The next headless attempt incorrectly required rendered
model artwork with no renderer; that retained failure led to checking artwork in
the graphical run, while the headless suite retains the canvas/input cases.
Earlier receipts remain as development history rather than final acceptance.

Remaining: source chooser record artwork still has visible gray bands/seams and
unverified proportions; complete original comparison is required. Local BIC
metadata/pregeneration, local editing, automatic/keyboard selection, remaining
record fields/Skills/Feats/Spells, late custom-text invalidation, role/font/scale/
audio states and the rest of the UI inventory remain unfinished. This test does
not prove every real multi-area transition, possession/death/reconnect variant
or original-client comparison. The prior intermittent blood-pixel failure and
pending-wind warning remain open; no particle fix is claimed here. The full UI
goal stays active, and general game porting stays deferred.
