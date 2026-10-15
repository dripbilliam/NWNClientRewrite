# Casting metadata, admission, caster context and travel timing

Target: NWN:EE `89.8193.37-17`, original read-only
`../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
No original game or Ghidra project files were changed; no agents were used.
Prior sealed checkpoint: `backups/live-native-casting-actions-1211-20261014.zip`.

Final sealed checkpoint: `backups/live-native-casting-metadata-1225-v3-20261014.zip`,
3911 files,23627733 bytes. All manifest entry lengths and SHA256 hashes verified.
This bookkeeping backlink was added after sealing; source/captures/evidence
preceding it are archived. Superseded1225/v2 archives remain retained.

**Casting is still not playable.** The spell UI records its placeholder;
command casts/actions15/18 and resource consumption callers remain unbound.
Ordinary release failure/concentration/defensive checks, impact scripts/effects,
interruptions, automatic Quicken and animation/recipient integration remain
required. Pure fixture providers must never be used as permissive live gates.

## Active metadata and component admission

`castingSpell` reads active physical SPELLS rows, preserving native field widths:
ConjTime+70/CastTime+e0 DWORD; ConjAnim+74/CastAnim+dc WORD;
Proj+128/ProjType+140 INT; UserType+184 BYTE; SpontaneouslyCast+188 INT;
Master+178 DWORD and MetaMagic+18c BYTE, plus VS+40, first Range character+30,
full ImpactScript CExoString+58 and TargetType+50 WORD. Missing Master retains the
physical row ID. ImpactScript is not prematurely lowercased or truncated to
a resource reference. The adapter reads current session rules rather than
embedding spell IDs, durations, damage or campaign-specific script names.

Loader blocks1402b0862..08f3,1402b0fce..11ab and1402b1cb4..1eba verify
animation/path enums. Point/touch are6; attack7; creature8. Native comparison
loops retain NUL-inclusive counts for some values; guessing a sequential enum
would produce wrong animation states. Unknown names select0, including JS
prototype-like keys. C2DA GetSTRINGEntry1401a68f0 supplies physical first-column
selection, empty cells and unavailable row/column default behavior.

`checkSpellComponents` maps ordinary AIActionCastSpell admission
1403ae4e6..1403ae997. Master-spell metadata gates metamagic. Somatic/verbal
requirements use native component bits4/8. Exemptions require exact raw
metamagic32/16, not just membership in a combined mask. Automatic Still/Silent
use native feat IDs, BYTE spell level/cost arithmetic and active ruleset caps
with strict level<cap. Automatic Silent's domain255 fallback differs from Still;
the original expanded comparison caught and corrected this distinction.
Failed master/metamagic admission preserves the consumed guard; component
failures clear it, clean round/pending gear, then send native feedback210/211.
The ordinary timing coordinator now requires an explicit admission outcome and
passes automatic component flags to the remaining release provider.

The live SpellBookRuntime metadata/component adapters are available, but their
timed casting caller is not yet bound. They do not spend a spell slot themselves.
The original shape/target gates and ordinary release checks remain dependencies.

## Caster level and script context

CNWSObject GetCasterLevel140494ee0 maps AoE/current override, equipment/polymorph
override, ordinary class, feat-source class, spell-like and placeable fallback
paths. The first type62 effect stops the scan even if its integer7 is nonpositive.
Missing spell-like level followed by missing spell lookup preserves255; a valid
fallback spell produces10 for every Innate BYTE under the native max/min sequence.
No attempted correction of that original quirk is made.

GetClassLevel1403fa4f0 accepts a class slot INDEX. It subtracts +25e's BYTE,
already owned as skillPenaltyByte, then applies CLMultiplier only for spellcaster
classes meeting MinCastingLevel with their unpenalized level. Scaling is float32,
CVTTSS2SI, then BYTE. CNWClass ctor1402992e0 does not initialize +518/+51c;
LoadClassInfo1402a7003/1402a70ca only writes successful optional cells. Selected
missing minimum/multiplier reads fail instead of inventing defaults.
GetIsClass140402dc0 returns the first slot; its complete leaf CFG was decoded
from the verified call at14049503a. GetFeatSourceClass140401b30 scans retained
level-up records in native order using the BYTE total level.

GetCasterLevel, GetMetaMagicFeat, GetSpellCasterItem, GetSpellTargetObject and
GetSpellTargetLocation are live alongside the earlier six queries. Creature
ctor14037ae6a/14037aecf/14037aed6 initializes override820/value824/caster-item818.
The item query reads that same818 cell already used by the pure timed coordinator.
The prior Field97c and EquipmentLock97c research names are now aliases of one
DWORD. Caster/queue and skill/equipment owners observe the same mutations;
contradictory imported aliases fail explicitly.

Target-location command140530920 copies the stored cast point and the caster's
raw orientation. A successful target lookup uses its area even if that area is
null; only a failed lookup falls back to the caster's area. Object/valid-script
gates and zero/invalid location defaults match the original. A native orientation
vector is retained alongside the existing local scalar compatibility metadata.
Impact-history writes, save DC and AoE construction remain separate owners.

## Projectile timing and math limits

`calculateSpellProjectileTime` maps14048fe20: no projectile or exact-one
carried/equipped-item membership means zero travel. Missing targets retain the
native zero-distance behavior. Other targets/location requests use native3D
distance and `3*log(distance)+2`, with path-specific factors/fixed-time behavior.
Path0 reads the default low BYTE, but the spiral tail tests the full INT and adds
2500 only on that branch. Low DWORD storage of native float-to-int64 conversion
and early returns are retained.

`native_log.js` traces CRT logf140c946b0's reduction tables and float arithmetic.
Only numeric constants/tables are copied. Original SSE instructions match6018
inputs, including subnormals; an independent installed ucrtbase.logf comparison
matches a traced branch for each. The original FMA/AVX emulator attempts failed
or produced invalid outputs. Their captures are explicitly retained separately
and are not parity expectations. FMA arithmetic is instruction-derived with
exact BigInt single rounding; original FMA/process CPU-state validation remains
open. The projectile helper computes both branches and rejects differing final
travel times instead of guessing a CPU mode. Exceptional negative/NaN/Infinity
log inputs fail; zero's return value is known, but CRT errno/status is a separate
boundary. The projectile core is not live bound yet.

## Validation

|Original capture|Cases|Limits|
|---|---:|---|
|native-logf-observations.json|6018|Original SSE; CRT exception helper captured; independent Windows CRT is supplementary|
|native-spell-projectile-observations.json|1562|Original travel/magnitude/log SSE; lookup, inventory and CRT sqrt captured|
|native-casting-metadata-observations.json|408|Loader mapping/stores; 2DA reads/ASCII lowercase/CRT strcmp captured|
|native-caster-level-observations.json|982|Class/index/feat-source execute within caster query; effect integer, spell-like and spell lookup captured|
|native-spell-context-observations.json|865|Nine scalar/context location commands and constructor stores; VM/lookup/casts/area boundaries captured|
|native-cast-action-observations.json|1526|Timing plus component admission; release/impact/time/round/presentation boundaries remain captured|

These files contain11361 bounded cases, including expanded earlier context/action
captures. They do not establish complete spell, original CPU, campaign or network
parity. Earlier sealed checkpoints preserve their earlier observation versions.

`casting-metadata-caster-full-suite-v3.txt`:1225/1225 tests.
`casting-metadata-caster-build-v3.txt`: build passes; existing bundle-size advisory.
`casting-metadata-caster-combat-regression-v2.txt`: retaliation, approach, kills
and encounter deactivation pass under concurrent suite/build/data audit. Missing
plc_w02/script1 and the same six omitted readiness owners remain recorded.

`casting-active-data-1225.json`:840 active spell rows and45 class slots across39
installed BIC files pass. These are independent data/class fixtures, not fresh
full imports or authored casts. The earlier Pale Master102/114 HP import mismatch
and campaign startup readiness failures remain open; this audit does not waive them.

Failed captures are retained: unsupported/invalid AVX runs; initial metadata
scratch-stack bounds failure; the component runtime fixture lacking UserType1;
the original domain255 Silent/Still distinction. The new backup allowlist includes
trusted observations and explicitly named invalid AVX observations separately.

Final field review caught an initially over-wide TargetType adapter and wrong
note offset. Original store1402b01a1 proves WORD+50; this now has its own native
cases. The earlier1225 archives are retained as superseded checkpoints. The
final v3 adds the shared97c cell fix, corrected target field, expanded capture,
and repeated suite/build/encounter checks.

## Next

Map ordinary release spell/arcane failure, concentration/defensive casting and
automatic Quicken; GetSpellSaveDC and remaining spell-script queries; native
SpellCastAndImpact14049c4b0 context/events, authored ImpactScript and effect
execution; requests/actions15/18, consumption, cancellation/interruption and
renderer cast animations. Then validate an authored cast without missing owners.
