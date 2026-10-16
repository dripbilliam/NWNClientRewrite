# Conditional spell effects and stat-effect lifecycle

Target: NWN:EE89.8193.37-17 x64, original executable SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
The installation and Ghidra database were not modified.

## Observed original owners

`ExecuteCommandVersusEffect14054ac30..54ae96` serves ordinals355/356,
VersusAlignmentEffect/VersusRacialTypeEffect. It pops an owned effect, followed by
the supplied integer arguments, and pushes the resulting value before destroying
the temporary. Stack pop/push failures return-638 immediately, without the normal
destruction path. Production uses the existing typed VM argument/return boundary;
it does not expose native allocator ownership to JavaScript.

Alignment selector1 is tested as unsigned against5. Selector2 is not validated.
Race is signed-nonnegative and **inclusive** of rules+106, a BYTE narrowed from the
active RacialTypes physical row count. The complete LoadRaceInfo1402aa460..2ac055
capture verifies this field's origin; Ghidra truncates at the earlier free(NULL).
No playable-race switch or built-in race list is used.

The effect WORD type determines its race/law/good integer positions:

| Types | Race | Law/chaos | Good/evil |
|---|---:|---:|---:|
| 10,11,13,14,48,49,55,56 | 2 | 3 | 4 |
| 22,47,63,76 | 1 | 2 | 3 |
| 26,27 | 3 | 4 | 5 |

Other types pass through unchanged, including linked containers. The wrapper
does not traverse linked children. Value copies preserve the original input,
uint64 effect ID, creator, spell attribution, flags and unrelated payload.

Full stat-effect owner pairs are now used before retention:

| Effect | Apply increase/decrease | Remove increase/decrease |
|---|---|---|
| Attack10/11 | 140427920 /1404277d0 | 140435f90 /140435f50 |
| Saving throw26/27 | 1404314a0 /140431360 | 140438290 /140438250 |
| Armor class48/49 | 140426ad0 /140426860 | 140435ad0 /1404358c0 |

All require AsCreature. Dead rejection applies during loading only, with native
duration3/4 exceptions; ordinary applications do not gain an extra dead check.
Positive magnitudes are required. Decreases retain their original immunity and
plot gates, including the different ordering for attack versus AC/save.

The owners create type67 children with icons29/30,35/36,39/40 or save-specific
103/102/104. The entire original copy constructor140423570..423768 executes in
the final oracle. It preserves identity/context/timing/immunity override but
clears payload, type, tag and links, even with icon flag1. The new stat adapter
uses `copyConstruct`, not full payload assignment. Child icon retention and
group removal reuse the separately mapped shared effect-icon/removal owners.

Generic AC applications mutate signed BYTE caches only for race28, no alignment
filter, and damage4103. Dodge sums; other categories compare the raw INT with
the current signed BYTE. Existing positive category cache emits feedback189–192
before comparison, including a weaker replacement.

Removal scans before erase, excludes the same pointer, and starts at the shared
first48/49 WORD index. UpdateEffectPtrs1403a7780's complete verified leaf CFG
confirms that shared index, including the native early stop when the leading
effect has the other sign. AC-decrease removal omits the parent's damage test
and candidates' alignment tests; AC-increase removal includes them. These
differences are preserved rather than normalized into one maximum calculation.

## Validation and limitations

`inspect-native-versus-effect.py` records11,090 original command executions,
including all effect type dispatch, alignment/race boundaries, null arguments,
and stack-failure cleanup evidence. Its first attempt shadowed the fixture's
effect pointer with a Boolean loop variable; the corrected v2 output is final.

`inspect-native-stat-effects.py` records5,858 original application/removal
executions, including the real sorted-index updater and complete copy
constructor. Final output is v4. Earlier fixture failures (stack clear extending
past mapped memory, absent application-manager pointer) and the v3 captured-copy
boundary are retained. The final constructor execution supersedes the v3
assumption that its integer payload was copied.

Lower creature/dead/immunity, icon application, feedback, heap and string/vector
initialization are captured boundaries. Native allocation failure and full
RecomputeCombatInformation are not claimed. Production refreshes the existing
local stat projection after retention/erasure. Native HUD buff-art presentation
and GUI/network synchronization remain separate gates.

Installed Prelude probe v3 runs unmodified Protection from Evil/Good and
Holy/Unholy Aura impact scripts with canonical spell context. All16 wrapper
calls succeed; the conditional saves are2/2/4/4 against the selected alignment
and zero against its opposite. Linked armor/save effects retain the correct
filters. Startup/general AI/entry are isolated in this probe; warnings and load
failures remain in the report. This is impact/consumer evidence, not high-level
eligibility or whole-campaign completion.

Full regression:1,649 tests pass (`stat-versus-full-tests-v3.txt`), build passes
(`stat-versus-build-v2.txt`, existing chunk-size warning). Three older direct API
tests now await effect application and assert real icon lifecycle instead of
expecting the former presentation warning. Auditv36 has86 unbound spell API names
and22 missing impact NCS resources. A presence audit does not establish runtime
branch coverage. The full spell/combat/campaign goal remains active.

Rendered `--versus` v3 passes with the installed cleric and an owned in-memory
BIC selecting two legal preparations of active Master321. The real self wheel,
class/level and Protection from Alignment submenu select children138/139;
automatic self targeting, conjure1/castup, authored impact, conditional effects,
native icon pools and two consumed parent slots are asserted. Browser errors0,
new errors0; the known missing plc_w02 PWK is separately retained. The final
PNG was inspected: the scene is dark and partly occluded, so it is not evidence
of complete lighting/camera parity or native HUD buff art.

Initial v1/v2 fixtures correctly rejected child variants as direct class-level
preparations (level255); switching the preset did not resolve the mistaken
fixture assumption. The final fixture resolves the active Master and uses the
original submenu. Failure screenshots/logs are retained, with no gameplay
exceptions added. Installed probe v3 and UI v3 are terminal.
