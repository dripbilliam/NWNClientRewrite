# Pregame Character details — partial UI parity

Typed native BIC previews now generate the original lower Character list instead
of displaying the BIC description there. Original save, base attack, resistance,
spell failure, armor penalty, alignment and Effects-heading rows use active
native class tables and TLK text. Godot owns their projection and presentation.
This supersedes the interim-description gap in the earlier numeric checkpoint;
it does not complete the Character page or the whole UI goal.

## Original evidence and data flow

The original binary SHA256 is
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Root `backups/animations/rea-native-pregame-character-details-v1.json` retains
the original lower-list helpers, combat-info import/defaults, class BAB loader,
complete SetData procedure range/callees and string concatenation. Additional
`rea-native-pregame-character-detail-controls-v1.json` records sizing, scroll
remainder, effect-list refresh/cleanup and string initialization.
`rea-native-character-detail-row-height-v1.json` records original AddItem.
The earlier complete pregame SetData text/assembly remains in
`rea-native-pregame-character-v1.json`.

`native_data/pregame_record_details.gd` reads strict CHAR Fort/Ref/Will fields and
strict BYTE SpellResistance/ArcaneSpellFail/ArmorCheckPen from the CombatInfo
STRUCT. Missing or incompatible fields retain original zero defaults.
`pregame_record.gd` combines this display source with its existing typed numeric
source. Active class AttackBonusTable resources are prepared before publishing
the complete preview. Original BIC import refresh invalidates cached BAB; the
display sums active per-class table bytes rather than trusting the serialized
BaseAttackBonus field. The original detail caller zero-extends that final byte;
saves are sign-extended. The native projection preserves both behaviors.

Labels317–319 receive the original appended colon/space. Other labels retain
their TLK punctuation verbatim. The original gray label prefix and normal value
text pass through the native NWN color parser. All nine exact alignment titles,
threshold-based alignment names and numerical alignment points are supported.
The original pregame constructor has no received effect rows: this projection
ends with its Effects heading and does not execute/import a BIC EffectList to
invent active world effects. In-game effect rows remain separate work.

The chooser now uses CTL_CHRSHT_LSTBX's text/scroll attachment points, original
dialog TTF and scrollbar artwork. Its bottom follows the source mode-zero
viewport; the scrollbar endpoint remains14 pixels above it. Original AddItem
uses fixed20-pixel list rows, independent of the font size. The native detail
font binding retains that advance and a20-pixel scroll step. Unchanged tab
reopens retain position; changed selection clears text; close retires the bar
and font callback. Exact raster/baseline/wrapped-row comparison remains open.

## Isolated original-instruction comparison

`scripts/inspect-native-pregame-character-details.py` executes the complete
unchanged `1409bbfc0` function and its original value/alignment/BAB helpers.
Allocation, string, TLK, portrait, row creation and layout services are captured;
imported fields and active table storage are fixtures. It does not emulate the
complete BIC importer or render the original client. The current72-case output
is `backups/animations/native-pregame-character-detail-observations-v2.json`.
It includes all nine exact titles, threshold boundaries, invalid classes,
class-level storage boundaries, signed save/unsigned combat boundaries and
custom server punctuation. Native row strings match the captured originals.

The earlier40-case valid-class oracle remains as v1, with its exact generator
saved as `inspect-native-pregame-character-details-fixture-v1.py`. Initial
emulator failures produced no accepted output. The harness was corrected to
capture string initialization and preserve RAX across the security-check service.
Native data tests v1/v2 retain11 mismatches each from treating displayed BAB as
signed. Current source follows the original MOVZX EDX,AL call site and passes.

## Current verification and rollback

All current runs are headless with normal-heap exception traps, source pins,
zero public connections and engine/lifetime checks:

| Run | Checks | Scope |
| --- | ---: | --- |
| `native-pregame-character-details-data-v4` |225|72 original complete-function output comparisons and strict typed source/dependencies |
| `native-pregame-character-details-input-headless-v3` |25| Typed BIC, displayed rows/font/extent, pointer tab/wheel input, fixed row advance, late TLK/race/BAB updates, stale selection and cleanup |
| `native-pregame-character-details-numbers-v1` |802| Earlier original numeric display/type/default regression |
| `native-pregame-character-details-worker-v1` |24| Preview integrity/ownership/shutdown regression |
| `native-pregame-character-details-skills-v1` |373| Earlier original skill/class-gain regression |
| `native-pregame-character-details-spells-v1` |296| Earlier original spell enumeration/gain regression |
| `native-pregame-character-details-chooser-headless-v1` |23| Existing chooser selection/double-click/New/Cancel regression |

Total:1,768 scoped checks. The open manual client was preserved. No graphical or
fresh authoritative local admission acceptance is claimed for this change.
`tools/audit-native-pregame-character-details.mjs` verifies current source pins,
oracle/evidence, retained failures and the read-back-verified rollback archive.

Remaining work includes original-client visual comparison, title/header and
portrait variants, every font/scale/row-wrap/state/gesture, negative-class-level
presentation, in-game detail/effect disclosure and all remaining chooser/UI
actions. The original native startup heap exception also remains unresolved.
General porting is still deferred; full UI and stability parity remain false.
