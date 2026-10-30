# Original spellbook layout research — historical data-plan checkpoint

At this research checkpoint the visible spellbook was still the generic
`server_spellbook.gd` screen. This milestone recovered original structure and
added a model-backed native layout plan, `native_data/spellbook_layout.gd`.
It is **not** spellbook UI acceptance. The later
[frame integration](NATIVE-SPELLBOOK-FRAME.md) connects that plan and tracks the
remaining gesture/state/role/comparison gaps separately.

Root `backups/animations/rea-native-spellbook-layout-research-v1.json` retains26
original function analyses, plus original icon-pointer/reference table bytes.
All identify original client SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Read-only model hashes/hooks/clips for12 confirmed resources are in
`reports/native-spellbook-model-geometry-v3.json`. An earlier candidate guessed
two absent model names; its failed report is retained and is not acceptance.

## Recovered structure

- `CPanelSpellbook14088c8d0` builds `PNL_SPELLBOOK`,360×471, not the current
  generic700×580 frame. Title uses `fnt_galahad14`, localized class name plus
  TLK5215 (`0x145f`); its initial title ref is53291 (`0xd02b`).
- Eight class tab objects use `CTL_SB_BTN_SPTAB`, chained33px from main hook
  `(6,59)`. Unused original slots are disabled. Class icons come from the active
  class definition; no server-specific list should be compiled into the UI.
- `CTL_WIZARDPAGE` attaches at main `pages` `(0,64)`. Ten level tabs start at
  page hook`(6,38)` and use the same33px links. Original level icons are
  `IR_CANTRIPS`, `IR_LEVEL1` through`IR_LEVEL6`, then shared`IR_LEVEL789` for7–9.
  Level refs are`0x10c42` through`0x10c4b`.
- Known scroll viewport is `(2,109,348,360)` in main-window coordinates;
  tree origin is `(6,105)`. Scrollbar attaches to page `scrollmin/scrollmax`.
  Separate top-right up/down buttons are at page `scrollup/scrolldown`.
- Seven `CTL_TREEBTN_ROOT` metamagic groups use Normal/Empower/Extend/Maximize/
  Quicken/Silent/Still. Original refs, feat IDs and icons are in the data plan.
  Costs come from active `SPELL_METAMAGIC_*_COST` ruleset entries; current
  `game_ui_rules.gd.meta_cost()` already consults those entries.
- Root links advance40px. Known leaves use **`CTL_TREEBTN_SPEL`**, with33px
  links and32px spell art. Caption is the separate `text0/text1` rectangle,
  not whole mesh bounds. Selected leaves attach `CTL_SPL_BTN_AROW` to
  `ArrowButton` and `CTL_CG_BTN_HELP` to `DescriptionButton`.
- Prepare-arrow callback14088e650 selects the first empty slot through
  14088ff10. Help14088e6c0 opens the original spell description modal
  constructor1409c3680. Root expansion14088e7a0 and known-row population
  14088e9d0 permit multiple expanded metamagic groups. Spell sorting is an
  original option, `ui.spellbook.sort-spells`; default is false.
- `CPanelSpellMemorization14088f800` is a **separate360×471 window**, title
  ref53290 (`0xd02a`). Its viewport is `(1,20,358,450)`, tree origin`(3,23)`.
  Ten expandable level roots use `CTL_TREEBTN_ROOT` and the same level refs.
- Prepared rows are **nine columns**, recovered from140890930's `/9` logic.
  `CTL_SPELLS_TMP` links rows33px vertically. The first slot uses
  `CTL_SPELBX_FIRST` (34×33), then eight`CTL_SPELBX_NEXT` slots (33×33).
  First row origins relative to a level group are `(33,40)` through`(298,40)`;
  slot9 restarts at`(33,73)`. Icons retain original hook centers.
- Slot contents/ready/metamagic/domain fields come from received character
  data via140890560. SetSpell1409c2630 sends a prepare command only when its
  explicit mutation flag is set; clear1409c1fc0 likewise has a send flag. A
  refresh must never fabricate a server preparation request.
- `CSpellButtonDragSource` selects the row and delegates to `CSpellBox` drag
  handling. Callback1409c2340 handles actual drag/drop events. Exact click,
  double-click, pickup/cancel, world casting and description gestures need
  original-client input comparison; the generic right/double-click cast
  behavior must not be assumed equivalent from appearance alone.

## Native plan verification

`native-spellbook-layout-v1` passes40 unchanged-source headless debugger checks:
all12 source models decode; both frame extents;8/10 tab chains; both viewports;
root/leaf caption/icon/help/prepare hooks; prepared counts0,1,8,9,10,17,18,19,27;
cross-row positions; asymmetric FIRST/NEXT widths; original shared high-level
icons and localized references; missing-resource/count rejection. There are no
UI pixels, input or server actions in this metadata test. Public connections0.

## Implementation still required

Connect a native main frame and separately movable/persistent memorization
window over the existing typed book/private-entry owner. Keep source art
proportions, radio/disabled states, fonts, scrolling and selected-row controls.
Extend the current single-level/single-metamagic view model to support the
original independently expanded groups/levels; do not claim parity with one
selected group merely restyled. Preserve authoritative prepare/clear/cast
outcomes, uses, used slots, domains, family-child shortcut dragging and stale
view rejection. Class/level/root callbacks need view/wanted ownership checks.

The family chooser and any genuinely replacement-only tools need a base-game
style. Spell-description/help modal, preparation refusal/pending states,
drag/drop to memory/quickbar/world, cancel, all shortcuts, original sorting,
role/server variants and original-client visual/input comparisons remain open.
Current original GUI button painting supports static per-pose geometry; class/
level/root icons also need their original `gui_replace01` texture overrides
carried through pose-cache keys, not a stretched composite screenshot.

No part of this data-plan checkpoint marks spellbook, full UI or general
migration complete. General porting remains deferred.
