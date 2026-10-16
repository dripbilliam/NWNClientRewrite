# Shared spell owners, October 15 2026

Target NWN:EE 89.8193.37-17, unchanged installed x64 nwmain.exe SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original assets and Ghidra database remain unchanged. Reports contain derived
observations and metadata, not copies of game binaries or assets.

## Mapped and connected

- October15 EffectPolymorph463 construction and internal racial68 now connected.
  Active FeatsTable WORD pools create innate vision/visual children; group
  removal clears them. Upper polymorph apply/remove follows native admission,
  icon/bonus feat ordering and half-second reversal, with full lower transform/
  restoration captured and type62 application still UNBOUND.3747 original cases,
  1566 tests/build and installed race/owned-VM probes pass. Authored spell387
  reaches the recorded unimplemented type62 applicator. No full polymorph cast
  proof; audit97 unbound command names/22 missing NCS. See
  [implementation and limits](polymorph-effect-owners.md).

- October15 polymorph stat prerequisites: six native base setters and
  GetACNaturalBase now shared with the live runtime/projection. CON preserves
  injury using old cache/new max and exact flag1; both canonical9f4/97c guards
  switch natural armor to BYTEd51 without removing monk/feat contributions.
  2052 setter cases and2400 armor cases match original instructions;1560 tests,
  production build and installed stat/drain/recovery probes pass. Full form
  transformation/restoration/cancellation remains open. See
  [evidence and boundaries](polymorph-stat-owners.md).

- October15 shared removal/expiry: RemoveEffectById140498280 and source-target
  cleanup1404986c0 now honor callback1 vs retained0, full assignment/value
  equality, nested mutations and the live cursor. Generic UpdateEffectList
  traversal restarts after expiry or a mapped periodic owner ran.936 removal
  plus324 updater native cases pass;1557 tests/build and installed poison,
  disease, regeneration/recovery, restoration/drain and bonus-feat probes pass.
  Area/summon constructors retain native six-string storage. This resolves the
  deferred-removal prerequisite below; full polymorph remains open. See
  [evidence and captured-provider limits](effect-removal-lifecycle.md).

- October15 polymorph prerequisite: type83 bonus feat apply140427fd0/removal
  1404360c0/query140425ba0 and EffectBonusFeat1107 constructor now connected.
  Canonical bonus WORD pool20/count28/capacity2c aliases old pendingFeats;
  HasFeat reads this pool separately from permanent GFF.2876 original handler/
  membership runs plus18 constructor cases cover growth, sentinels, raw vsWORD,
  distinct/same effect-ID grants and retention. Original query algorithms run;
  allocator/memmove/item providers and constructor lower VM/feat lookup captured.
  Derived stat/HP/save projections now consume it; local refresh timing is an
  adapter, not full original recompute-scheduling proof. Installed duplicates,
  queued removal, passive saves/Toughness and PC289 strict expiry pass without
  permanent feat mutations. Full polymorph transform/cancel is still OPEN.
- Polymorph native full assembly captured: apply140430950/remove140437c80,
  transform140399e20/restore1403a5b50 and saved-GFF loader1403984c0. Ghidra's
  transform pseudocode collapses at first free; assembly is authoritative.
  Removal first returns0 and retains a half-second temporary parent, then
  untransforms. Current generic effect remover must honor callback retention
  and native value-equality/live-cursor behavior before type62 is bound.
  All1552 tests/build pass; negative-level lifecycle still passes. Auditv26
  has98 unbound impact command names/22 missing NCS; no cosmetic transform added.

- October15 negative levels: constructor462/type82, full apply14042f500/removal
  140437bc0, class-counter setter140415490/getter1403fa5b0, total14040a960 and
  GetLevel1404035c0 use canonical class BYTE25e.2691 handler/constructor cases
  plus424 support cases execute original copy/class/hash instructions; lower VM,
  rule lookup/creator/immunity/feedback/nested apply/slot refresh/events captured.
  Active rules control bounds and bonus HP. Linked penalties and highest-class
  assignment, byte wrapping/loading, independently owned source HP and lethal
  event5 preserved. No mutation of authored class level or new counter cache.
- Actual Enervation52 vs authored mage applies2, manual group removal restores;
  EnergyDrain51 vs1-level goblin produces death17->-11. Installed hostile mage
  vsPC seed4 and real Restoration70/152 cure lifecyclev3 verifies level/caster/DC
  15/15/16 ->11/11/12 ->15/15/16. Bonus HP5 remains after parent cure and expires
  strictly after18s. Failed fixture choices and saves retained; preset wizard
  had no readied52 slot, so no normal Enervation cast proof is claimed.
  Complete GetScriptEffectType140423fe0 mapping now matches all470 existing native
  cases, rather than only implemented effect subsets; missing82 translation had
  blocked cure scripts. This also fixes public poison/disease/regeneration reads.
  All1549 tests/build pass; auditv25 has98 unbound spell-used names/22 missing NCS.

- October15 equipped regeneration: property type51/ApplyRegeneration1404725f0
  now creates ordinary equipped type7 effects through the existing materializer
  registry. Native costWORD/cap20, zero-constructor consumption, creator,6000ms
  interval and loading match72 original executions with real effect ctor and
  SetInteger. Installed live-equipped-item-regeneration.json validates actual
  factory/add/remove, property-ID linkage, strict healing ticks, unequip stop,
  re-equip clock reset and linked icon removal on a plain dagger. Earlier item
  enhancement/all abilities/damage/light probes also pass in that run. Direct
  API/controlled NPC injury is distinct from item spell casting and rendering.
  All1546 tests/build/hidden item-casting UI pass. Audit99 unbound names remains;
  the regeneration property factory binding predated its missing materializer.

- October15 regeneration/healing/recovery: original EffectRegenerate164/type7,
  EffectResurrection82/type4, OnApplyRegenerate140430d80, Heal14042df10 and
  Resurrection140430e60 connected. Regeneration poll14049dba3..dd50 uses strict
  unsigned elapsed-time comparison, one tick and reset-after-heal only. Native
  subtraction675 cases now shared with reputation. Heal feedback151, live type84
  removal/recovery dispatch and resurrection's canonical flags/listening/actions,
  floaty903, message36/2 and temporary type57 removal match original handlers.
  Oracle covers399 constructor/apply/poll +462 heal +362 resurrection cases;
  actual copy constructor and GUI sender execute, lower VM/HP/AI/encumbrance/
  feedback/apply/removal providers captured. Full outer effect-list mutation and
  active area timer selection remain open. Local heal log is a presentation
  adapter; full native feedback151/death-GUI renderer remains diagnosed.
- Actual installed Regenerate374/MonstrousRegeneration525 heal and clean up
  their linked icons at strict tick boundaries; cleric prepared374 consumes1->0
  in normal cast/release/NCS path. RaiseDead142/Resurrection153 impact probes
  restore canonical goblin -10->1/-10->17. These controlled fixtures do not
  validate full corpse/death UI, ordinary recovery casting or campaign play.
  Their first failure identified old GetLocation missing facing-vector storage;
  original wrapper14052b130/leaf140495f30 now copy raw vectors/ID, use original
  invalid defaults and match387 cases. Installed lifecycle v2 passes, prior
  failure retained. All1546 tests/build/full casting UI pass; auditv24 has99
  unbound names/22 missing NCS. Saved effects, further effects and rendering open.

- October15 poison/disease: complete OnApplyPoison14042fce0,
  OnApplyDisease14042c1f0, ApplyPoisonPayload1403822d0 and
  ApplyDiseasePayload140381ab0 connected to active2DA/shared effects, plus the
  affliction poll block14049dd55..de8a. Comparison uses710 native handler cases,
  450 actual world-time executions,21 effect equality,9 copy,8 constructor,
  12 self-feedback and256 poll cases. Table/RNG/save/script/event/nested apply
  boundaries are captured, not replaced with claims of full lower-owner parity.
  Original copy constructor preserves immunity override but clears payload;
  assignment preserves full values. Queued event5 now calls native apply without
  script duration normalization. Parent/icon cure does not cure independently
  owned ability damage. Native disease prior-save flag remains set on failure.
- Installed Poison129/Contagion27 impacts and their timed lifecycle pass; normal
  prepared Quillfire425 request/slot/release/NCS also passes, uses2->1. Lifecycle
  v3 checks before/exact secondary deadline, incubation/daily saves and cure,
  and final independent ability-group removal. Fixture limits: seed1, unrelated
  AI disabled, startup off, no continuous campaign/rest/saveimport/rendered
  affliction acceptance. Missing plc_w02.pwk remains in loadDiagnostics. All1541
  tests/build pass; static auditv23 has101 unbound names and22 missing NCS/840rows.

- October15 query/control continuation: GetAppearanceType14051ec20 reads live
  creature WORDa74/placeable WORD32c/door DWORD3f8. GetCreatureSize1405213f0 reads
  canonical718; GetCreatureTailType140521470 reads stats E18, imported via checked
  DWORD Tail_New/BYTE Tail/retain-current block. Subrace140531050 copies stats
  CExoStringD28; modern decoded text is connected, legacy localized conversion
  remains explicit. SetMode1403a3510 compares raw INT state before shared
  ToggleMode, and both script/radial now share that owner. Enabling/changing
  stealth/detect activity still selects a diagnosed lower lifecycle gap.
  Set/GetDroppableFlag140540ee0/140522b30 use the canonical raw INT448, already
  consumed by inventory/acquisition/corpse owners. No template mutation or new
  gameplay IDs. Query oracle:132 wrapper observations (valid decoded outputs
  compared, VM error statuses captured),3420 SetMode,36 import-block,100 flag
  setter/getter and40 Subrace cases. Lower object/VM/GFF/string/Detect/Toggle
  operations are captured boundaries, not claimed full lower-owner ports.
- EffectPetrify583/14051ab90 uses the existing type8/kind15 pipeline. Constructor
  v4 adds its original output to the13 prior constructors; base construction,
  creator and VM ownership are lower captures. Shared SetState/Internal and
  group removal already have independent original comparisons. Actual installed
  Flesh-to-Stone485 on a goblin produces state15/icon109/visual records207,351,352;
  removing the group clears effects/icons/looping and restores state0/flags65535.
  Native OnApplyPetrify14042fbf0 was inspected but is not the type selected by
  this script constructor; do not invent a new type mapping for it.
- Installed direct impact probes: Sunburst427 damages goblin17->-16 after the
  appearance/subrace reads; Gust75 completes after its helper item's droppable
  setter, and Bigby460 queries size without engine errors. Seed1/impact8 and
  unrelated AI disabled are fixture limits. These do not validate cast request,
  slots/release, full rendered petrification, original-process encounters or
  campaign acceptance. All1535 tests/build and hidden full radial/casting UI
  regression pass. Static audit v22 has103 unbound names/22 missing NCS resources
  across840 rows; bound is not synonymous with fully implemented.

- Script casting: ExecuteCommandCastSpell140511540 binds object/location and
  fake-cast commands to canonical action queues. Class type remains distinct
  from class index; default metamagic uses actual ready-slot metadata. Placeable
  casting remains explicitly unsupported. Tests: script-cast-runtime.test.js
  plus the existing native command coordinator comparisons.
- Touch attacks: ExecuteCommandDoTouchAttack140516710 uses separate melee/
  ranged touch bonuses, target signed enemy-attack byte, touch AC, native RNG,
  current combat defensive record, confirmation and separate client feedback.
  `inspect-native-spell-touch.py` compares untouched instructions at captured
  lower boundaries. Nonrolling-target feedback's indeterminate scratch value
  is recorded as unavailable rather than fabricated. Stats constructor
  1403ee4b4 clears the target byte at D54 via its WORD D53 initialization.
- Beams: EffectBeam140517cb0 admits active Type_FD exactly B after uppercasing;
  source object, body part, miss and optional grouped transforms are preserved.
  OnApplyBeam140427a20 copies a hidden shared-ID visual child; OnRemoveBeam
  140435fd0 returns1. 1,080 original constructor cases compare in beam-native.
  Lifecycle tests verify linked removal and strict-after expiration. This is
  effect ownership, not complete beam rendering.
- Blindness73/16, darkness74, vision69, miss chance75, SeeInvisible70,
  UltraVision71 and TrueSeeing72 use native flags and shared-ID children.
  Owners: 427bb0/435fe0, 42a590/436590, 434e80, 42efa0,
  4315e0/4382d0, 434be0/4394f0, 434990/4392b0 (all image base140000000).
  Special vision removes active darkness blindness and retains an inactive89
  copy. Removing the final source reactivates it only with canonical membership
  in native darkness AoEs36/345. These IDs are native owner constants.
  `inspect-native-vision-effect.py` compares blindness/darkness/deafness gates,
  child calls, removals, vision filters and miss admission with untouched
  instructions. Source deactivation/reactivation is statically mapped and
  integration tested; its mutation loop has no independent native oracle yet.
- Deafness21: shared ExecuteCommandEffectComplex1405180b0 ordinal150 chooses
  type21 (constant140de7af8), subtype8, current creator. OnApplyDeaf14042a790
  checks loading/dead, immunity8, plot; creates shared type23 mask-17 and icon7;
  exposed records send floaty2229. Existing hearing and verbal failure owners
  read the resulting bit16. GetEffectType returns installed public type13.
- Conversion: player message18 block14045498f..140454ba7 checks active class
  CanCastSpontaneously, ordinary uses and ready non-domain slots. 768 original
  cases compare in spell-conversion.test.js. Class loader1402a71ef..1402a7247
  proves the column populates +520. CNWClass ctor1402992e0 does not initialize
  that field: missing/empty class entries are diagnosed as indeterminate when
  selected, rather than silently treated as an enabled/disabled conversion.
  AIActionCastSpell1403ae430..1403ae49d can
  automatically select conversion when ordinary uses are zero and the spell's
  SpontaneouslyCast flag and GetSpellsOfLevelReady permit it. Consumption at
  1403af4d3..1403af655 selects the first ready non-domain slot at the effective
  level and consumes that slot's spell/metamagic. Both context writes preserve
  the resolved conversion flag. The original empty consumption scan still
  marks consumed; the replacement preserves that behavior. Expanded original
  cast-action oracle has3,686 rows, including requested/automatic conversion,
  failed consumption, empty/null/domain/not-ready and BYTE readiness cases.
- Dispelling: ExecuteCommandEffectComplex1405180b0 ordinals460/473 create
  types51/52 with caller level. OnApplyDispelAllMagic14042c720 and
  OnApplyDispelBestMagic14042cbd0 test magical duration1/2 records once per
  uint64 ID, compare d20+level against max(0,effect caster level)+11, and queue
  event14. Best's native scan selects its first eligible record; it does not
  sort a new array by spell level. 3,024 original cases compare roll/order,
  duplicate IDs, client messages, flags, missing source and allocation-growth
  cases. Event14 removes the complete shared-ID group for verified creature,
  item, door and placeable receivers. Other receivers remain explicit.
- Damage shields61: constructor140519760 clamps unsigned base and damage
  flags; apply14042a4c0 creates shared icon49. ResolveDamageShields1403e4c50
  reads active IPRP_DAMAGECOST NumDice/Die, then DamageHitVisual VisualEffectID
  at rules tables+3e0 (Load2DArrays1402b9675/1402b96ba). It applies raw
  unprocessed damage38 and visual30 to the attacker for each live shield.
  OnApplyDamage140428828..14042888a and140428dc3..140428dd4 gate reflection
  on processed!=0/reflected==0, including zero incoming damage. 456 original
  cases compare construction/admission/table and payload order; two-shield
  runtime tests verify reflection terminates and spell/reflected damage skips it.
- Damaged casting: OnApplyDamage140428e6c..140429188 compares a new d20 plus
  signed Concentration rank against max(1,base spell level+CONCENTRATION_BASE_DC
  +damage). It does not add domain/metamagic costs. Failure deletes the current
  queued action via DeleteCurrentAIAction140491570, sets animation14, attempts
  consumption with stored class/domain0/meta0/caster255, feedback72, failure
  visual292/293, then skill message270. Success preserves the cast. 913 original
  block cases compare order, missing/fallback metadata and signed arithmetic.
  Live tests retain the original stored-class behavior: before the first
  completed cast, class255 makes the attempted consumption fail without
  aborting cancellation. After an actual Light cast sets class0, interruption
  consumes the ready Ray slot. No replacement-only refund/extra charge is added.
- Item-property duration: ExecuteCommandGetItemPropertyDurationType140529240
  returns duration low bits for type91 and -1 otherwise; it does not normalize
  duration3/4. Added to the existing original query fixture (488 total cases).

## Installed-script validation

All fixtures use isolated replacement sessions, startup and unrelated native AI
disabled; they do not establish campaign, multiplayer or original-process parity.

- live-casting-enemy-107.json: actual Magic Missile cast/resource/impact/damage.
  live-casting-enemy.json is the same107 result for the earlier evidence link.
- live-casting-enemy-144.json: actual Ray of Frost, touch attack, beam and damage.
- installed-vision-lifecycle-v2.json: installed See Invisibility, True Seeing,
  Ultravision impacts and removal restore canonical actor state. The self-target
  Blindness/Deafness case completes but applies no hostile effect.
- installed-blind-deaf-enemy-v1.json: installed Blindness/Deafness against an
  authored goblin creates types21,23,30,67,69,73,75 without engine failures.
- installed-darkness-lifecycle-v1.json: real persistent Darkness entry/heartbeat/
  exit scripts and canonical AoE cleanup complete without engine errors.
- live-casting-conversion-cleric-default.json: installed cleric converts a real
  prepared non-domain slot, preserving converted spell context and executing
  its authored impact script. No synthetic readied slots or proprietary data
  were written into the project or install.
- installed-dispel-lifecycle-v3.json: all four installed dispelling scripts
  execute their delayed actions and remove Light/Ultravision shared-ID groups
  created by an actual low-level module creature. Each removes two IDs and
  restores vision0. Earlier v1/v2 fixtures did not advance delayed actions;
  they are retained as failed fixture attempts, not successful acceptance.
- installed-shield-lifecycle-v1.json and installed-shield-hit-v1.json: installed
  Elemental Shield47, Death Armor519 and Acid Sheath524 apply/remove correctly
  and reflect a controlled processed hit through real mitigation, HP and death.
- live-cast-damage-v2.json: queued Ray of Frost survives a1-damage concentration
  success and executes its installed impact.20 damage cancels the cast without
  impact, both before and after a real prior Light cast, with the stored-class
  resource behavior described above. Incoming damage is a fixture, not a full
  independently played combat encounter.
- live-casting-ui-v14.txt and regenerated UI JSON/PNG: built-client spellbook
  click, self-target selection, dragging Light to F2, actual slot consumption,
  animation and Escape/right-click cancellation pass without renderer errors.

## Still open

Remaining branches of feat/item/placeable/talent casting, native conversion UI
selection, memorization/rest UI, complete projectile/release and effect rendering,
polymorph and further authored-script engine dependencies remain unfinished.
Earlier counterspell, summon, item-property and affliction work is documented
above; passing their covered paths does not establish all spell combinations.
Static binding counts are an inventory, not proof that a spell works. Every
unimplemented branch and failed asset/script load retains diagnostics.

Current validation:1,552 tests, production build and hidden full casting/radial
UI regression pass. Audit-v26 has840 physical spell rows,98 unbound command names and
22 missing scripts. Original-code comparisons above capture lower boundaries;
they do not establish full original-process spell parity or campaign acceptance.
