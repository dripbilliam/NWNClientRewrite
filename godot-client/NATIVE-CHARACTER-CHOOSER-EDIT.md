# Character chooser focused edit — partial parity

The subsequent [pregenerated preference follow-up](NATIVE-CHARACTER-PREGENERATED.md)
implements the persistence item identified below. Local metadata and full
chooser/UI parity remain unfinished; earlier receipts here are historical.

The native chooser now consumes focused key presses like the original hidden
`CPlayModuleUpDownKeyHackControl`. Enter, keypad Enter, Escape and Tab do not
fall through to unrelated menus, chat or Godot focus traversal. Cursor keys
continue to select and scroll through the existing acknowledged requests.

## Original behavior

Original binary SHA256:
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Root `backups/animations/rea-native-character-chooser-edit-input-v2.json` retains
the constructor, setup, per-frame focus restoration, GUI dispatch and base edit
functions. The original chooser setup focuses its hidden edit; its cursor
override `140710a90` always forwards to `CGuiEdit::HandleKeyPress` at `1401e99b0`.

The base edit returns handled for key presses. Enter becomes a newline and
invokes the submit callback; Escape invokes the cancel callback. Both callbacks
start at the original no-op `1401e58c0` and the chooser does not bind them during
setup. Tab queries Shift and follows its next/previous edit pointer only when
assigned; both pointers start null and remain unassigned in this chooser.
Thus these keys do not mean Play, disconnect or a Godot-selected next control.
The original GUI manager directs key presses to its focused object.

`scripts/inspect-native-character-chooser-edit.py` executes unchanged original
constructor, cursor override, base edit and empty callback instructions. String
allocation/virtual operations, object construction, Shift query, cursor callback
and focus service are captured boundaries. Its64 unique key/Shift/link cases
are retained in `native-character-chooser-edit-observations-v2.json` under root
`backups/animations`. The configured-link cases prove the base edit's conditional
focus path; they do not claim the actual chooser has such links. The earlier
v1 observation contains a duplicate Home case and is retained separately.

The native implementation consumes pressed GUI keys while the visible chooser
has focus, before checking cursor-selection availability. This also protects
empty and temporarily unavailable choosers. Another focused control and a
hidden chooser retain their separate ownership. The invisible original text
buffer's insertion/cursor internals are not reproduced: they have no visible
text or bound submit action in this control. This is scoped externally visible
input parity, not a general implementation of every original CGuiEdit mode.

## Verification and rollback

`native-chooser-edit-before-v1` reproduced23 failures before the correction:
focused edit keys escaped ownership, including unavailable/empty and scaled
cases. It reported no exception or engine/lifetime failure. The receipt is
retained, not counted as accepted evidence.

| Accepted run | Checks | Scope |
| --- | ---: | --- |
| `native-chooser-edit-graphical-v1` |94|64 original constructor/key observations plus actual key input, adversarial Godot Tab neighbors, unrelated text focus, hidden/busy/empty and125% cases |
| `native-chooser-edit-cursor-graphical-v1` |19| Actual cursor requests, delayed/stale acknowledgment, scroll, page return, scale and ownership regression |
| `native-chooser-edit-local-v1` |207| Seven admission, eighteen two-participant roster, twelve native BIC record-input and170 authoritative gameplay/UI actions |

Total:320 scoped checks. The local probe now presses Enter, keypad Enter,
Escape and Tab and checks that the chooser retains focus with no menu/chat,
gameplay window or character submission. It then exercises real server roster
updates, preview input, admission and gameplay. Existing authoritative action
requirements were retained. Accepted runs have current source pins, exception
traps, zero automated public connections and no reported native exception.
Graphical tests use a secondary screen without OS focus or mouse capture.
The isolated original local server and its participant are cleaned up, including
both temporary BIC files. Original clients were not interrupted.

`tools/audit-native-character-chooser-edit.mjs` verifies current source, original
evidence, the before/after regression and the read-back-verified rollback archive
`backups/native-character-chooser-edit-v1.zip`.

## Remaining work

Pregenerated preference persistence is next. Original constructor `140708660`
reads `game.character-generation.show-pregenerated`, and destructor `14070a6b0`
writes the current boolean with `CExoConfig::Set<bool>`. Callback bytes at
`14070ffc0` store the value then jump to the row rebuild. Evidence is retained in
`backups/animations/rea-native-character-pregen-persistence-v1.json` at the
workspace root. It is not implemented or accepted by this keyboard milestone.

Local metadata and permitted Delete/Customize, full rejection/rebuild states,
all record modes, sounds, original-client visual/gesture comparison and wider
scale/role coverage remain unfinished. The earlier separate startup heap
exception and headless Player List artwork failure remain unresolved; green
graphical/local runs do not prove either fixed. Complete chooser, UI and startup
stability parity remain unaccepted. Continue [the full UI goal](NATIVE-UI-PARITY-GOAL.md)
before general game porting.
