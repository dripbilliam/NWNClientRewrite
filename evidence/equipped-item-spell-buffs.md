# Equipped item spell buffs and on-hit casting

Target NWN:EE `89.8193.37-17`, original executable SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Research uses read-only Ghidra/static assembly and isolated unchanged native
instructions. The original install and Ghidra database were not edited.

## Implemented owners

`src/item_property_materializers.js` implements ApplyEnhancementBonus
`14046fee0..14047077d`, ApplyDamageBonus `14046ece0..14046f0aa` and
ApplyAbilityBonus `14046dcd0..14046de6d`. These cover property types0,6..9,
16..19. They use the session's active tables, native width conversions, hand
selectors, racial/alignment conditions, double-weapon ordering, creator IDs,
loading flag and lower effect application boundary.

Enhancement queries **IPRP_MeleeCost** directly. Load2DArrays at `1402b4848`
loads that resource and `1402b488d` stores it at two-dimensional-array offset160.
IPRP_BONUSCOST is a separate resource at offset300. The enhancement's damage
conversion scans cost table4 only for magnitudes above5, retaining the original
value if no matching zero-dice row exists. Query statuses do not override the
output-cell behavior observed in the original handler.

The oracle executes the real CGameEffect constructor `1404233d0..14042356e`,
copy constructor `140423570..140423768` and CopyEffect `140423ce0..140423f86`.
The copy constructor resets type, exposure, icon and integer data while retaining
the source ID and metadata; assignment copies the effect data. Consequently,
enhancement attack and damage copies share an ID but differ in exposure.
Property-ID linkage and exact effect references preserve their distinct
ownership and removal. Zero-value construction order is retained.

Full ApplyItemProperties `140464d50..140464dfe` and RemoveItemProperties
`14046b3e0..14046b496` traversal now drive the concrete materializers during
queued equipment changes. Bounds and pool storage are re-read after callbacks.
Removal still reaches the creator-cleanup boundary when the AI lookup is null.
`NativeItemRuntime` filters materialized properties from the older derived-stat
projection, preserving canonical item properties for ordinary queries and
avoiding duplicate bonuses. All six ability modifiers and Constitution HP
restoration were exercised with real installed creatures and gear actions.

`src/item_on_hit_spell.js` implements ApplyOnHitCastSpell
`1403de8a0..1403deaec`, reached from ResolveItemCastSpell `1403e60a0`.
It reads active **IPRP_ONHITSPELL.SpellIndex**, uses cost WORD+1 as caster level,
and creates the original spell/feat/caster/target/item/position/area payload.
The original base-item bit mask selects defensive direction for14,16,56,57,73;
the actor's area remains the payload area in both directions. Offensive payloads
go into attack list at+c0 and defensive ones at+d0. Missing spell or allocation
returns without appending.

SignalMeleeDamage `1403ed7e0` and SignalRangedDamage `1403edcc0` already schedule
event19. The live adapter now supplies the defensive payload's caster-ID accessor,
verified at `1403edbab` and `1403ee06b` (payload+8 is both event caller and recipient).
The existing event19 receiver executes the authored NCS with the item caster-level
override, then restores the interrupted caster context. No per-spell effect body
was added to production code.

## Validation

- `native-item-property-materializer-observations.json`:658 full materializer
  executions, including original constructors/copies, all conditions, slot
  selectors, double weapons, ammunition, zero/negative table values, cost scans,
  query statuses and loading flags.
- `native-equipped-property-traversal-observations.json`:96 original apply/remove
  runs, including callback growth, shrinkage and storage replacement.
- `native-item-on-hit-spell-observations.json`:1,050 complete original runs,
  covering base-item direction, widths, statuses, invalid area/spell and payload
  allocation failure. Lower table/string/allocation/list helpers are captured
  boundaries; this comparison does not execute authored impact scripts.
- `live-equipped-item-buffs.json`:installed dagger on canonical NPC475, queued
  equip/unequip, enhancement +1, all six ability +2 modifiers, HP restoration,
  damage bonus, property-ID links, removal, exact-expiry retention and subsequent
  deletion, re-equip and absence of duplicate stat projection.
- `live-authored-item-buffs.json`:four installed scripts selected from active
  ImpactScript rows. Magic Weapon and Greater Magic Weapon complete conjure/
  release/impact, add property6 and change the equipped attack bonus. Flame Weapon
  and Darkfire attach properties82/83; actual damage resolution and melee impact
  scheduling create event19 for installed on-hit spells696/703. Their NCS reduces
  HP (77→65 and65→58 in this captured run), restores caster context and cleans up
  item properties. No error-severity diagnostics occurred; all warnings remain
  included in the report.

The live buff probe uses public scripted requests with cheat=1 and an explicit
successful-strike fixture. It does not manufacture memorized slots, dispatch
the physical strike's other events, prove attack-roll parity or constitute
continuous campaign play. The spell logic itself remains installed NCS.

1,434 tests and production build pass. The rendered right-click summon test
still consumes a real slot, executes Follow/Stand commands, retains summon574
through an out/back area transfer and dismisses it. Screenshots were inspected;
the scene remains dark, DoSinglePlayerAutoSave is unsupported and the plc_w02
resource warning is retained. These are open issues, not clean campaign acceptance.

## Armor properties and carried-item release follow-up

ApplyACBonus `14046d9b0..14046dca9` is now implemented for types1..5. It allocates
before querying cost cache2 Value, uses the base item's AC_Enchant BYTE, creates
type48/duration3 and applies race/alignment or physical-damage conditions. The
normal damage mask is4103; property3 selectors0,1,2 replace it with1,2,4. Native
base-item loading `14029fd38..14029fd5c` writes255 when the AC_Enchant INT query
fails, so the live base-item cache now preserves this fallback explicitly.
`native-item-ac-materializer-observations.json` retains151 representative full
original executions using the existing real-constructor harness. An earlier
5,280-case Cartesian run also completed; the focused retained cases cover each
condition branch, magnitude/status/loading and category behavior without its
redundant cross product.

The ordinary casting release adapter previously sent every item through world
LOS using the item's stored position. Original `1403af22d..1403af3ff` instead
bypasses LOS when the target item has no area and its possessor is the caster.
An unplaced item belonging to someone else retains the block's initialized zero
destination; placed objects and location targets use their position with the
native height addition. `castReleaseLineOfSight` reproduces that selection,
verified against96 unchanged original block executions. The caster-area lookup,
full action and actual geometry remain separate owners.

`live-authored-armor-buff.json` now uses installed `x2_s0_magcvest` (active row546).
The older row108 `nw_s0_magvest` is a legacy visual-only script, as observed in
the first probe attempts; absence of an armor property from that script was
not an engine failure. The successful probe casts through the public scripted
request on the actor's own equipped, installed `nw_cloth001`. The authored NCS
creates property1 and the native materializer retains effect48. AC changes8→11;
unequip/re-equip preserves the item property, exact expiry retains it and the
next millisecond removes it and restores AC8. There are no error-severity
diagnostics; presentation warnings are retained. Startup/AI are isolated and
cheat=1 is an explicit scripted request. Normal memorized/item-target UI and
continuous campaign play are not claimed.

The follow-up passes1,436 tests and production build; all four weapon/on-hit
spell probes pass again (`live-authored-item-buffs-v6.txt`). The last rendered
radial/companion transfer acceptance was at the preceding1,434-test checkpoint;
there is no rendered armor-spell UI acceptance yet. Verified checkpoint reports
are `equipped-item-buffs-checkpoint.txt` and `armor-item-buffs-checkpoint.txt`.

## Remaining limits

38 of52 concrete property materializers remain unsupported, as do custom removal
handlers13/61, permanent item-level restriction setting134 and pricing owners.
Attached weapon visuals and parts of generic ApplyEffect/RemoveEffect bookkeeping
remain unfinished. Initial imported equipment still uses the earlier projection
until materialized through the native path. The new native comparisons capture
lower application/creator-cleanup boundaries and do not prove those complete
lower owners. Weapon-buff spellbook/radial acceptance is separate from the rendered
summoning regression. Full spell, combat, transport, persistence and campaign
completion remain part of the active formal goal.
