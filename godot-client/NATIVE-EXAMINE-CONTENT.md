# Original item Examine content — partial parity

The original-framed item window now uses a continuous native text flow instead
of generic field-name/value blocks. It displays the received description,
original stat block, conditional base-item name, charges, weight, value, required
level, localized property heading and existing authoritative Identify fee.
Creature/door/placeable/trap formatting and complete item-property styling are
not accepted by this checkpoint. Full Examine and full UI parity remain open.

## Original evidence and data ownership

`../backups/animations/rea-native-examine-content-v1.json` retains original
receiver `14079a1e0`, formatter `140899040`, text wrappers, and assembly showing
TLK arguments omitted by the decompiler's GetSimpleString prototype.

The original item formatter uses these localized references:

| Reference | Installed English text |
| --- | --- |
| `d036` | Base Item: |
| `15bd` | Charges: |
| `15bf` | Weight: |
| `be8`, `1907` | Value, GP: |
| `1a97` | Level Required: |
| `1a96` | Special Properties: |

The implementation resolves the active TLK/overrides, not these English strings.
Empty descriptions use the active `baseitems.Description`; stat blocks use
`BaseItemStatRef`. Armor uses the **server-disclosed `item.field35c` category**
and active `armor.DESCRIPTIONS`/`BASEITEMSTATREF`. The existing protocol reader
receives that category in the active item properties. Visible chest parts may
differ and never override it. Missing category data does not fabricate armor
statistics. Table column lookup in this content owner is case-insensitive.

Charges and level information retain original identification gates; absent
value sentinel `ffffffff` is omitted. The original base-name exclusions use the
formatter's string-reference tests. Numeric fields stay inline, and weight uses
the received tenth-pound value. The original property heading replaces the
generic English heading. The UI does not add its own unidentified/use-permission
paragraphs to the original item text. Existing logical disclosure state remains
available to other owners and the generic fallback.

`native_data/examine_content.gd` handles data-only presentation;
`native_gameplay_ui.gd` projects the received message; `server_examine.gd` renders
the single rich-text flow and asynchronously delivered property details. Native
caption fonts/colors and explicit server color spans remain intact. No JS
rendering, server rule implementation, protocol mutation or resource cache purge
was introduced. One original `armor.2da` load joins the native UI's table setup.

## Verification

Final source-pinned debugger receipts:

- `native-examine-content-original-final-v1`:22 checks using installed original
  tables/TLK, original stat text and field order, description fallback, disclosure
  gates, server category versus differing model parts, clothing category0,
  missing category and custom server table/string references.
- `native-examine-content-projection-final-v1`:15 checks for asynchronous
  property tables, custom subtype/cost/parameter overrides, stale targets,
  revisions, menu stacking and closed-window behavior.
- `native-examine-content-ui-final-v1`:48 graphical checks, including visible
  inline fields, original font identity/line metrics, real pointer scrolling,
  scaled controls, Identify refusal/pending/timeout/context guards and portraits.
  Item/creature/scroll/scale captures are retained; the item capture was reviewed.
- `native-examine-content-text-final-v1`:1025 text/token checks.
- `native-examine-content-playability-final-v1`:1314 regression checks.

The earlier `native-examine-content-actions-checkpoint-v1` passed99 original
server checks on isolated localhost5125 before the final armor-category
correction. It is retained as intermediate evidence, not the final source proof.
The final action receipt is `native-examine-content-actions-final-v1`.
It passed all99 checks with unchanged source, native exit0, zero remaining
workers and no public connections. The pre-existing isolated servers and user
clients were preserved. Original free Lore and exact paid Identify both passed.

Failed work remains recorded: initial GDScript type/inherited-name errors,
the first case-sensitive armor lookup, and an older headless projection fixture
that omitted the current inventory receiver dependency. Only owned failed tests
were stopped; the explicit fixture dependency and implementation were corrected.
An early appearance-derived armor experiment was discarded after confirming
the server already supplies the category. These runs do not count as acceptance.

Limits: exact original-client blank-line/wrapping/color comparison, item-property
ordering/colors and every target/state/scale/server variant still need audit.
The earlier intermittent blood screenshot failure remains open. No particle or
combat implementation change was made here.

Rollback: `backups/native-examine-content-v1.zip`; scoped audit:
`node godot-client/tools/audit-native-examine-content.mjs`. Previous checkpoint:
[NATIVE-BITMAP-FONTS.md](NATIVE-BITMAP-FONTS.md).
