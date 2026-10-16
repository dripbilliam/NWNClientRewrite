# Form equipment, defenses and HP ownership

Target NWN:EE89.8193.37-17 x64, unchanged installed nwmain.exe SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original install and Ghidra project remain unchanged. All fixtures contain
derived observations; game assets are read from the existing installation.

The shared item-property dispatch now implements vision, immunities, bonus
feats, spell immunities/resistance, damage percentages, attack bonuses, saving
throws and turning resistance needed by installed form templates. Active
tables provide values; there are no per-form spell outcome switches.
`inspect-native-form-immunities.py` and `inspect-native-form-save-attack.py`
compare1,970 and4,268 cases against original instructions with captured lower
resource/creator/application providers. Base/copy/assignment effect construction
and integer writes execute in the native fixtures. Detailed owner addresses and
call order are retained in their reports and the materializer source comments.
These bounded comparisons do not establish complete item lifecycle parity.

Turning resistance uses native types77 and88. Shared apply140434b20 checks
loading/dead duration gates and TURN_RESISTANCE_AFFECTS_PCS; query140396290 sums
raw signed increase/decrease amounts with32-bit wrapping. Constructor14051c650
binds NWScript552/553.499 cases cover constructors, apply/remove and query.
Installed PC/NPC checks preserve the active rule gate and remove both effects.

The score provider previously refreshed all cached modifiers while a native
single-ability setter was still measuring its old state. It now calculates the
score without rewriting unrelated caches. Ordinary UpdateCombatInformation
continues to refresh all six, matching1404171e0. The128-case HP pipeline runs
original STR/CON/DEX setters, full GetMaxHitPoints140391850 and the six original
cache writes. Lower score/feat/level/rule providers are captured. Coordinator
stages come from the separately compared form lifecycle; this is not another
full native form execution. Missing CON overrides can change the cached CON
through racial/equipment refresh and lose HP on restoration in the original
sequence. Installed form26/40 profiles, with full and injured HP, match that
sequence; forcing all forms to restore identical HP would conceal it.

The installed --observe-hp sweep completes all102 physical rows with valid
AppearanceType, preserving canonical roots, stats, equipment, item identities
and non-HP restoration assertions. HP changes are recorded rather than waived
as parity acceptance. Two authored template lookups still fail visibly:
`x1_it_frostghide` and `x2_mech_hide`. The original coordinator continues after
template load failure; no fabricated aliases or game data edits were added.
Saved/GFF loading flags, complete native combat-information copying and broader
effect ownership remain open.

Live model replacement now preserves the actor wrapper and reattaches existing
visual instances to the new body. Phase, animator time, lifetime and effect IDs
survive. This is a tested local presentation bridge; native handle invalidation
and model-event lifecycle are not claimed reconstructed.

Validation:1,572 tests pass (`form-defenses-full-tests-v1.txt`); production build
passes (`form-defenses-build-v1.txt`). Hidden Electron polymorph UI exits0 and
passes real prepared parent130 consumption through radial child387, canonical
player565, model/animation replacement and cancellation/restoration. Startup is
disabled in this fixture; baseline import diagnostics and camera occlusion
remain, so it is not campaign acceptance. Active spell auditv28 still records95
unbound names and22 missing NCS. Spellcasting, combat and campaign goal is active.
