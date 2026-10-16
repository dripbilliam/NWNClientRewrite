# Rest lifecycle and spell recovery

Target: NWN:EE89.8193.37-17, nwmain.exe SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original install and Ghidra database remain read-only.

## Original owners

| Owner | Evidence and behavior |
| --- | --- |
| Rest14039f360..740 | Dead/dying, familiar, area NoRest, active REST_ENEMY_CHECK_DISTANCE/nearest-enemy and excitement gates. Clears actions before excitement rejection. Clears selected activities, enables16, queues42 with player-mode INT and started INT0. PC/possessed sends module rest-start; NPC runs its rest script9. |
| AIActionRest1403ca890..b8f9 | Full unwind body, including early failures, progressive HP/spell recovery, affliction callbacks, associates, enemy checks, final restoration and module rest-finished. Profiling/CRT are captured boundaries. |
| CancelRest140386940..6b0f | Animation0, reason WORD feedback, activity16 off, module canceled event, timing-bar stop and type1 associate current-action cancellation. Timers are cleared by selected callers, not this owner. |
| Input1404531b0 subtype13 at140454244 | Controlled creature/8ac veto, overflow, commandable feedback213, existing activity16 veto, then Rest(0,0). Returns0; no underflow read or success Boolean. Writer1407bffb0 sends6/13. Inventory12/13 is scroll learning, a different family. |
| ClearAction1403870b0, branch1403871a4..b9 | Interruptibility veto, CancelRest20 and common lock/start-time cleanup. Completed actions are disposed by RunActions without invoking cancellation. |
| ReadySpellLevel1404123b0..2593 | Existing non-null prepared slots become ready; BYTE slot-count traversal. Other classes reset both remaining/maximum daily BYTE counters from shared spell gain plus capped UINT bonus. No spellcaster gate or array growth. |
| GetHighestLevelKnown140402950 | Highest physical level with nonzero WORD known-count, independent of memorized slots or class flags. Verified closed leaf CFG. |
| ResetFeatRemainingUses140412b10 / ResetSpellLikeAbilities140412b50 | Reset physical spent feat BYTEs to0, skipping NULL; set every spell-like entry ready INT to1. Duplicate IDs remain independent. Verified closed leaf CFGs. Existing FeatUsePool.reset is reused. |
| RemoveBadEffects14039e020..e0c4 | Sorted live effects, stop at type>99; exact duration/subtype gates, restart on removal. Preserves innate subtype32. It does not mean “remove every debuff.” |
| ClearSpellEffectsOnOthers140491110..12c8 | Shared canonical +170 target list, reverse physical traversal, creator/subtype/timed-property gates, synchronous effect removals or queued creator-owned AoE destruction11. Clears count while retaining capacity. |
| RestoreItemProperties14039f760 / recursive14039f860 | Visit18 equipment masks; carried container contents before their own properties. Restore each selected item and update its active-use cache. No stack/charge refill. |
| RestoreUsedActiveProperties14046b4d0 | Physical TYPE15 properties only; nonzero flag selects UsesPerDay255 only. Cost8..12 sets daily counts1..5; remaining flag1. Reuses prior validated single-property policy. Verified closed leaf CFG. |
| UpdateUsedActiveProperties14046cf20 | Existing shared cache/delta/full presentation owner reused. This is not an inventory-repository refresh or arbitrary dirty flag. |
| RemoveDominationEffect1403d7160..71ef | Type8/integer0==7/current master match; removal cursor resets then increments, so next scan starts at1. Raw native behavior retained. |
| Module EventHandler14047c0b0, script35 at14047cfa7..cfc3 | Caller stored in module380, integer0 narrowed BYTE384, RunEventScript12. Constructor14047865b/665 initializes INVALID/0. Script absence does not prevent history updates. |
| ActionRest14050ea00 / ForceRest14051dc70 | Optional ActionRest visibility INT normalized Boolean; normal Rest(0,flag). ForceRest independently clears actions/effects, readies0..9, heals, restores items/feats/abilities and encumbrance. It does not run the ordinary rest timer or emit finished event. |
| GetIsResting140527890 / last-PC14052a670 / last-type14052a8e0 | Canonical creature activity16 and stored module ID/BYTE history, including absent-object/module defaults. |

Full original ASM lives in `native-spell-preparation-rest-owners-v1.txt`,
`native-rest-resource-cancel-owners-v1/v2.txt`, `native-rest-script-item-owners-v1.txt`,
`native-rest-constants-item-leaf-v1.txt`, `native-rest-clear-query-owners-v1.txt`,
`native-rest-domination-removal-v1.txt`, and existing full module/2DA/creature
constructor/load captures. Some decompiler bodies truncate at free(NULL); the
full unwind ranges and closed leaf CFGs are authoritative.

## Shared implementation

`rest.js` ports request/action/cancellation/input/module-event semantics.
`rest_resources.js` ports effect cleanup, inventory traversal and domination
removal; `spell_book.js` owns recovery of the canonical spell pools. RestRuntime
connects active RestDuration.2da and ruleset, existing nearest-enemy/perception,
activity/action managers, affliction owners, effect removal, native equipment/
repositories, active-item use caches, HP, feats and encumbrance. No campaign name,
character preset, NPC tag, spell template or fixed rest duration selects behavior.

Prepare never readies a new spell. Action42 progressively restores spells after
the first duration third, heals at the original integer intervals, checks enemies
every500ms, and restores all remaining resources at completion. Interruption
preserves already recovered resources. NPC/associate/player paths retain their
different admission and event behavior. Undefined native subtraction outputs or
division-by-zero are explicit failures rather than fabricated elapsed values.

Rest input uses the canonical local FIFO; actor/area/session changes discard old
requests. The HUD Rest button uses input13, progress uses a local client GUI
timing projection, and Escape cancels through the real action cleanup. The model
bridge selects native animation47 (`sitcrossps`). The five rest script commands
are bound through the existing VM, and ScriptRested is imported for NPC script9.

The ApplyEffect adapter now registers newly retained matching-ID effects in the
same +170 NativeIdList already used by created AoEs. Classification is subtype8
or timed item property91, using the captured ApplyEffect14048e350 tail. Tracking
runs after application callbacks; removal reuses existing RemoveEffectTarget.
This is a focused adapter correction, not a claim that the entire native common
ApplyEffect owner has been ported.

Two early research labels were corrected before runtime binding:1404998a0 is
RunEventScript, not animation;1403d7160 removes domination, not an associate.
Also, area328 in SetExcitedState/UpdateExcitedStateTimer is CNWSAmbientSound;
its virtual+20 is PlayBattleMusic1403588d0. Earlier “rest controller” descriptions
of that field are wrong. Existing battle-music adapter work remains open; the
rest action itself reads the shared excitedDuration574 and cancels normally.

## Validation

- `inspect-native-rest.py`:651 request,287 action,96 cancellation,96 decoded
  input executions =1130 original comparisons.
- `inspect-native-rest-resources.py`:1800 ready,20 highest-known,192 removal,
  197 clear-caster,360 bulk-property,4 nested inventory,32 domination and24
  module-event executions =2629. Total3759 comparisons, with ordered callbacks,
  uint widths, raw started0x01010101, cursor quirks and retained storage.
- `rest-native.test.js` and `rest-resources-native.test.js` match final original
  observations and check stale local input. Initial fixture failures (missing
  timer boundary, pool-label/allocation errors) are retained in earlier logs;
  final observations use independently allocated records and canonical labels.
- Installed probev2: dynamic stock scroll50 is learned, prepared unready, then
  recovered by ordinary rest; HP67→77, all stack/charge counts unchanged; timed
  caster effect tracked then removed. The authored `NW_S0_EndEle` impact runs
  once and spends the slot. VM ActionRest starts a second rest, cancellation
  leaves its slot unready, ForceRest restores it without changing canceled
  history. Installed `m1q0_rest` is delivered by the actual module events1/2/3.
- Rendered UIv4: unchanged installed wizard plus unchanged stock scroll fixture,
  inventory wheel learning, Prepare drop, HUD Rest, timing bar, animation47/
  sitcrossps, ready pool, cast/self targeting/consumption and Escape cancellation.
  Native AI remains enabled; startup/entry fixture is explicit. Browser errors0,
  new error-severity failures0. Known absent plc_w02 PWK remains recorded and
  separately classified. All warnings remain in the report. UIv1/v2 snapshot
  initialization races and v3 stale closed-panel diagnostic snapshot are retained;
  corrected fixture waits for refreshed canonical data. Final PNGs were inspected;
  the rest pose is also verified by the actual model animation event, since the
  current camera has substantial dark/occluded world geometry.
- Existing rendered prepared item-target/F2/wheel/cancellation regression passes
  with engine omissions0 after shared caster-target tracking.
- Full1644 tests pass (`rest-full-tests-v3.txt`); buildv2 passes, with the existing
  bundle-size warning. Active impact dependency auditv35 still lists88 unbound
  names and22 missing NCS; static binding presence is not runtime completion.

## Remaining acceptance

Rendered domain/associate/affliction/item-daily rest scenarios, exact native GUI
timing and feedback packets/art, pause/calendar event ordering, save/reload and
full campaign play are still separate gates. The native lower encumbrance,
domination/possession, stealth/dialogue and effect callbacks retain their existing
explicit unsupported branches when selected. No claim that spells, combat or the
campaign are complete follows from this continuation. Goal remains ACTIVE.
