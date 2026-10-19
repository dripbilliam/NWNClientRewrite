# Bonus attacks and equipped bonus spell slots — 2026-10-17

Read-only original NWN:EE89.8193.37-17 x64 `nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original install and Ghidra project unchanged. Active authored scripts choose
these generic engine commands; no Divine Power/Tenser runtime branches added.

## Native bonus-attack effect

`ExecuteCommandEffectModifyAttacks14051a730..14051a821`, active ordinal485,
accepts signed magnitudes below6, including negative values. Invalid values
leave a fresh type0 effect with the default creator/subtype. Valid values produce
type44/subtype8 with raw INT0 and source creator. This is distinct from existing
type59, which controls the creature's attack-count override flag.

`OnApplyModifyNumAttacks14042f010..14042f106` rejects loading dead creatures
except durations3/4; noncreatures return0. It rejects an existing round2f64
value above5, then sums INT0 from every live type44 across the entire array,
including the incoming amount. Signed DWORD wrap precedes a maximum5 cap;
there is no lower clamp, plot gate or icon creation. It writes round2f64, already
represented as `bonusEffectAttacks` and consumed by attack counting, physical
attack records and action grouping.

`OnRemoveModifyNumAttacks1404378d0..14043797b` scans until type>44, excludes
the exact removed pointer, sums the remaining type44 magnitudes, caps at5 and
writes the same round field. Siblings sharing an effect ID still contribute.
The handler returns1 before the existing effect-removal owner erases the record.
`src/modify_attacks_effect.js` ports these owners, connected through the VM and
effect runtime. Retained REA dossiers: effect-modify-attacks-command,
modify-attacks-apply-owner and modify-attacks-remove-owner.

`scripts/inspect-native-modify-attacks-effect.py` runs all three original owners
and original GetInteger/SetInteger.792 cases cover defaults/VM failure boundaries,
negative and overflow values, loading/dead/durations, stale round count>5,
noncreatures, duplicate IDs versus pointers and deliberately out-of-order arrays
to distinguish apply's full scan from removal's early stop. VM allocation/base
constructor/free, cast and dead are captured lower boundaries. This does not
prove hits, damage, animation scheduling or transport.

## Bonus-slot equipment dependency exposed by the installed spell

Tenser's unchanged installed script reached native polymorph equipment removal,
then failed on unimplemented property13 removal473c30. The fix ports both
directions and the underlying counter owner in `src/bonus_spell_slots.js`:

- ApplyBonusSpellOfLevel46e820..46e8c4 / RemoveBonusSpellOfLevel473c30..473d2e
  scan all class slots and use the LAST matching class BYTE against the property
  subtype WORD. CostValue's low BYTE is the spell level; no pricing-table level
  substitution. Apply modifies by+1; remove modifies by-1 and additionally
  decrements a nonzero per-day BYTE for non-memorizing classes.
- ModifyNumberBonusSpells40f110..40f300 performs signed DWORD addition,
  warns if negative and clamps below1 to0. The getter treats the stored count
  as UINT and caps255. Gain plus bonus saturates255, unlike the wrapping BYTE
  addition in the separate UpdateNumberMemorizedSpellSlots owner.
- Stats SetNumberMemorizedSpellSlots416540..41660b chooses delete1 only
  when creature9f4 and97c are both0, then delegates to the existing class-info
  resize. Transformation locks retain truncated spell records. Existing resize
  preserves capacity and removes tail records first when deletion is enabled.
- GetSpellsPerDayLeft409680..40975b / DecrementSpellsPerDayLeft3f2790..3f2868
  preserve class/level bounds warnings and raw BYTE decrement semantics.

`NativeItemRuntime` supplies active class rules, existing spell-gain providers,
live class counters/spellbook arrays, actual lock cells and durable warnings.
Property13 now has both materializer and remover. Initial counters still use
the pre-existing equipment-derived import in initializeBonusSpellSlots; these
changes do not replace that separate import with an invented native load order.

`inspect-native-bonus-spell-slots.py`:2400 original-code cases covering full
apply/remove/modify/stats-setter/getter/decrement chains. GetClass, spell gain,
class-info resize and ExoLog are captured boundaries. Tests compare counters,
per-day arrays, warning order and exact resize arguments/lock flags. Full WORD
subtype mismatches, duplicate classes, levels0/1/9/10/256, saturation, negative
and overflowing deltas are included. Total new original-code cases3192.
REA dossiers for all six owners are retained under backups/animations.

## Installed/runtime validation and remaining limits

`installed-modify-attacks-v10.json` PASS with unchanged installed Prelude/cleric:
actual NCS constructors and applications grant+2 then+4 (capped5), schedule
the real round action groups with counts3->5->8, and removal leaves7 then3.
NCS ItemPropertyBonusLevelSpell/AddItemProperty on existing equipped gear adds
one actual memorized slot; queued RemoveItemProperty removes it and restores the
original counter/pool length.

Ordinary cast actions with the explicit native script cheat argument execute
untouched Divine Power and Tenser scripts. Divine Power produces type44/value0
for this preset; that is accepted native behavior, not a forced bonus. Tenser
produces value2, and the real round schedules5 attacks versus baseline3.
After native deferred polymorph removal (501ms), the original equipment IDs and
bonus counters are restored. All originally registered objects retain identity.
Explicit script creation and temporary form equipment advance the cursor575->578;
requiring an unchanged cursor here would contradict native object creation.
Final inventory validation traces `CreateItemOnObject` in unchanged
`nw_s0_tenstrans` (VM continuation PC2726), creating carried `x3_it_pchide`/ID575.
That authored item remains; both temporary form gear objects are gone. Every
remaining new object must match an actual installed-script creation call. Its
entire later lifetime is not established by this controlled removal probe.

Earlier probe failures retained: v1 incorrectly required positive Divine Power
bonus; v2 exposed missing property13 removal; v3/v4 asserted immediate total
cleanup despite native delayed restoration and persistent equipped effects.
v7/v8 also incorrectly required zero remaining new objects, exposing the authored
player-hide item; v9/v10 capture its creation rather than deleting native content.
The accepted probe waits for the existing native owner and preserves equipped
effects. It isolates startup/periodic AI and uses seed1. It has zero error-level
diagnostics but retains10 known presentation/cache diagnostics, including temporary
HP/stat/skill icon presentation, weapon visuals, approximate polymorph combat
snapshot and unavailable synchronous RecomputeCombatInformation4171e0.
No claim that those remaining gaps are resolved.

All1900 tests and production build pass; bundle advisory remains. Existing actual
polymorph hotbar/prepared-slot/live-mesh-animation/radial-restoration UI regression
passes with exit0 (`modify-attacks-polymorph-ui-v1.txt`). Electron emitted one GPU
command-buffer error after its PASS line; retained log is not counted as proof of
pixel-perfect graphics. New Divine Power/Tenser rendered acceptance, attack hits/
damage/animation, all spell forms, native wire protocol and full campaign remain
unproven. Active auditv50:61 unbound commands/22 missing impact scripts (v49:62/22).
The full spellcasting/combat/campaign goal stays active.

Verified checkpoint `backups/bonus-attacks-slots-1900-20261017-v1.zip`:
10060files/130205302bytes; every archived entry length/SHA256 verified.
Process68183 terminal exit0 consumed; no running validation jobs. Verification
notes added after sealing. REA session99283 remains idle for read-only research.
