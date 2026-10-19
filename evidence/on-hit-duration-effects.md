# Common duration on-hit effects and skill modifier icons

This continues the active single-player spell/combat goal. The preceding
[on-hit/status increment](on-hit-status-delivery.md) was concrete progress and
provided a verified1968-test backup. This increment closes ten more timed
on-hit payload builders and replaces the skill-buff presentation placeholder.
Full spells, combat and campaign acceptance are still open. No user pause was
requested; the goal remains ACTIVE.

Read-only target: NWN:EE89.8193.37-17 x64,
`../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
No original installation or Ghidra project changes. REA dossiers
`rea-onhit-*-owner.json`, native original-instruction captures and verifier
logs remain under `backups/animations/`.

## Native duration owners

| Original engine helper | Address range | Mechanical and visual construction |
| --- | --- | --- |
| ApplyOnHitSleep | `1403e18d0..1403e1c38` | Instant94, type8/kind9 with integer1=1, then linked visuals7 and207. |
| ApplyOnHitStun | `1403e1eb0..1403e2180` | Type8/kind6, linked208 and207. |
| ApplyOnHitHold | `1403e0650..1403e09fc` | Type8/kind8, linked232,82,207. |
| ApplyOnHitConfusion | `1403deaf0..1403dedc0` | Type8/kind2, linked208 and207. |
| ApplyOnHitDaze | `1403dedd0..1403df0a0` | Type8/kind5, linked209 and207. |
| ApplyOnHitDoom | `1403dfcb0..1403e0230` | Instant57, attack decrease11[2,0,28], damage decrease14[2,0,28], skill decrease56[255,2,28], save decrease27[0,2,28], then207. |
| ApplyOnHitFear | `1403e0240..1403e04f9` | Type8/kind3, linked218 and207. This owner omits UpdateLinked calls during construction; delivery performs that update later. |
| ApplyOnHitSlow | `1403e1c40..1403e1ea5` | Previously verified instant95, Slow3 and linked207, now using the shared builder. |
| ApplyOnHitSilence | `1403e11b0..1403e1415` | Instant93, Silence46 and linked207. |
| ApplyOnHitDeafness | `1403df0b0..1403df315` | Instant46, Deafness21 and linked207. |
| ApplyOnHitBlindness | `1403de620..1403de893` | Instant46, Vision73[16] and linked207. |

The descriptors in `src/on_hit_duration.js` reproduce these engine methods;
they are not individual authored spell implementations or campaign overrides.
Property admission, real saves and chance/DC/duration still use the existing
native dispatcher and active IPRP tables. The tree builder preserves allocation
and append order, copy-source selection, exposed/icon flags, shared uint64 IDs,
native creator context, intermediate linked metadata updates, final float32
rounds*6 duration and packed flags9. Original Slow remains a compatibility entry
that delegates to the same builder.

`inspect-native-onhit-duration.py` executes all eleven COMPLETE original owners,
the original clearing copy constructor, SetInteger, SetLinked and UpdateLinked.
675 cases cover negative/zero/large rounds, canonical creator IDs including bit31,
attack-index narrowing, metadata, every partial allocation failure position and
ordered cleanup. Base allocation/constructor/creator, attack lookup, append and
destructor are captured lower boundaries. This proves their caller contracts and
payloads, not native allocator/destructor internals or the entire attack round.
The shared builder matches all675 cases on its first comparison, and the previous
independent60-case Slow comparison still passes after factoring.

## Skill modifiers

Actual Doom delivery reached a skill-decrease placeholder. Original owners
OnApplySkillDecrease `140433190..1404332cb` and OnApplySkillIncrease
`1404332d0..1404333b7` admit zero magnitude, reject negatives and require a
creature. The death check applies ONLY during loading, with equipped3/innate4
exceptions. Decrease additionally checks plot, resolves the creator even when
bypassing immunity, then checks native immunity27 when bypass=0.

Both use the clearing copy constructor with icon flag1, set child type67 and
integer0 to43/44, apply that child before retaining the parent, and preserve its
shared ID/duration/context. `src/skill_buff_effect.js` supplies these owners;
EffectRuntime now uses them and the existing native icon pool instead of emitting
the placeholder warning. It also replaces the old unconditional dead gate and
approximate immunity call with the verified native provider path.

`inspect-native-skill-buff.py` executes both COMPLETE owners and the original copy
constructor in552 cases. Loading/dead/duration/amount/plot/bypass/source/immunity,
skill selectors, exposed/icon flags, subtype metadata and exact provider order
match. As with the original code, this oracle assumes successful icon allocation:
the native owner otherwise writes a null pointer. The client reports an unavailable
copy rather than claiming undefined-memory parity. Additional real-runtime tests
cover overlapping icon grants, final shared-ID cleanup, zero magnitude on a dead
creature outside loading and hidden equipped icons.

## Installed validation

`installed-onhit-duration-v5.json` passes THIRTEEN checks:

- Eleven temporary property variants are selected from the independent original
  dispatcher observations, rather than a second handwritten expected mapping.
  Only owned temporary property records change; the installed cleric's item and
  all original files stay unchanged. Actual on-hit tables, chance, saves, payload
  construction, combat event5 and effect/control/stat/vision delivery run. Each
  shared effect ID expires naturally and restores control/slow state.
- Two real native creature frames follow each application in `--control-frames`
  mode, retaining heartbeat/perception/script execution. Sleep runs NW_G0_sleep;
  Stun/Hold run x2_sig_state; Confusion runs NW_G0_confuse; Fear runs NW_G0_fear,
  all selected by active StateScripts. Daze state5 deliberately does not dispatch
  a control script, matching the original heartbeat. v2's incorrect test
  expectation for Daze was corrected; production dispatch was unchanged.
- NCS skill constructor/application/query wrappers on the PC verify an active
  untrained skill selected from the rules: rank20->23 with increase3, and
  rank20->18 with decrease2. Native icons43/44 appear, expire and disappear; rank
  returns20 after each expiry.

The fixture isolates startup/general scheduling and consecutive effect phases
with explicit frame-stamp/spawn/position/action resets. The two-frame check is
not continuous combat or full AI acceptance. Authored callbacks create32 canonical
creatures/items (cursor575->607); the report records them and verifies all existing
object references remain identical. Default isolated v1 passes all eleven original
delivery checks with a stable cursor; v3/v4 also pass their then-current control
checks. The final v5 adds skill totals/icons. No renderer sampling of every newly
produced visual is claimed.

Separate regressions `installed-fear-cast-v6.json` (six checks) and
`installed-onhit-slow-v2.json` (two checks, including immunity-linked visual cleanup)
pass. This retains broader actual Fear casting/combat evidence alongside the
isolated factory/control checks. Startup/character acquisition fixtures and other
limits in those reports still apply.

## Regression status and remaining scope

Full suite v2: **1972/1972 pass**. The first full run exposed two older tests that
neither awaited the new native child application nor distinguished mechanical
records from their new linked icon records. They now await application and verify
mechanical stacking, deferred removal, immunity and actual icon-pool behavior.
No production behavior was weakened to satisfy their old record counts.

Build v1 passes with the existing bundle-size warning. Electron v1 passes live
spellbook selection, right-click self casting, slot consumption, F2 targeting and
cancellation, cast animation and counterspell mode22. The shutdown GPU message is
retained. Native icon pool behavior is proven; full HUD buff-art rendering is not.

The accepted control probe retains trap and speech overhead/sound warnings; the
skill placeholder warning is gone because its original work is now implemented.
Baseline missing PWK/load diagnostics remain. All failures and runtime omissions
are retained; no diagnostic filtering turns a failed check into a pass.

Remaining non-duration on-hit owners include poison/disease, ability/level drain,
slaying/vorpal/wounding, vampiric regeneration, dispel/knock and their applicable
gates. Death/corpse scheduling, full generic ApplyEffect admission/persistence,
trap and effect presentation, the remaining spell engine dependencies and full
single-player campaign acceptance remain open. Audit v53's54 unbound commands/
22 missing impact scripts are historical dependency evidence, not a completion
claim. Multiplayer work remains deferred and the full goal stays ACTIVE.

Verified checkpoint `backups/on-hit-duration-1972-20261017-v1.zip` contains
10702 files /147958611 bytes, with every archived length and SHA256 verified.
`on-hit-duration-checkpoint-v1.txt`, session63271 terminal0 consumed. This
verification note was added after sealing. No validation or backup job remains.
