# Whole-number game displays

User policy: game values use whole numbers; diagnostics and settings retain
precision. Version strings, names, server-authored chat/descriptions and explicit
server NUI formatting stay as supplied. This is a presentation policy, not a
change to protocol fields, movement/combat calculations or stored values.

`systems/native_data/game_numbers.gd` formats known game-value fields. Finite
numbers and numeric rule-table strings truncate toward zero, matching the
existing inventory whole-pound display. Missing/nonfinite numbers show the
caller's unavailable marker. Count markers such as infinity and `3/5` survive.
`tenths` converts examine's network weight units to pounds before truncation.
Do not run arbitrary rich text, version strings or diagnostic values through it.

Remaining direct JSON-float display paths corrected:

- Native/fallback examine facts: charges, weight, value, required/player level
  and challenge rating. Original inline item examine also uses whole-pound
  weight, intentionally overriding its original decimal-weight presentation.
- Shared spell slots, including spellbook and quickbar counters; radial counts
  and their use-count tooltips.
- Character-sheet numbers and numeric rule strings; projected class levels,
  arcane-failure percentages and armor penalties.
- Attack-roll, confirmation-roll and concealment-percentage TLK tokens.
- Fallback character-preview HP, XP, class IDs/levels and abilities.

Inventory/equipment AC, gold, capacity/weight, stack counts, store prices,
party HP, skill ranks, journal dates and the original chooser's numeric cells
already use integer casts/projections or `%d`. The browser integer follow-up is
documented in [NATIVE-BROWSER-RESPONSIVENESS.md](NATIVE-BROWSER-RESPONSIVENESS.md).
Server-defined NUI `number_precision` remains authoritative; it is not treated
as a client-formatted gameplay statistic. No global decimal-stripping occurs.

## Validation

Six local receipts, 154 checks, with source hashes pinned by the native debugger
wrapper and no engine/lifetime errors:

| Receipt | Checks | Coverage |
| --- | ---: | --- |
| `native-game-numbers-current-v1` | 21 | Real JSON floats, truncation, unknowns, count controls, custom classes, immutable data, fallback preview, server NUI precision |
| `native-game-numbers-feedback-current-v1` | 18 | Original combat TLK/token flow, JSON attack/confirmation/concealment, damage and authored feedback |
| `native-game-numbers-examine-current-v1` | 16 | Actual native examine controller, JSON item values, server prose, late property tables and disclosure |
| `native-game-numbers-examine-original-current-v1` | 22 | Read-only installed TLK/2DA item content, field order, custom labels, whole-pound weight |
| `native-game-numbers-radial-final-v2` | 15 | Visible radial counts/tooltips and real viewport drag/drop, private scopes and existing routing marker |
| `native-game-numbers-examine-ui-final-v1` | 62 | Visible original examine controls, integer weight, identify fee, scrollbar, resizing and stale actions |

The item screenshot was visually reviewed:
`reports/native-game-numbers-examine-ui-final-v1-item.png`.
The audit receipt is `reports/native-game-number-display-audit-v1.json`.
Backup: `backups/native-game-number-display-v1.zip`, verified by checkpoint.

Historical rejected runs are retained. The original-content test had one old
custom-label expectation of `1.5`; it now expects whole pounds. The older radial
test omitted the already-existing `kindSource` routing field; its exact request
expectation now includes it, and it selects the page through the existing page
button callback. Product action routing was not changed.

These are formatting and local UI receipts, not public-server latency or full
UI parity acceptance. No public connections or manual client restarts were made.
