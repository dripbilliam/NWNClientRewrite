# Native character-record values — partial content audit

The later [record-entry milestone](NATIVE-RECORD-ENTRIES.md) adds original feat
admission and default-locale insertion order. This document's receipts refer to
its own historical source checkpoint.

The current native record uses `native_data/character_record_values.gd` for
ability display values. Previously its modifier was always `floor((score-10)/2)`
and received adjustments were ignored. The original client uses the connection's
`CHARGEN_ABILITY_NEUTRAL_VALUE` and `CHARGEN_ABILITY_MODIFIER_INCREMENT`, including
its even-neutral correction, division truncation, unsigned score input and
signed-byte result. This is a UI projection; it does not alter received stats.

Original `GetAbilityModifier`1407ec3a0 was executed unchanged in the existing
offline Unicorn harness for1,295 cases: all256 score bytes plus wrapping inputs,
stock rules, odd/even neutral overrides, nonstandard increments and negative
increments. Only the hash/ruleset-lookup service boundary is captured. The result
matches native Godot in every case. Hash calls whose displayed string begins
`HARGEN_` have already folded the leading C into their seed.

The actual wire reader stores the additional Dexterity modifier in
`inventoryStats.fields76[6]`, not a standalone `field7c` property. This signed
byte now contributes to the sheet's effective Dexterity modifier and comparison
color. `fields7d` supplies signed score adjustments; the baseline score wraps to
a byte before lookup. Undisclosed values remain unknown. Malformed rules that
would fault the original integer division produce an unknown display value.

Original token data140e2e740 is `<c ff 01 01>` and140e2eedc is `<c20 ff20>`:
reduced values use RGB255,1,1; improved values use32,255,32. Both native and
fallback record controls now use those colors. Labels resolve active TLK refs:
ability labels135/133/132/134/136/131, Experience314, Next Level315, saves
317/318/319, BAB40424, SR58349, arcane failure58350 and armor penalty58351.
Arcane failure includes `%`, armor penalty includes its native minus sign and
the undisclosed BAB sentinel remains unknown.

Evidence:

- `scripts/inspect-native-record-abilities.py` generates the read-only original
  oracle at root `backups/animations/native-record-ability-observations-v1.json`.
  It imports the pinned client-HP/PE-loader harnesses, never a live client.
- `backups/animations/rea-native-record-ability-values-v1.json` retains the
  original function and token bytes. Full original Character SetData research
  remains in `rea-native-character-content-research-v1.json`.
- `native-record-values-v2`:1,310 headless checks including all original cases,
  ruleset-cache input semantics, signed cache projection and actual TLK labels.
- `native-record-values-frame-v1`:28 graphical native-input checks including
  visible score/modifier colors, received HP refresh, title dragging and saved
  placement, stale handles, Level Up routing and freed-control retirement.
- `native-record-values-rules-v1`:15 existing native UI rule checks.
- `native-record-values-desktop-v1`:41 existing graphical desktop checks.

All four debugger runs passed with unchanged source, no engine/lifetime errors
and zero public connections. The preceding frame milestone also passed its
99-check owned original-server regression; it was not rerun for this display-only
correction and is not represented as current-source full record acceptance.

This does not complete the character record. Weapon/attack/damage/qualifier and
other original details, disclosure, feat grouping/order, all states, resizing,
large-dialog-font selection, original-client comparisons and server-context
coverage remain open. General porting remains deferred by the full UI goal.
