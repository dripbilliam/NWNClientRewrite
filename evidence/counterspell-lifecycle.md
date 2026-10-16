# Counterspell continuation, October 15 2026

Target NWN:EE89.8193.37-17, unchanged installed nwmain.exe SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original binary/assets and Ghidra project remain unchanged.

## Implemented and compared

`src/spell_counterspell.js` implements shared query/selection/cleanup owners.
The full shared lifecycle is connected to decoded player mode input5, the
right-click spellcasting options wheel, script ActionCounterSpell, canonical
action50 scheduling and cleanup, broadcast selection, consumption and impact.
The earlier broad preflight guard is replaced by these owners.

- Count140392830 uses ordered area IDs, mode4/target6f4, native3D FLOAT range4,
  both class loops and count cap10. Both loops require SpellCaster AND
  MemorizesSpells, including the uses loop. Hasted incoming casters require
  the candidate haste bit. Each class checks incoming ID, Counter1/Counter2,
  then94/41/67/122 with active ruleset thresholds2/3/5/9. These alternatives
  are engine constants, not replacement per-spell effects.
- Broadcast selection block140384654..140384c61 adds the count to effective
  Spellcraft rank for eligible countercasters, scans every memorizing class
  (last eligible class wins), then scans nonmemorizing classes only when the
  first pass found no spell. The nonmemorizing pass uses the incoming spell's
  class level even when choosing a dispel alternative. The count's class gates
  must not be substituted for these distinct selection gates.
- ValidateCounterSpellData1403aae30 scans all slots at the given class/level;
  last ID match supplies meta/domain, with no readiness condition. It stores
  7fc/800/801/802. Null slots expose invalid ID/metamagic255 in captured accessors.
- SPELLS Counter1/Counter2 load1402b1831..1402b193d writes signed DWORDs,
  default-1 on failed reads. `castingSpell` now exposes these active fields.
- RemoveCounterspeller14039e5b0 checks count>0 once, then clears all matching
  IDs without compaction; duplicates can decrement count below zero. Original
  leaf CFG ends14039e6ad. RemoveSpellActionFromRound14039ecb0 always scans all
  ten IDs and then the caster, removing actions only when pending result==1.
  Canonical constructor14037a901..14037a964 initializes slots invalid/count0.
  SpellRuntime.removeRoundSpell now uses this mapped shared cleanup owner.

`inspect-native-counterspell-selection.py` executes unchanged owners with
captured lower query boundaries:1,064 count,472 selection,72 validation,
48 ID-removal and144 round-cleanup cases (1,800 total). Tests cover exact call
order, class gates, active threshold changes, range/haste, duplicate IDs and
spent-slot metadata. Full suite1,345/build pass. Reports:
counterspell-selection-{focused,all-tests,build}-v1.txt and the native JSON.

## Lifecycle implementation and validation

The previously mapped continuation below is now implemented and compared.
`counterspell_actions.js` maps queue14037e460, action1403b6b02..1403b6f54
(profiling disabled), ClearAction50 at140387293..140387428 and its common tail.
Original actor rejection is dead==1 AND dying==1; targets reject either.
DAT140df04dc/e0/e4 are **1/2/3**, correcting the earlier reversed1/2 note.
ClearAction retains target6f4 and physical slot holes.

Broadcast selection retains signed BYTE skill, specialization/opposition,
authoritative d20, class/metamagic/domain, haste and ten physical ID slots.
Ordinary slow casts initialize countercaster6000ms rounds; fast casts skip
that initialization but still animate and consume. Release failures52/147/118
restore animation/lock/81c. Successful countered impact sends CC12 and schedules
no event8/ImpactScript. Completion restores reaction state and clears IDs/count.
CC12 observer14048e960 queries skills for every spatial creature, including
NPCs/distant creatures; only clients within30m get school adjustments and a
separate rawCRT rand()%20+1. Names are STRREFs. Local UI wording is an adapter,
not verified original TLK formatting or client/network reconstruction.

Full-action comparison also corrected fake casting: negative-flag casts skip
ordinary broadcast/counterspell reactions and never run impact scripts. They
call BroadcastSafeProjectile1403b03ad..1403b04c0 with appearance6/7, spell ID,
path and stored travel time. Ordinary release/projectile VFX remain explicit
unsupported owners. SetActivity8 calls StopDialog14049ce40, not counterspell
removal; the old counter-target guard is corrected. Actual active-dialog
participant/owner cleanup still raises an explicit unsupported diagnosis.

New unchanged-instruction comparisons, with captured lower boundaries:

- inspect-native-counterspell-actions.py:77 queue,195 execute,144 clear cases.
- inspect-native-counterspell-broadcast.py:232 cast broadcast,144 CC12 cases.
- inspect-native-cast-action.py:3,765 cases,79 added counter/fake cases.
- inspect-native-cast-impact.py:97 cases,48 added countered cases.

These add919 cases. Exact calls/RNG order, slot/count, contexts, rounds,
resource state, return codes and absent impact events are compared. Captured
boundaries limit this evidence; it is not original-process campaign acceptance.
Focused report:counterspell-focused-v7.txt. Full suite1,347/build pass:
counterspell-full-tests-v3.txt and counterspell-build-v3.txt. Isolated Electron
counterspell-casting-ui-v3.txt verifies spellbook click, hotbar drag/F2 target,
radial Light, two real slots and cast animations, plus a world NPC's counterspell
radial command enabling mode4 with that canonical target. Renderer errors0.

probe-live-counterspell.mjs imports installed wizard.bic twice into canonical
objects, without manufacturing spell slots. Player mode5 activates the order;
queued Light spends both real slots, animates both casters, sends CC12 and
suppresses impact. With perception flags0 only the incoming slot is spent,
and the installed impact runs once. Fake Light spends neither slot, provokes
no counterspell broadcast/animation and runs no impact script. Cancellation
and script ActionCounterSpell requeue/cleanup pass. Reports:
live-counterspell-v4.txt/live-counterspell.json. Startup/general AI disabled,
controlled visibility, local test clone; not original-process multiplayer.
Audit-v13 remains840 rows/618 scripts/596 loadable/163 unbound/22 missing.
Binding presence is not implementation. Full spell/combat/campaign gates remain.

## Original mapping notes (superseded by validation above)

The authoritative continuation is the full assembly in
`backups/animations/casting-action-flow-full-asm.txt`, function requests
AIActionCastSpell1403ada70 and SpellCastAndImpact14049c4b0. Broadcast assembly
is `native-live-spell-adjacent-asm.txt` (140384300). Ghidra truncates important
functions; use the assembly and isolated instruction comparisons.

- Broadcast: after selection and the viewer's d20 identification check,
  140384d11..140384d89 appends an identified, eligible, haste-qualified viewer
  into the first invalid310 slot and increments338, at most10. Full observer
  broadcast selection/append still needs runtime wiring and validation.
- AddCounterSpellActions14037e460 validates noninvalid/nonself target creature,
  both areas and actor movement bit8d4&2. If head action15/46 has9c0, it sets1
  before ClearAllActions. Front50/new group then front17/same group with range4;
  writes6f4. ExecuteCommandActionCounterSpell14050d840 calls this independently
  of commandability. Player input10/mode5 first queues, then ToggleMode5.
- AIActionCounterSpell1403b6480: activity manager4; target dead/dying/area gates;
  out-of-range retries front50/17/move/path wait; in range broadcasts combat
  state, resolves initiative, enables mode4 when needed and locks orientation.
  The decompiled actor-dead/dying condition is unusual; inspect exact instructions
  before implementing it. Status constants dc/e0/e4 are1/2/3 (corrected).
- Cast action start1403aede3 starts each recorded countercaster round6000,
  decrements by the incoming cast duration and pauses with its own ID. Conjure
  1403af143 copies incoming spell/target/point/impact0 and animation15/16.
- Release failure paths reset each countercaster animation/lock/81c and give
  feedback52 for LOS failure,147 for defensive/concentration failure,118 for
  armor/general failure. Native release helpers currently lack these callbacks.
- Consumption1403affa9 iterates all10 slots when count>0, decrements each
  selected7fc/class800/domain802/meta801 with caster level255; consume failure
  clears that slot/decrements count, success sets the countercaster81c1.
- Cast animation1403b0113 updates countercaster projectile time and cast
  animation. At impact1403b02ee, any still-resolved countercaster marks the
  incoming spell countered, removes its pending round spell action, then passes
  that flag to SpellCastAndImpact. Countered impact14049c8ff..14049ca37 sends
  counterspell feedback for each existing slot and schedules NO impact script.
  At normal completion1403b023e it resets countercaster animation/lock/81c,
  clears slots and decrements count before round cleanup.
- BroadcastCounterSpellData14048e960 needs exact observer/RNG handling. Its
  pseudocode is truncated in school/opposition paths; use original assembly.
- ClearAction and SetActivity counter-target removal must be connected; current
  guard still diagnoses native counterspell removal instead of dropping state.

Useful captures: ghidra-counterspell-{queue,action,script,validate}.txt,
ghidra-counterspell-ready-{pointer,classinfo}.txt,
ghidra-counterspell-14039ecb0.txt, ghidra-counterspell-14039e5b0.txt,
ghidra-counterspell-14048e960.txt and native-counterspell-*-asm.txt.

Remaining spell owners after counterspells include summons/create/destroy/
associates, polymorph, poison/disease/negative levels, item properties and
equipped propagation, feat/item/placeable/talent casting, memorization/rest and
full release/projectile/VFX presentation. Only then advance the formal goal to
combat completion and continuous campaign play/fix acceptance.
