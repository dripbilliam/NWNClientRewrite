# Native Change Key Settings — source rules and layout

This historical data-plan milestone recovers the original key-settings rules
and source layout. The [integration follow-up](NATIVE-KEY-SETTINGS.md) now adds
the visible page, persistence and supported input routes, including editable
hotbars. The full original action/UI audit remains open; data checks alone do
not accept a working window or complete UI parity.

## Original sources and behavior

Original executable SHA256:
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Read-only dossiers are preserved in
`../backups/animations/rea-native-key-settings-v1.json`,
`rea-native-key-settings-followup-v1.json` and `rea-native-key-tabs-v1.json`.
They retain provider identity, analyzed ranges, pseudocode and assembly without
the unrelated large p-code facets. No original process or profile was modified.

- `CKeyMappingPanel` constructor `1408b94d0` uses `options_key_pnl` and four
  `options_key_page` children. `options_controls` is a different legacy panel.
  The installed complete key panel is430×447 pixels, including a73px header.
  The `pages` attachment supplies the page position; root GUI editor positions
  are not screen positions. Native layout derives these dimensions from models.
- Rows37 through108 refer to named `ActionN` rows of the active `Keymap.2DA`.
  `ActionStrRef`, `Page` and `LanguageN` supply captions, tabs and defaults.
  Installed English has51 displayed rows. These are not a hardcoded action
  list or a restriction on a server's replacement resource contents.
- Original `C2DA::GetRowIndex` `1401a7330` uses the first case-insensitive row
  match; `GetINTEntry` `1401a6e00` also uses the first case-insensitive column.
  The native parser now retains raw physical `rowLabels`. Its existing numeric
  `rows`, physical/ordered cells, columns and defaults retain their semantics.
- Initial load `1408be080` selects a language column if it contains at least
  one nonnegative default satisfying the original remappable-key predicate;
  otherwise it uses Language0 globally. Saved `Keymapping/ActionN` entries
  override defaults. Ordered duplicate bindings clear the later displayed row.
- Defaults `1408befa0` is different: it uses the requested language if that
  produces any rows, including zero-only rows, and otherwise uses Language0.
  It does not suppress duplicate defaults. The installed two Tab rows expose
  that difference; do not unify these two population paths.
- Runtime rows use `CTL_OPT_BTN_KEY`, original401×32 artwork and35px vertical
  progression. The action caption uses `text`, left/middle alignment; the
  binding caption attaches to `label`, right/bottom alignment. Both use
  `fnt_galahad14`. `CGuiLabel` constructor `1401e80b0` and key-row model
  initializer `1408bdd70` establish the second caption's alignment.
- Selecting a row `1408bd0d0` begins capture, blanks its binding caption and
  colors the action caption(0.8,0.1,0.1). Capture completion `1408bf920` clears
  equal bindings in displayed rows across all four tabs, assigns the selected
  row and restores white text. Undisplayed actions and quickbar actions0..36
  are not part of that conflict scan.
- Original `AddEvent` `14016f880` captures the physical SDL scan on key-down.
  While capture is enabled it suppresses normal keyboard queue publication.
  `GetLastCapturedKeyboardScanCode` `1401703e0` searches native IDs40..105.
  Modifier state does not synthesize a chord in this path. Key releases do
  not assign; Escape is outside that capture range and Alt+Enter is reserved.
- `IsRemappableKey` `140170490` excludes74 and105. This is the language
  eligibility predicate, not the capture scan: native74/tilde can be captured.
  Slot105 has no initialized SDL mapping in this constructor. The offline
  observation fills uninitialized memory with a sentinel and does not turn it
  into a supported binding. Encoded stored defaults can still display Shift
  (high byte2) or Ctrl(high byte3) through formatter `1408bbce0`.
- Changing tabs `1408bc960` ends active capture before selecting the new page.
  Defaults also ends capture. Close and X `1408bcce0` commit all72 decimal
  Action entries, writing0 for absent actions. Cancel `1408bc4e0` and Escape
  `1408bc9f0` discard pending edits. Neither assignment nor Defaults writes
  the original profile before a commit.

## Native work and evidence

`systems/native_data/keymap_rules.gd` owns the source-backed data policy,
caption references, native physical capture translation, initial/default
population, pending conflict clearing and commit payload. The physical/native
key IDs and formatter references are original input ABI; action resources and
localization remain catalog data. It does not read the original user's INI.

`systems/native_data/key_settings_layout.gd` derives the two source frames,
four tabs, title, X, page buttons, list clipping, row progression and separate
caption anchors. Missing required controls/models/hooks fail explicitly.
Active GUI replacement tests relocate list rows and clipping together.

The parser's new metadata uses the existing session decode cache and catalog
forks.2DA derivative disk caching remains disabled. No unrelated cache purge
or global cache revision was introduced; existing running games are preserved.

`scripts/inspect-native-key-capture.py` executes unchanged original capture,
remappability and label-table setup instructions offline. Its retained oracle
contains3072 scan/enabled/modifier cases,256 native-code eligibility cases,
67 original label references and four release/reserved-key cases. Allocation,
OS preprocessing and queue boundaries are captured, not real OS keyboard input.

`scripts/inspect-native-key-population.py` executes the original caller's
initial/default population instructions in26 controlled cases. It captures
table/INI/language queries, strings, row creation and caption boundaries.
This verifies caller ordering, fallback, duplicates and override behavior;
it does not claim to execute actual C2DA parsing or render a window.

The named-row regression compares all five preexisting table fields against
the authored parser extracted and hash-verified from `native-video-options-v1.zip`.
All13 sealed captured tables retain those fields exactly; raw physical labels
are checked separately. Keymap checks also cover cached private consumers,
original integer field types after JSON conversion and active language cases.
Earlier compile/JSON-type comparison failures remain retained and excluded.

Final receipts and their current source hashes are indexed by
`tools/audit-native-key-settings-plan.mjs`. The backup retains authored native
source and offline research scripts; original assets/keys are excluded.

## Integration plan at the research milestone

User-required extension: **all36 hotbar shortcut keys must be rebindable**.
Keep F1–F12, Shift+F1–F12 and Ctrl+F1–F12 as defaults, not immutable keys.
Expose these entries in the native key-settings workflow with source-styled
controls, persistent replacement preferences and conflict handling across
normal actions and hotbar bindings. Preserve original active-page behavior for
unchanged defaults. A custom chord must activate its actual slot through the
existing authoritative quickbar request/targeting path. Rebinding a key must
not rewrite the server's shortcut contents. Test modified chords, all three
bars, unbound/conflicting keys, text-entry suppression, restart persistence,
Cancel/Defaults and capture suppression of movement/camera/other actions.
This extension is requested behavior, not a claim about original key settings;
the original four-page72-action list and its oracle remain separate evidence.

Create one native binding owner that loads the active catalog's Keymap and
TLK, owns replacement-only persistent preferences and pending transactions,
and routes bindings into actual implemented gameplay actions. Gate every
movement/camera/desktop/quickbar/highlight keyboard path during capture and
clear held movement when capture starts so releases cannot leave it stuck.
Preserve WASD and middle-mouse camera use while merely browsing menus.

Build the visible original page, source-art rows and scrollbar with these
native data plans, capture highlighting, source text metrics, tab changes,
Default/Close/X/Cancel/Escape semantics, drag/front ordering and retained
placement. Connect it to the real binding owner before enabling Options.
Do not expose cosmetic remapping controls whose corresponding gameplay input
still follows a separate hardcoded key handler.

Native UI input, actual local-server movement/action requests after reassignment,
restart persistence, focus/release/cancellation/stale-scope cases, all roles,
custom table/TLK/GUI variants, supported scales and direct original-client
visual/gesture comparison remain unaccepted. DM/host/other actions absent from
the current client remain explicit gaps. Malformed numeric/resource behavior
and original overflow quirks are not fully accepted by the controlled oracle.
Entire UI completion remains open; general porting stays deferred.
