# Item casting execution and resources

Target: NWN:EE `89.8193.37-17`, x64 `nwmain.exe` SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original install and Ghidra project remain unchanged. Read-only static analysis
and isolated execution of original instructions provide the comparisons below.

## Owners and verified behavior

`item_cast_action.js` ports AIActionItemCastSpell `1403c07b0..1403c1a27`.
The decompiler truncates before the main body, at string cleanup; complete
assembly and executed instruction comparisons are authoritative. Action46
stores its own day/time in physical slots7/8, independently of ordinary action
start time. Its saved fields are item, property, variant, target, XYZ, day,
time, consume. Property lookup uses INT, but remaining-use lookup and child
selection narrow to BYTE. Selected child metadata controls the action.

Native base-item switches are retained: potion49/104 release750/total1500 ms;
54/75 release2500/total2500+CastTime; other bases release500/total500+CastTime.
Animation IDs70/71 depend on the live creature appearance MODELTYPE containing
uppercase P/F. Base81 uses10; other release phases use17. The recipient, rather
than the caster, drinks when an owned creature receives base49/104. The live
appearance provider uses the same GFF-backed WORDa74 owner as the rendering and
appearance commands, avoiding an invented cached field that would select row0.

Two static-research interpretations were corrected before acceptance. The call
at `1403c136f` resolves **GetPlayerCharacter140392ec0**, not GetIsInCombat.
It tests creature89c or possessed-familiar control. Native difficulty option2
(`GetDifficultyOption14055b420`) participates in the opportunity-attack gate
for bases49/54/104. The potion round setting is **FAST_SPELLCAST_ROUND**: the
hash helper receives the suffix AST_... and a precomputed F seed
`af63fb4c86022139`. Original comparison with an override verifies the full key.

Pre-release writes item818, featFFFF, zero metamagic/spontaneous, projectile
time, iprp_spells.CasterLvl824 and override820=0. Release sets override820=1,
uses shared SpellCastAndImpact14049c4b0 with class255/itemID, and removes round
spell actions when started==1. No class/innate pool is consumed. Insufficient
uses fail with native status3 and feedback23, after animation/round cleanup.
Node9c becomes0 during activation; ClearAction46 honors this noninterruptible
phase. Cancellation before activation clears828, independently of ordinary
casting's81c. Original ClearAction `1403870b0` branch251..289 and shared tail
were executed in the lifecycle fixture.

Resource owners SetCharges14046c440 and GetUsedActivePropertyUsesLeft140469170
execute complete original instructions. SetCharges clamps signed INT0..250;
nonzero update rewrites charge-cost2..6 readiness, without notifying the cache.
Uses-left returns WORD, but stack count is first narrowed to BYTE. Charges cost
5..1 for property cost2..6. Daily costs8..12 decrement UsesPerDay BYTE and clear
readiness on exhaustion. Cost1 decrements stack INT or depletes the last unit.
Unlimited7/13 bypass the uses-left gate. Consumption only occurs when slot9 is
nonzero. An exhausted item schedules event11 for projectile-time+500; charge
items also scan remaining active charge properties before destruction. Plot
items remain protected at this scheduling boundary.

`item_charge_command.js` binds real GetItemCharges607/SetItemCharges608. Getter
returns raw charges or0. Setter clamps, and for nonplot zero charges schedules
immediate event11 **without first overwriting charges/readiness**. Other values
call shared SetCharges then active-use cache notification.

`item_destroy_event.js` ports item EventHandler140466f70's complete event11
branch140467c22..140467f66. Receiver is item+48; canonical item ID is item+50.
Destroyable, independently of plot, gates delivery. Container clients close
before possession removal. Creature removal, item/placeable repositories,
store removal, missing-owner dialog references, RemoveFromArea and destructor
retain native ordering. Unknown owner types skip SetPossessor. Field464's
proposed last-holder name is an inference; its offset, constructor value and
use in the missing-owner dialog branch are directly evidenced. Runtime has the
actual creature/repository/area/destructor adapters; container client closing,
placeable inventory load flag, store and active-dialog adapters remain explicit
failures when selected. These are not silently treated as successful deletion.

`item_input.js` ports decoded subtype9 within full
HandlePlayerToServerInputMessage1404531b0, branch14045360b..140453780. It preserves
optional variant/target/point reads, field8ac/area/overflow gates, action manager,
UseItem feedback23 only on result0, and native handler result0 even when the
action queues successfully. ModuleSession.queuePlayerUseItem serializes this
with existing player inputs and rechecks control/session area. Item UI should
judge queued/action state rather than inventing a boolean packet acceptance.

## Validation and limits

- `native-item-cast-action-observations.json`: 5,312 full action executions;
  clock/table/object, round, opportunity, projectile/presentation, impact,
  cache/event calls are captured boundaries. Consumption and charge helpers
  execute original instructions. Branches include resource exhaustion,
  duplicate-impact guard, elapsed jumps, variants, recipient animation,
  unsigned timer arithmetic and full rule-key overrides.
- `native-item-cast-lifecycle-observations.json`: 36 SetCharges, 5,040 uses-left,
  30 setter, 3 getter, 18 cancellation, 488 full item-event executions. VM
  pops/push, client/object/repository traversal and lower destruction calls are
  controlled providers. The initial event fixture passed event11 in the wrong
  register and did not exercise destruction; v2 fixes it and is authoritative.
- `native-item-input-observations.json`: 587 complete original input handler
  executions, dispatched subtype9, with decoded read/manager/UseItem providers.
- `installed-item-casting-v6.json`: untouched installed wizard inventory in
  Prelude, startup/general AI disabled. Canonical player565/potion570, stack
  3→2→1→removed. First use enters through typed VM309; subsequent uses through
  decoded player item9 and its input queue. Each authored NW_S0_CurCrWn impact
  and nested x2_pc_umdcheck runs with item caster level7; actual HP67→77 after
  injury via the shared damage owner. Class/innate pools unchanged. Last impact
  at7200 ms, destruction at7700 ms removes registry, inventory and repository
  membership. Typed commands607/608 separately prove stored7 remains until the
  immediate zero-charge destruction event, then getter0 for the removed ID.
  Actual item reload/asset failures and presentation omissions remain recorded.
- All1,603 automated tests pass; production build passes. Active dependency
  auditv33 has88 unbound names and22 missing NCS resources. Binding presence
  does not establish full branch implementation or campaign readiness.

The wheel/hotbar item-use entries still need their client selection/targeting
owners connected. No rendered item-use acceptance, full scroll/wand equipment
acceptance, completed spell ecosystem, completed combat, or campaign completion
is claimed. Spell release/projectile presentation diagnostics remain explicit.
