# Character chooser automatic selection — partial parity

The later [focused edit follow-up](NATIVE-CHARACTER-CHOOSER-EDIT.md) implements
and validates the original focused Enter/Escape/Tab behavior. Its fresh receipts
supersede those input gaps below; this document retains historical evidence.

The native chooser now selects the first visible row when its logical character
catalog is rebuilt, including the pregenerated filter. Selection requests keep
their connection and nonce; rebuilding never submits Play. This completes the
first-selection follow-up identified in [cursor keys and titles](NATIVE-CHARACTER-CHOOSER-KEYS.md),
not the complete character chooser or UI.

## Original evidence and implementation

The original `140714a70` rebuilds the row controls, selects tab zero when the
list is populated, sets its double-click suppression flag at `0x1c78`, and calls
`140712440` for row zero. Its empty branch disables character actions instead.
Read-only evidence is retained in root
`backups/animations/rea-native-character-chooser-first-selection-v1.json`,
against original executable SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.

`systems/native_character_lobby.gd` separates logical catalog changes from late
TLK/table repaints, preserves explicit selections on repaint, resets the list
viewport on automatic selection, and defers requests while unavailable or hidden.
The pending intent is checked against its connection, catalog and visible keys.
Explicit pointer/cursor input, replacement and close retire obsolete intent.
An already selected initial first row does not duplicate its existing request.
Play remains disabled while selection is pending or its key is absent.

Automatic selection exposed an ownership problem in the local test driver:
an earlier preview's success must never authorize Play for a different character.
The diagnostic driver now waits for native chooser readiness and validates the
exact current connection, selected key and raw BIC SHA256. Its twelve actual
record-control checks must carry the same identity, alongside independent raw
BIC field/count expectations. The input probe checks chooser instance and
identity before every queued event and after waits. Retired tasks cannot publish
successful evidence. These JS additions validate diagnostics only; native Godot
still owns BIC decoding, rules, artwork and rendering.

## Verification and rollback

Current accepted receipts:

| Run | Checks | Scope |
| --- | ---: | --- |
| `native-auto-selection-chooser-graphical-v3` |31| Actual pointer/double-click/filter/New/Cancel, new connection and stale acknowledgment, text repaint |
| `native-auto-selection-keyboard-graphical-v2` |19| Cursor selection/scroll, pending acknowledgment, page return, 125% and input guards |
| `native-auto-selection-pages-graphical-v3` |32| Server/Player source pages, scrollbar artwork/input, held controls and replacement |
| `native-auto-selection-lifecycle-v2` |17| Hidden/unavailable/empty/replaced catalogs, no automatic Play and cleanup |
| `native-auto-selection-probe-scope-v2` |8| Real queued diagnostic clicks rejected after identity/owner changes |
| `native-auto-selection-local-v2` |207| Seven admission, eighteen real two-participant roster, twelve record-input and 170 gameplay/UI action checks |
| `native-auto-selection-menu-v1` |12| Native graphical entry/menu routes and prework cleanup |
| `tools/native-character-preview-proof.test.cjs` |17| Exact receipt accepted; stale/wrong/incomplete receipts rejected |

Total:343 scoped checks, with zero automated public connections. Graphical tests
used screen zero while the primary was screen two, without OS focus or mouse
capture. The local run used the original isolated server at `127.0.0.1:5125`,
validated native record input before Play, and verified actual server outcomes.
It closed both temporary BIC files, the second participant and its owned server.
The finished manual replacement session was closed with the user's permission;
original clients were not closed. Accepted native runs have unchanged source
pins, armed exception traps and no reported exception or engine/lifetime error.

`tools/audit-native-character-auto-selection.mjs` verifies the receipts, current
source hashes, original evidence and read-back-verified archive
`backups/native-character-auto-selection-v1.zip`. Historical numeric/skill/spell
oracle receipts remain documented in their earlier milestones; their counts are
not added to this follow-up's total.

The initial chooser/page/local attempts retained outdated assertions that no
selection request should occur after a rebuild or roster input. Those fixtures
were corrected to require the proper first-row request and reject Play; real
action/server requirements were preserved. The first lifecycle fixture also
failed because its next state incorrectly restored unavailability. Failed
receipts remain on disk, separate from accepted reruns.

The older headless Player List artwork failure remains recorded. The graphical
scrollbar checks now pass; this does not establish why headless preparation did
not complete. The separate retained native startup heap exception is still
unresolved. Passing these runs does not establish full startup stability.

## Remaining requirements

Enter/Escape/Tab and base-edit behavior, complete rebuild/rejection states,
pregenerated persistence and local metadata/Delete/Customize, all record modes,
sound, source role/state variants and direct original-client visual/gesture
comparison remain open. Source artwork is displayed and input is tested; exact
appearance across scales is not accepted by these screenshots alone. Full UI,
character chooser and stability parity remain unaccepted. Continue the active
[complete UI goal](NATIVE-UI-PARITY-GOAL.md) before general porting.
