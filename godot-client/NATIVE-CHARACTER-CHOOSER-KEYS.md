# Character chooser cursor keys and title — partial parity

Subsequent validation and first-row implementation are recorded in
[automatic chooser selection](NATIVE-CHARACTER-AUTO-SELECTION.md). That follow-up
supersedes the pending graphical/local and first-selection items below, while
retaining this milestone's historical receipts and failures.

The native chooser now handles the original previous/next character cursor
keys through its existing scoped selection requests. Its record caption now
includes the original localized `Character Record, ` prefix. This is another
UI parity step; the complete chooser and UI audit remain unfinished.

## Original source and behavior

Original binary SHA256:
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Root `backups/animations/rea-native-character-chooser-keys-title-v1.json` retains
the CPlayModulePanel constructor/setup, embedded UpDownKeyHack control, key
handler `140710a90`, selection/scroll callback `14070f3c0`, preview selection
`140712440`, local record constructor and title path `14088b180`.

The original key handler maps0x125/0x126 to minus one and0x127/0x128 to plus one,
then forwards to the base edit. The Windows-style cursor-code grouping maps to
Left/Up and Right/Down, consistent with the earlier native server-list control.
The callback clamps to the list ends, invokes ordinary selection/preview, and
requests a one-row pixel-scroll adjustment only when the next row is outside
its viewport. Actual scroll-range clamping remains with the GUI range owner.

`native_data/character_lobby_keys.gd` implements that policy. The native owner
uses the current pending key when acknowledgments lag, returns from Server Info
or Player List to Character, and sends the existing `lobby-choose` request with
its connection and nonce. Matching received state enables Play. Cursor input
never invokes Play. Empty, unavailable, hidden and separately focused controls
cannot submit character selections. Internal Godot GUI focus follows the
original hidden-edit ownership; this does not activate the OS window, capture
the mouse or read another application's keyboard input.

The original local record constructor reaches `14088b180`, which fetches
TLK61826 and formats the record title with the character name. The native title
now follows that path and refreshes when active TLK data changes. The local
test driver's caption comparison was updated while preserving its independent
raw BIC hash, abilities/classes/count checks and selection ownership. Its record
input probe now also waits for numeric/detail dependencies. Neither request
validation nor the real server-outcome requirements were removed.

The older preview-frame test still described the superseded raw HP/description
view. It now supplies the proper typed MaxHitPoints/PregameCurrent/ArmorClass
and CombatInfo fields, checks generated details, rejects the interim description
and verifies late title/class/detail TLK updates without another BIC parse.

## Verification

`scripts/inspect-native-character-chooser-keys.py` executes unchanged original
key dispatch and selection/scroll arithmetic. Tab selection, preview rendering,
slider reads, registration and base-edit handling are captured GUI boundaries.
Its192 populated-list cases cover both ends, deselection, cursor/non-cursor
keys and partial viewport positions. Observation file:
`backups/animations/native-character-chooser-key-observations-v1.json`.
The empty-list refusal is a native boundary guard, not a claimed successful
original selection of an absent row.

Current source-pinned headless receipts share prefix
`native-character-chooser-followup-`:

| Suffix | Checks | Scope |
| --- | ---: | --- |
| `key-policy-v1` |386|192 original dispatch/bounds/scroll comparisons and empty guard |
| `keyboard-v1` |19| Actual cursor input, pending/stale/matching acknowledgments, scroll/reveal, page return,125%, focus/hidden/busy/empty guards |
| `preview-v1` |13| Native raw BIC to original controls, updated fields and localized title/class/detail refresh |
| `chooser-v1` |23| Existing pointer/double-click/New/Cancel regression |
| `stats-v1` |25| Numeric/detail controls, font/scroll, active race/BAB/TLK refresh and retirement |
| `phase-v1` |20| Pregame/gameplay visibility and input isolation |
| `numbers-v1` |802| Earlier original numeric/type/default regression |
| `details-v1` |225| Earlier complete original pregame detail-output regression |
| `worker-v1` |24| Native preview integrity/selection/worker lifetime regression |
| `skills-v1` |373| Earlier original skill import/calculation regression |
| `spells-v1` |296| Earlier original spell import/enumeration/gain regression |

Total:2,206 scoped checks, under exception traps with zero public connections
and current source/lifetime validation. The visible manual client is preserved.
The updated entry script also passed a headless parse check. Graphical and fresh
authoritative local admission checks are still required for this source.

`native-character-chooser-followup-pages-v1` is retained as a failed headless
attempt:28 checks, with Player List scrollbar artwork readiness and its arrow
step failing. The artwork did not become ready headlessly. This result is not
accepted, is not counted above and must be rerun graphically; its exact runtime
cause is not established by this test. The original separate native startup
heap exception remains unresolved as well.

## Remaining work

The original populated rebuild automatically selects row zero and sets a
double-click-suppression flag. This is confirmed in
`rea-native-character-chooser-first-selection-v1.json` but remains unported.
That change also requires adapting the local observer/driver to verify the
current selected BIC receipt, rather than treating an earlier automatic
preview's success as permission to play another character.

Other remaining requirements include Enter/Escape/Tab and base-edit behavior,
automatic selection and filtered rebuild/rejection states, pregen persistence,
local metadata and permitted Delete/Customize flows, original sort/row states,
all title/disclosure/empty-portrait variants, sound, direct original-client
appearance and gesture comparison, graphical Player List regression, and fresh
owned-server outcomes. Full chooser/UI and stability parity remain unaccepted.
The rollback archive and scoped proof are verified by
`tools/audit-native-character-chooser-followup.mjs`.
