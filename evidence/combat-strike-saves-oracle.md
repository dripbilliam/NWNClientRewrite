# Strike, defense, saves and native oracle — 2026-10-12

Current implementation status is in [Combat action-loop checkpoint](combat-action-loop.md). The counts and remaining-provider lists below describe earlier checkpoints; the independent captures retain their stated scope.

## Status

Combat is **not playable end to end**. The Attack radial remains a placeholder;
these are native-traced providers and partial runtime adapters, not a completed
encounter loop. Casting and original-client coexistence are unimplemented.
This extends [reputation/lifecycle](combat-reputation-lifecycle.md).

Target: NWN:EE `89.8193.37-17`. Read-only inspection verifies `nwmain.exe`
SHA256 `3B7CB1252E0EDB2CE22D7971F333AADE027039AE30A45B4BC64732C3E6BEC73A`.
The original server hash is
`98951511AE7D06A251355F12D4F3E4B96269A2414FA3058E641AFD70098690F6`.
No game/Ghidra project mutations or proprietary asset copies occurred here.

## Verified static contracts

The controlling exports are under `backups/animations/`:
`live-hostile-setter-asm.txt`, `live-strike-roll-preparation-asm.txt`,
`live-sneak-defense-asm.txt`, `live-saving-throw-asm.txt`,
`live-save-object-table-asm.txt`, `live-load-2das-asm.txt`,
`live-effective-skills-asm.txt`, `live-skill-effects-asm.txt`, and
`live-skill-leaves-asm.txt`.
Bridge pseudocode remains supplemental: returning cleanup aliases can truncate
functions or invent early returns. The post-damage export
`live-post-damage-orchestration-asm.txt` contains the complete requested
post-damage body but stopped at a leaf lacking unwind metadata; it does not
contain the later requested cleave/circle-kick exports.

| Function | Address / calls | Implemented contract |
| --- | --- | --- |
| SetLastHostileActor | `0x14049b070..0x14049b254` | Forced IDs, plot/DM/dead rejection, AoE creator resolution, same-faction/PVP and dying-PC/familiar gates. Missing lookups preserve prior history. |
| ResolveSituationalModifiers | `0x1403ec070` | Native distance/coup eligibility, level limit and existing-record ownership. |
| ResolveCachedSpecialAttacks | `0x1403e45f0` | Independent type/parameter queues fill the first available current/future attack. Malformed local queues are diagnosed before consumption. |
| OffHandAttack | `0x140376400..0x140376431` | Current-index/count query, separate from consuming iterative modifier counters. |
| ResolveAttackRoll | `0x1403e4100..0x1403e45e9` | Offhand, d20, modifier/AC, precision, coup, defensive, parry, miss and confirmation ordering; critical immunity/difficulty feedback. Combat-debug mode remains explicit unsupported work. |
| ResolveDamage | `0x1403e4720..0x1403e4c55` | Damage record fill, maximize-use consumption, Defensive Roll, death attack, Epic Dodge, plot, physical/energy/on-hit/item-cast/visual ordering. Missing side-effect systems remain required providers. |
| SetBaseDamage / GetTotalDamage | `0x140379b00..0x140379b05`, `0x1403767a0..0x140376a38` | Base damage is component 12 / raw +2e. Sum nonnegative signed shorts; nonzero query flag excludes only components 0, 1, 2. |
| ResolvePostMeleeDamage | `0x1403e8f00..0x1403e979a` | Killing-blow gates, Devastating Critical, Crippling Strike, Quivering Palm, coup, cleave/circle-kick requests and weapon warning. Follow-up target/action/effect providers are still required. |
| ResolveSneakAttack / ResolveDeathAttack | `0x1403ebe00`, `0x1403e5040` | Cached visibility, full float distance, distinct ranged setup, class/Improved Uncanny Dodge gates, feat ladders, immunity and attack-owned feedback. |
| GetFlanked | `0x1403e3850..0x1403e3902` | Native stored-target tests (+724/+728/+73c/+740), not a geometric rear arc. +740 constructor initialization was checked at `0x14037ae33`. |
| ResolveDefensiveEffects | `0x1403e5630..0x1403e604d` | Ordered type 75/47/76 effects, visibility masks, self-concealment ladder, strict d100 comparison, Blind Fight, once-per-round Deflect Arrows consumption before its save. |
| SavingThrowRoll | `0x1403ec600..0x1403ed7d8` | Signed-byte base, contextual/spell/feat/trap/Spellcraft bonuses, upper cap, d20 before immunity, table/legacy immunity, feedback ownership, natural-one setting and one Slippery Mind recomputation. |
| Save base / optional table | `0x1404024c0`; loader `0x1402b59bb..0x1402b5ab8`; reader `0x1401a7010..0x1401a7117` | GetFortSavingThrow(1) excludes effect queries but retains other bonuses. Failed savingthrowtypes load frees the table and selects legacy immunity. Integer reader uses table defaults on missing rows/columns. |
| Save feedback | `0x1403ed64f..0x1403ed70a` | Broadcast to owner-client/distinct caster, or append to caster current record +e0; cleanup returns to result resolution. |
| Save script wrapper | `0x14053d2b0` | Commands 108/109/110 select Fort/Reflex/Will; narrow DC/category, feedback=1, feat=0, attack-feedback=0. Wrapper wiring remains pending its live ownership/settings providers. |
| GetSkillRank / LoadSkillInfo | `0x140406a40..0x140408058`; `0x1402ac6f0..0x1402ad108` | Active skills Untrained/KeyAbility/ArmorCheckPenalty fields, signed ranks/abilities, physical blindness penalty, signed-byte armor sum, native feat/ruleset/area/class bonuses, per-class +25e penalty bytes and saturation. Effective world/effect/armor/class-penalty providers remain explicit. |
| GetCanUseSkill | `0x1403fa1d0` | Trained skills require positive base rank; untrained skills query native class usability; IDs 100..102 validate against skill 2 but retain original ID for class query. |
| Skill effect query | GetTotalEffectBonus category 5 `0x140395d23..0x140396237` | Types 55/56 use skill/amount/race/law/good at integers 0..4; ID 255 applies to all skills, ID 0 remains a specific skill. Independent fifty-slot spell/item source lists and positive/negative caps. |
| Skill effect constructors/handlers | `0x14051b7f0`, `0x14051b6a0`; `0x1404332d0`, `0x140433190` | Active skill-count validation, all-skills ID, creator/subtype, zero magnitude admitted on apply, negative magnitude rejected, creature/dead gates, decrease plot/immunity 27. Linked type-67 icon effects 43/44 are diagnosed rather than silently implemented. |
| Skill effect enumeration/removal | script type map `0x1404242ef..0x140424313`; removal leaves `0x140438830..0x140438836`, `0x140438840..0x140438846` | Script-visible types 54/55; removal handlers return 1 with no cache mutation. Existing enumeration/deferred deletion/expiry semantics retain canonical IDs. |
| Skill limit / blindness | default write `0x14055c66a`, getter `0x14055b990..0x14055b9a6`; GetBlind `0x140390210..0x14039022e` | Default skill cap 50; native nonnegative module override precedes server cap. Cached blindness tests mask 0x24 overrides, then 0x10 or (flags & 0x0a)==8; not a single-bit boolean. Limit engine calls remain unconnected. |

Native eligibility's final sneak feat ladder is **834..843**, while the
existing native damage-dice ladder is **842..851**. Preserve this build's
discrepancy rather than substituting names or a rules-manual interpretation.
The fear-save Resist Nature's Lure fallback is two; ruleset overrides still win.
`SNAKE_BLOOOD_POISON_BONUS` and `STILL_MIND_COMPETANCE_BONUS` preserve native
label spelling. Active module/HAK/base 2DAs remain the data source; no campaign
or actor-specific behavior was added to the runtime.

DamageRuntime now reads serialized **IsImmortal**, not Immortal. Its new async
roll adapter uses live mitigation/removal budgets without committing HP/base
attack damage. GetWeaponPower reads the **attack** bonus limit (native
`0x140396770`), not the damage limit. The synchronous and asynchronous damage
drivers share one generator to retain draw/query order.

## Independent native observations

`scripts/build-combat-oracle.mjs` writes wholly authored GFF/MOD/NCS resources.
It references installed ttr01 tile 109 after selecting flat grass metadata;
it copies no installed assets/scripts. The limited NCS emitter reads command
ordinals from active nwscript metadata and implements only its authored AST.
It is not a general compiler. The malformed first attempt used an incorrect
GIT creature-list field, was diagnosed by invalid native tag lookups, and was
corrected. Native GIT uses `Creature List`.

`scripts/native-combat-oracle.ps1` launches the hash-checked unmodified server
hidden with a workspace user directory, unique port 5131, random credentials,
unlisted settings, disabled DM/admin access and NAT punching disabled in the
child environment. Native still contacts its master server and reports the
server hidden. Native also reports autosave enabled despite the CLI interval;
there were no joined clients. Native logs contain two empty-label IFO reads
that remain recorded in the engine log; the fixture nevertheless loads and
executes all probes. Do not claim a warning-free native fixture.

The final stopped-server capture is
`backups/native-combat-oracle/native-combat-log.txt`, with exact module/log/server
hash metadata in `.capture.json`. The generated MOD's SHA256 is
`d8297fe97f93dedc7d4a688e24c81ae65cf6300a1d62f6396172da17a4a4c381`.
`scripts/verify-combat-oracle.mjs` verifies those bindings before comparison.
The earlier baseline log is retained separately.

The latest capture has 34 authored observations, 10 attack notifications and
3 damaging strikes. Three actor BAB/AC/HP baselines match replacement providers.
Native and replacement both apply damage 50 to an IsImmortal=1 actor as HP=1,
retaining damage history 50 and canonical self-damager attribution. Each native
fighter completes rounds 1,2,3 then ClearAllActions stops it. Attack notification
precedes native damage and also occurs on misses. Naked native strike damage
and replacement bare damage rolls remain within the verified unarmed/critical
ranges; replacement roll queries do not commit HP or attack base damage.

After applying poison immunity, native and replacement **FortitudeSave,
ReflexSave and WillSave return 2 at DC 65535/category 2**. The replacement check
uses fixture-specific capability providers for this never-casting creature;
unvisited systems throw. These are explicit test inputs, not live no-op handlers.

The bare level-11/Dex-14 probe also agrees on Parry (base 0, effective 2) and
Spellcraft (base 0, effective 0). These check the native ability and trained-skill
gates with fixture-supplied absence of skill effects, blindness, armor and class
penalties. They do not validate the entire live skill subsystem. The first
comparison incorrectly asserted a present effects array; the runtime legitimately
leaves it absent when empty. That test assumption was corrected and comparison
rerun successfully.

Native and replacement also agree on Parry after live unsourced skill effects:
**2 → 7 (+5) → 10 (+3) → 8 (−2)**, with base rank remaining zero. The default
mapped effect and blindness providers are used in this latest comparison;
the unarmored/no-class-penalty fixture still supplies those two cache inputs.
The source query now resolves any live canonical item, including unequipped
items; deleting that item changes subsequent source classification as native
GetItemByGameObjectID does. Conditional save/skill subjects are creatures or an
AoE creator; ordinary doors/placeables do not acquire neutral creature alignment.
Missing-subject race/law/good sentinels are -1, as the native query writes.

This is a narrow independent oracle. Native seed was uncontrolled: it does
**not** compare exact attack/damage random draws, replacement encounter timing,
full defenses, spellcasting, gameplay animation or networking. Native fighter
activity is not evidence that the replacement live attack loop works.

## Validation and remaining work

All **459 tests** and production build pass (`feat-uses-all-tests.txt`,
`feat-uses-build.txt`). The only build warning is the existing large-chunk warning.
The hash-bound installed native oracle comparison passes
(`native-oracle-check.txt`). Installed Prelude/Witch's broad creature/BIC/UI
checks were run at the prior 358 checkpoint; they were not rerun here.

Default saving-throw adapters supply mapped stats, effects, IDs, rules and RNG;
spell/caster metadata, armor/class-penalty caches and class skill usability, trap-query casts, auto-fail server
settings and client/broadcast ownership still require verified providers.
Likewise roll/defense/damage stages are not yet the default full attack backend.
Finish action/approach/perception/LOS and attack preparation; live modifier/AC,
parry/effective skill, feat-use and on-hit/status/death providers; combat AI
15/19/20/22 delivery; ranged ammunition/projectiles; round activity cleanup and
gameplay presentation. Then compare complete replacement/native encounters
before claiming combat ready. Casting follows through the same canonical state.

Backups: `combat-save-oracle-checkpoint-20261012.zip` preserves the earlier
421-test/save-only fixture. `combat-skill-oracle-checkpoint-20261012.zip`
preserves the 433-test/skill fixture. `combat-skill-effects-checkpoint-20261012.zip`
preserves the current 443-test/skill-effect fixture. Archives include only authored module data,
manifests and research logs from the oracle, not its entire user home or secrets.

## Feat-use checkpoint

`feat_uses.js` owns a canonical mutable pool of four-byte records: ushort feat
at +0 and byte **spent** uses at +2. Stats owns the pointer list at +10, count
at +18 and capacity at +1c. AddFeat `0x1403ef170` allocates 16 entries then
doubles; duplicate grants retain the existing record. Decrement
`0x1403f2750..1403f2782` increments every matching spent byte, including wrap;
increment `0x14040b9d0..14040ba0d` decreases nonzero spent bytes. Reset
`0x140412b10..140412b43` skips null records. RemoveFeat `0x140412720` removes
the last matching pool record using a signed-short tail index. Oversize pools,
invalid live records and successor cycles are diagnosed rather than reproducing
native faults or infinite loops.

LoadFeatInfo `0x1402a8800` uses physical table rows. A found `Feat` integer marks
the row valid; the cell and row label do not remap the ID. CNWFeat constructor
`0x1402a1180..1402a11f0` initializes UsesPerDay +64 to zero and SUCCESSOR +54
to -1. Found table cells replace them, narrowing to byte/ushort for these
queries. GetFeat `0x1402a3bd0..1402a3bf3` checks count ushort +100 and valid
flag +68. Table reload creates a new rules cache; no campaign-specific data.

Remaining `0x1404012f0` and Total `0x140401c70` retain native music, stunning,
turning, smite, unlimited, rage and prestige-class branches and ruleset constants.
Arithmetic wraps to byte before spending/capping at 100. Invalid feat precedes
the remaining-query DM shortcut; total has no DM shortcut. Missing pool records
return 100. Feat 871 follows the highest owned song successor; even **Total**
calls **Remaining** for that successor. HasFeat `0x14040b900` checks owned and
pending lists, plus Ranger class 7 grants of feats 1/41 while chest AC <4.
Highest `0x1404029b0` traverses unowned intermediate successors and preserves
native aliases 65000/65001 to lookup feat 5.

ReadStatsFromGff `0x1404117ae..140411906` adds each feat before restoring
optional BYTE `Uses` as remaining charges. Runtime imports preserve that value
in the separate pool; absence starts fresh. XP feat removal/regrant updates pool
ownership without resetting retained charges. `GetHasFeat` wrapper
`0x140525410` follows successors and, unless ignoreUses !=0, tests remaining
charges. `GetFeatRemainingUses` wrapper `0x140524a10` maps native 100 to INT_MAX.
Decrement wrapper `0x1405154f0` gates exhaustion; increment wrapper
`0x1405331e0` tests ownership of the original ID before following successors.
Defensive Roll/maximum-damage adapters now use this pool; their full encounter
side effects are still pending.

Controlling exports: `live-feat-uses-asm.txt`, `live-feat-uses-full-asm.txt`,
`live-feat-pool-leaves-asm.txt`, `live-feat-query-removal-asm.txt`,
`live-feat-script-mutation-asm.txt`, `live-has-feat-asm.txt` and
`combat-loaders-asm.txt`. Ghidra is read-only. The inspector now flags unmapped
RIP operands from embedded tables and continues exporting later functions;
linear table decoding is not evidence of an executed path.

The native fixture now independently agrees on feat 223 saved exhausted
(has=0, owned=1, uses=0), feat 39 saved uses 2 ->1 ->0 ->0 ->1 after two
decrements, an exhausted decrement and an increment, and unlimited feat 5
(INT_MAX). Latest authored module SHA256:
`89096371af1b4955ddd00376e316e30d006f96dabc77f655338e59d559383a00`.
Captured native log has 45 observations, 10 attack notifications and 7 damaging
strikes; RNG seed remains uncontrolled. This still does not prove a replacement
live encounter or full combat parity. Backup: `combat-feat-uses-checkpoint-20261012.zip`.
