# Native Multiplayer entry — partial UI migration

The Main → Player Name → Multiplayer → Direct Connect / Internet navigation
now uses the installed original `PRE_MULTIPLAYER` owner. This is a scoped
navigation and native presentation milestone. Full UI parity remains unproven.

## Original evidence and implementation

Original client SHA256:
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Read-only dossiers are retained outside the source checkpoint under
`../backups/animations/rea-native-multiplayer-entry-v1.json`,
`rea-native-multiplayer-direct-return-v1.json` and
`rea-native-multiplayer-browser-return-v1.json`.

- Main710fd0 skips Player Name when the application already has an identity.
  The service now distinguishes an accepted session identity from a configured
  default. Fresh settings no longer invent a default account. Older settings
  without the explicit default field migrate their old name once.
- Constructor708290 / initializer713510 load `PRE_MULTIPLAYER` and bind New,
  Load, Internet, LAN, Direct and Cancel. `entry_menu_layout.gd` resolves that
  original GUI/model/caption data through the independent native pregame catalog.
  Six source buttons replace the omitted intermediate menu.
- Direct710480 retains the parent. Continuation7137e0 retires it only for result4;
  other returns dismiss the child. Native Direct Cancel now returns to Multiplayer
  with the source parent behind the modal. A viewport shield blocks click-through.
- Cancel70f740 clears the session identity only when the configured default is
  empty. Native Cancel explicitly requests this policy and returns to Main.
- Original browser Cancel8cded0 stops all discovery sections and enumeration,
  destroys the browser and recreates Multiplayer. Native Back/Escape now issues
  `return-menu`: abort providers, retire their epoch, preserve the accepted name
  and return a fresh idle view. Cancel can overtake a busy-view acknowledgment,
  but an earlier opening's handle cannot cancel the new owner. Late provider
  successes and abort rejections cannot restore rows or emit a stale error.

The existing command pump already gives browser controls an interruptible lane;
no new rendering worker or JS presentation was added. Native Godot owns the
artwork, fonts, controls, modal ownership and input. The existing JS service owns
the protocol, endpoint policy and saved browser settings.

An empty name on the generic Direct route first opens Player Name, then resumes
Direct after acknowledgment. Failed admission returns a standalone original OK
notice over Multiplayer, preserving the backend refusal. Unencodable ports and
overlong wire fields receive a visible notice before sending a request. Pending
profile storage blocks input with a shield without displaying the source
checkbox's misleading disabled X when Save As Default is unchecked.

## Verification and rollback

`native-multiplayer-entry-v3` checks35 native graphical/input/lifetime cases,
including busy-browser Escape, modal returns, authoritative fake refusal messages,
stale held presses, wire-bound rejection and profile-to-Direct resumption. Menu
and modal viewport PNGs were visually reviewed in the v2 run; v3 retains that
geometry and adds busy cancellation input. The graphical window uses a secondary
display with unfocusable=true, focused=false and mouse mode0. No physical input
is synthesized.

`native-multiplayer-service-v3.tap` records37 service/protocol tests. The added
provider tests use deferred query/discovery adapters through the actual command
pump; no Internet discovery occurs. They cover immediate abort, late completion,
abort rejection, accepted-name retention and rejected old/missing/future handles.

`native-multiplayer-entry-startup-v3` must pass the full graphical startup check
with the unchanged20-second watchdog, original art gate, ten entry routes and
both prework cancellation checks. `native-multiplayer-entry-local-v3` must pass
native Profile → Multiplayer → Direct admission and170 authoritative checks
against the owned original server at127.0.0.1:5125. These final receipts and current
source hashes are enforced by `tools/audit-native-multiplayer-entry.mjs`.

Rollback: `backups/native-multiplayer-entry-v1.zip` with its verified manifest.
The acceptance audit checks every archived source digest against the workspace.
It must not report the entire UI, migration or rendering goal complete.

## Required follow-up

New/Load hosting and LAN discovery remain disabled with explicit explanations;
they are missing functionality, not matched role behavior. The generic browser
still needs its original five-page panel, list/details/filter controls, server
password and CD-key/connection dialogs. The original page/Cancel/filter dossiers
are starting evidence, not acceptance of those screens. In particular original
filters include empty/full/module-name options absent from the current form.

Original side-by-side visual comparison, additional resolutions/scales, DM and
host roles, backdrop scene, exact disabled/hover/pressed states, GUI sound,
clipboard/IME/caret/password details and the remaining complete UI ledger stay
open. The owned server regression proves original-compatible actions in its test
module, not every server's gameplay or every navigation role. No public or
Arelith connections are authorized for automated tests.
