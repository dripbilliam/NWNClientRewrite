# Polymorph shared stat owners — 2026-10-15

Target NWN:EE89.8193.37-17, original x64 nwmain.exe SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
The install and Ghidra project remain unchanged. Original instructions, rather
than truncated decompiler output, establish the behavior below.

## Implemented dependencies

`src/base_ability.js` implements the six stats base setters: STR1404167d0,
DEX140415530, CON1404152a0, INT140415aa0, WIS140416e70 and CHA140415260.
Each writes the canonical GFF-backed base BYTE, queries the ordinary current
score and stores the returned modifier BYTE. STR tails to encumbrance(flag1).
The mental setters set actor+544=1; DEX does not introduce a dirty/event write.

CON writes its new base before querying the old maximum, which still uses its
old cached modifier. It updates the modifier, reads current HP and the new
maximum, then writes the DWORD HP as signed-short current + new max - old max.
Only adjustment flag exactly1 does this. Other flags update the cache only.
There are no additional death/dying events in this setter; do not substitute the
different UpdateAttributesOnEffect owner. ModuleSession.setBaseAbility exposes
this shared method using the existing current score/HP/encumbrance providers.
Those providers use the existing cached-stat refresh adapter; complete native
combat recomputation scheduling remains a distinct open dependency.

`src/natural_armor.js` implements `GetACNaturalBase1403f3e90..1403f4118`.
It preserves monk eligibility==1, positive signed cached WIS with feat260,
first Monk class level/5, flag1 exclusions, Dwarven Defender level/3, feat490
and active EPIC_ARMOR_SKIN_NATURAL_AC_BONUS. Class IDs/levels and the rule class
count have native BYTE widths. Per-class gains use signed BYTE returns.

When either native actor+9f4 or actor+97c is nonzero, ordinary class gains and
racial/authored natural armor are replaced by stats BYTEd51. Other contributions
retain their individual gates. The live character/combat projection now passes
the canonical actor into this query. Ordinary offline projections use the
constructor's untransformed state. Combat-context/touch consumers retain the
same projected parts; no authored NaturalAC value is overwritten.

The existing `nativeField9f4` already backs area entry/exit suppression and now
also drives polymorph natural armor; no second transition flag was introduced.
Existing `nativeField97c` and `nativeEquipmentLock97c` remain aliases. The new
single `nativeNaturalACD51` initializes to0, verified by stats constructor
1403ee49a zeroing DWORDd4f..d52. Base ability, HP, actor and stats identities
remain shared with existing combat/effect/UI consumers.

## Original instruction comparisons

`scripts/inspect-native-base-ability.py` executes all six full setter owners.
2,052 cases compare byte writes, cached modifier ordering, exact adjustment
flags and signed-short HP arithmetic including overflow boundaries. Current
score, modifier, encumbrance and virtual HP getters are captured lower
providers, not newly claimed complete native implementations.

`scripts/inspect-native-natural-armor.py` executes the full natural-armor owner,
both original permanent/bonus WORD membership algorithms, ordinary HasFeat and
the original ruleset hashing instructions. 2,400 cases cover query flags,
monk eligibility, duplicate/invalid classes, bonus feats, BYTE wrapping, signed
values and both polymorph guards. Monk eligibility, rule lookup and class gain
getter are captured boundaries. This is not a complete transformed encounter.

Fixtures: native-base-ability-observations.json and
native-natural-armor-observations.json in backups/animations. Tests replay their
side effects and provider ordering. A further projection regression checks
class/racial replacement without losing monk/feat contributions or authored data.

## Installed checks and remaining work

`installed-polymorph-stat-owners-v1.json` checks all six setters using an actual
installed wizard, active class/race/item data and native modifier/HP providers.
Each stat change/restoration preserves the same canonical root/stats/object,
equipment and effects. A controlled injury of7 and temporary HP9 survive CON
changes. Non1 adjustment flags leave HP unchanged. Both canonical transition
guards select a natural-armor value read from the active polymorph.2da and
restore the baseline afterward. These are direct shared-owner checks, not
EffectPolymorph casting, equipment merging or form-rendering proof.

All1,560 tests pass (`polymorph-stat-full-tests-v1.txt`); production buildv1
passes. Installed negative-levelv6 and regeneration/recoveryv4 regressions pass
without phase errors. Known loading diagnostics remain recorded. The hidden
spell UI smoke passes (`polymorph-stat-live-ui-v1.txt`), covering current spellbook/
radial/hotbar, slots, casting animation and counterspell. This is distinct from
full polymorph acceptance.

Full polymorph remains OPEN: constructor arguments and casting-ability selector,
type62 apply/remove adapters, active form loading, saved/native equipment arrays,
full transformation/restoration, race-derived effect68/vision traits, appearance
replacement, client message12/1 and feat289/radial cancellation. The native
shared removal and half-second deferred callback prerequisite was completed in
the previous checkpoint. All spellcasting, combat and continuous campaign
completion remain unproven; the persistent goal stays ACTIVE.

Additional research is captured in native-polymorph-creature-constructor-full.txt,
native-polymorph-racial-owners-full.txt and native-polymorph-racial-query-remove-full.txt.
Race effect68 creates copied innate vision69 filters for first-level race feats
228/354; its removal returns1. The full native race feat loader initializes each
WORD to0, queries physical FeatIndex, writes only on success, keeps duplicates
and uses a WORD row count. Ghidra's decompile truncates this loop at free(NULL).
This owner is researched, not yet connected; derived race table membership/count
metadata is retained in polymorph-active-racial-feat-rows.txt, not copies of tables.

Verified checkpoint: backups/polymorph-stats-1560-20261015.zip. See
backups/animations/polymorph-stat-checkpoint.txt for archive entry/hash verification.
