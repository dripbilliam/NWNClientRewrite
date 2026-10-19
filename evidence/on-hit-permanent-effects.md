# Permanent on-hit effects, wounding and vampiric healing

The active single-player spell/combat/campaign goal continues. This increment
adds eleven native attack-payload builders, the alignment slaying gate and the
wounding/vampiric application and periodic owners. It does not complete the
spell ecosystem, combat, corpse lifecycle or campaign acceptance.

Read-only target: NWN:EE89.8193.37-17 x64,
`../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
No original installation or Ghidra project changes. REA dossiers and native
captures remain under `backups/animations/`.

## Original owners and delivery

| Owner | Inclusive original range | Result |
| --- | --- | --- |
| ApplyOnHitPoison | `1403e0fb0..1403e11a7` | Creature weapon: table poison35[param]. Ordinary: explicit ability/dice/DC payload35[2,param,1,2,DC]. Subtype8/permanent. |
| ApplyOnHitDisease | `1403df6e0..1403df7a5` | Disease5[param], subtype16/permanent. |
| ApplyOnHitAbilityDamage | `1403de480..1403de612` | Instant visual91 followed by ability decrease37[param,1,5]; creature weapon subtype16, ordinary24. |
| ApplyOnHitLevelDrain | `1403e0cd0..1403e0e5e` | Instant91 then82[amount,1]. Creature weapon amount=paramBYTE+1/subtype16, ordinary1/subtype24. |
| ApplyOnHitSlayRacialGroup | `1403e1740..1403e18c4` | Repeats creature/raceWORD gate before instant50 and death19[0,1]. |
| ApplyOnHitSlayAlignmentGroup | `1403e15a0..1403e1738` | GoodEvil then conditional LawChaos BYTE gate, visual50/death19. |
| ApplyOnHitSlayAlignment | `1403e1420..1403e1599` | Redundant cast, then complete GetCanSlayAlignment, visual50/death19. |
| GetCanSlayAlignment | `1403e3760..1403e382a` | Creature gate; LawChaos then GoodEvil. Nine alignment pairs; raw parameters9..255 return1. |
| ApplyOnHitVorpal | `1403e2280..1403e233a` | Death19[0,1] without the slay visual. Existing dispatcher owns critical/save admission. |
| ApplyOnHitDispelMagic(property) | `1403df900..1403df9ca` | Effect51[10], subtype8/instant. Saves attack BYTE before allocation. The item-spell overload remains separate. |
| ApplyOnHitWounding | `1403e2340..1403e242e` | Wound84[creatureWeapon?paramBYTE+1:1], permanent, no subtype. |
| ApplyOnHitVampiricRegeneration | `1403e2190..1403e227f` | Effect86[raw costWORD,total strike damage], instant. Reads/appends the same saved attack index. |

`src/on_hit_instant.js` ports engine methods, not individual spell scripts.
Properties retain active 2DA/chance/save admission. Effects append to attack+b0
and arrive through existing combat event5, canonical object references and
normal effect owners. No direct on-hit HP overrides or campaign exceptions.
GetTotalDamage1403767a0..140376a37 executes in the oracle; signed-short
components below zero are excluded. Existing `totalAttackDamage` supplies the
same result in the runtime.

## Correct full rules key

Native FNV call sites print a suffix `NHIT_EFFECT_DC` but pass the seed already
hashed with initial `O`. The complete key is **ONHIT_EFFECT_DC**, FNV64
`e7ee69e2c0067ae9`. Both dispatcher and poison builder now use this full key.
The previous dispatcher used the suffix and missed active rules overrides.
The dispatcher oracle now executes original FNV instructions instead of a fake
constant result. All1312 dispatcher cases recaptured and passing; focused
coverage verifies successful cost-cell precedence, full-label overrides and a
decoy suffix-only row that must not override default20.

## Wounding and regeneration lifecycle

- OnApplyWounding140435640..1404356cc copies with icons=1, makes icon67[129]
  with the SAME effect ID, and returns0. It does not initialize tick stamps.
  OnRemoveWounding returns1; shared-ID removal clears its icon normally.
- OnApplyVampiricRegeneration140434d80..140434e79 looks up the canonical creator
  creature. A present creator receives a new instant39 healing effect for the
  signed minimum of cap and strike damage. The original86 always consumes.
  No positive clamp, fabricated target healing or extra live regeneration state.
- Wounding UpdateEffectList14049e0ce..14049e1dd uses shared regeneration-pass
  subtraction scratch, including untouched outputs on failure. It repeats the
  native casts/dead gate; missing/different-area source queues event14, then a
  final due tick can still execute. Strict unsigned elapsedTime>6000, one tick,
  stamps=now. This owner does not restart the outer scan.
- ApplyWounding140382570..1403828fa queues damage38 through event5, amount in
  GetDamageIndexFromFlags(0x1007), remaining components-1, integer33=1000,
  flags34=0x1007. Signed nonpositive amounts warn and are preserved.
  GetDamageIndexFromFlags1402a3b60..1402a3b70 is a numeric bit-index loop,
  not an authored damage-table lookup. Original instructions execute in oracle.
- Blood colour comes from active physical Appearance/BLOODCOLR. Exact W or
  stateBYTE15 selects238; R109/G110/Y111; other strings still apply visual0.
  The visual has the native default invalid creator, independently of damage.
- Existing healing39 removes all live wounds through normal shared-ID removal,
  so ordinary healing and vampiric healing cure wounding without special HP code.

## Verification and limits

`inspect-native-onhit-instant.py` executes twelve COMPLETE original owners
(eleven builders plus alignment gate), GetTotalDamage, SetInteger and FNV:
**596 cases PASS**. Base construction/allocation/SetCreator, target casts/stats,
cost/rules access and attack append are captured lower boundaries. Cases cover
raw BYTE/WORD narrowing, alignment cross-products/defaults, signed damage,
allocation failures and saved-versus-reread attack indices under creator mutation.

`inspect-native-wounding.py` executes complete84/86 application, ApplyWounding,
the exact periodic branch, original copy constructor, INT access, damage-index
and subtraction: **275 cases PASS**. Captures base allocation/constructor,
SetNumIntegers, SetCreator, active string output, source/dead and event/apply.
Native allocation-null dereferences are excluded, not converted to success.
Boundary, backwards time/shared scratch, source/dead/noncreature, signed values,
icon flags, blood case/NUL and state-byte tests preserve observable call order.
The first oracle attempt had an incorrect captured stack offset; corrected
against original x64 call-site instructions, v2 completed without source changes.

Installed Prelude/cleric/goblin probe **v6 PASS9 checks**:
real property admission and event5 for retained poison35, disease5, ability37,
direct dispel51, wound84/icon129, positive vampiric healing3 and2 from strike3
with caps4 and2, source-area removal/final tick, and last-level drain death.
Wound exact6000 leaves HP unchanged;6001 deals1. Healing removes wound/icon.
Native death callback creates one legitimate item575 (`nw_it_mglove004`);
cursor575->576 and ALL prior canonical object references remain identical.
Reports retain72 load diagnostics and3 gameplay records: damage reaction,
temporary-HP presentation omission and corpse cleanup/body-bag omission.
Those omissions remain open; PASS is scoped to assertions, not an issue-free run.

Probe uses owned temporary property variants, fixed injury/stamp phases and
explicit seed search. Poison has an independent application-save seed search;
v4's zero-cap vampiric case was strengthened to positive caps. First installed
fixture incorrectly expected retained82 after draining a level1 goblin; native
death is the correct result. Scheduler records also required `.event.eventId`,
and the registry check now records legitimate authored death-item creation.
These were test expectation/capture corrections, not gameplay exceptions.

Regression: **1975/1975 tests PASS**, build PASS (existing bundle-size warning),
installed common-duration/control-frame probev6 PASS13, and live casting UI
PASS: spellbook, right-click self casting, slots, F2 targeting, cast animations,
cancellation and22 counterspell/radial checks. Full suite/build/UI logs prefixed
`onhit-instant-`. Source-changing work finished before these final checks.

Next: remaining item-spell on-hit dispel/Knock overloads and door lock binding,
then native death/corpse cleanup/presentation. Generic effect admission/import,
other remaining engine calls, continuous AI and campaign playthrough stay open.
Goal ACTIVE; single-player first. No pause or completion claim.

Verified checkpoint `backups/on-hit-permanent-1975-20261017-v1.zip` contains
10762files/149126665bytes. Every archived length and SHA256 matched source;
`on-hit-permanent-checkpoint-v1.txt` terminal0. This verification note was added
after sealing; no checkpoint writer or validation remains pending.
