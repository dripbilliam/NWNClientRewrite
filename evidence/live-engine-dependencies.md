# Live combat engine dependencies

Target: NWN:EE89.8193.37-17, original nwmain SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original binaries, campaign and Ghidra database remain unedited. Findings below
come from bounded read-only disassembly; pseudocode alone is insufficient.

## Original campaign startup checkpoint, 2026-10-14

The startup audit now covers all seven original modules and321 areas, with all
occurrences retained in per-module JSONL journals. A replacement-only256-event
cutoff incorrectly aborted five modules; the native due-event loop now drains
the actual finite batches in order. GetStringLeft, StringToInt, GetAssociateType,
GetSittingCreature and GetFacing are connected to bounded native owners, together
with authored orientation loading (2628 original comparisons).1177 tests/build
and the installed complete encounter integration pass. Strict startup readiness
still fails on recorded gameplay/persistence omissions. See
[Base campaign startup](base-campaign-startup.md) for contracts, boundaries,
failures and reports. Corpse lifecycle/loot copying remains unbound.

## Corpse metadata, lifecycle and collection cores (1167 tests)

GetBodyBagAppearance140390230/1404b3b80 matches144 full native selectors;
script GetBodyBag14051fa50/SetBodyBag14053e2f0 matches16/48 cases. Active
physical table queries preserve exact-one Lootable157 shortcut, BYTE stored
row, raw INT setter validation before lookup, WORD appearances and13 fallback.
Both getters use Appearance.2da, with different Body_Bag/BodyBag columns.
This unexpected shared table is verified by Load2DArrays1402b3b5a..3be4
(table+100); bodybag is table+3f8 at1402b9915..99ae. Do not substitute the
placeables table or unify those column names. Placeable ctor1404afd3b and
bounded GFF import1404b527a..52a2 establish its BYTE default/existing fallback.
Live queries/import and Get/SetBodyBag are connected. Installed actor565 and
placeable385 select active row1/appearance194 with no new errors; invalid−1
does not alter the previous selection (`live-native-corpse-bag-installed-queries.txt`).

Bounded death flag14042acf8..ad1c matches108 original cases; scheduling
14042b2dc..b513 matches432, preserving original effect creator attribution,
UINT decay, Lootable/spectacular paths, PC event and encounter order. Event11
14038f07a..f220 matches3456, including ignored/repeated possession queries,
exact-one destroyable, associate7/8 exclusions, retained area observer cleanup,
encounter accounting and destructor order. Bag/effect/event/area/destructor
helpers are captured. These source coordinators are intentionally not attached
to partial live destruction. Callers must supply actual death-effect integer0
and capture the flag before OnDeath; passing damage integer0 would be wrong.

AcquireItem1404b11d0 matches360 complete native owner cases: matching direct
source, creature/placeable/container/world removal before destination check,
mutable ref handling, ignored AddItem result and possession flags. Complete
AcquireItemsFromObject1404b1350 matches1296 cases with captured copy/array/
acquisition helpers. First14 equipment slots are inspected; head/chest/right/
left create distinct copies. Collection precedes acquisition in five size
buckets and preserves physical order. Gold is tested as unsigned nonzero,
loads the native gold template, clears source gold before acquisition and
increments the result only for nonzero acquisition. Bucket sizes above255
would wrap the original BYTE traversal indefinitely; the source diagnoses that
fault domain before transfer rather than freezing. It is not a native recovery
claim. Oracle failures from an initial helper-address/return-register mistake
are retained; the corrected harness executes the original acquisition body and
preserves RAX across the security-cookie boundary.

Lifecycle and collection remain unbound until CopyItem140466910, complete
body-bag constructor/LoadBodyBag/SpawnBodyBag, area removal/destructor and
death-effect bridge are connected. New read-only complete loader/constructor
and collection listings are retained. Current live combat still records corpse
cleanup as omitted; six prior encounter omissions and equipment/casting/native
full-fight/network gates remain.1167 tests/build pass. Checkpoint
`backups/live-native-corpse-transfer-1167-20261014.zip`.

## Pending equipment and unequip (1159 tests)

RunUnequip14039fff0..1403a059f matches1008 original executions, retaining
direct possession/equipment eligibility, repository selection, mutable item
replacement, fitting flag order, transfer/drop branches, offhand promotion,
page selection and native client-dependent returns. CanUnEquipWeapon1403d22b0
matches378 cases; weapon promotion precedes exact-one natural weapon locks.
ProcessPendingCombatActions14039be00 matches32 cases: due head gates traversal,
tail conversion precedes each removal/disposal and rejected requests still
remove their round record. Original pseudocode's disposal early return is
incorrect; the complete assembly loops.

AddUnequipActions140380bd0 matches1296 requests; AddUnequipAction140374f80
matches180 insertion/rescale cases with original DecrementRoundLength running.
Native duplicate handling writes the tail record's target when a match appeared
earlier; that observed behavior is retained. AIActionUnequipItem1403cef60
matches576 gates/calls, ClearAction11 matches48, CalculatePage1404656a0
matches400. Script wrappers14051ca60/14054a590 match188 cases (VM/lookups/request
helpers captured, exact integral powers of2 captured). The optional equip
object is consumed but unused in this build. All query inputs use canonical IDs
and active base-item data. These comparisons do not prove the captured helpers.

The runtime connects ordinary/timed unequip, cancellation, round-end conversion,
script equipment commands and equipped item-removal delegation. The installed
`live-native-unequip-cycle-integration.txt` passes a plain-dagger NPC fixture,
including cancellation with pending equip/unequip, preserved identity/direct
ownership and empty final queues. Its round clocks are explicit test inputs.
An initial PC fixture exposed the existing missing itemLevelRestrictions owner;
the loaded fighter also has passive properties requiring the unresolved effect
owner. No PC flags or rules were overridden to bypass these gates. Alternate
inventory GUI, SelectPanel/SetPanel, failed-fit AddToArea drops, passive properties
and broader acquisition/merge lifecycle remain explicit missing providers.

`live-native-unequip-complete-encounter.txt` passes authored retaliation,
approach/kill and all four encounter goblin deaths, with only the installed
missing plc_w02 PWK/script1 NCS resources. Readiness still finds six omitted
owners: traps, dirty stats, corpse/body bags, automap, achievement presentation
and voice playback. Special/on-hit, equipment transitive paths, casting and
original full-fight/network comparisons remain separate unproven gates.
1159 tests/build pass. Checkpoint `backups/live-native-unequip-1159-20261014.zip`.

## Queue display and cancellation (1150 tests)

UpdateActionQueueDisplay1403a6270..1403a698c matches227 original executions
with group, special attack and item-property helper boundaries captured.
All ten28-byte records match, including untouched padding, raw coordinate
bits, physical special-list packing and canonical target IDs. Forward AQ
maps1404ab820 match every ushort in both modes (131072 inputs); reverse
map1404abb10 independently matches65536 inputs. It is not the inverse of
the display map. CancelAction140386700..1403868ad matches240 original
traversals with captured list/ClearAction/disposal helpers. Group traversal
includes separated groups, honors exact1 ClearAction acceptance, and uses
native special sequence IDs. Live cancellation retains protected actions
and does not add a commandability gate.

The HUD uses active physical actions.2da labels/icons and spells.2da spell
icons, resolved native TGA canvases and ctl_actionqueue local hook geometry.
The screen anchor is a replacement HUD adaptation. Missing tables/resources
retain diagnostics. Cancellation joins the identity-guarded local input FIFO;
native cancellation packets and network authority are unverified.

`combat-native-queue-cancel-spawned-cycle-ui.txt` verifies rendered Attack
group0/target572, a real queue icon click, disappearance of that group, fresh
canonical radial Attack, approach, swings and fall→held-dead atHP−22.
All26 actors have zero presentation failures. Authored AI/stats remain live;
camera/lighting are test controls. Attack/fall screenshots were inspected.
The original queue/cancellation observations and rendered captures are retained.
1150 tests and the production build pass; full combat/casting/parity remains
unfinished. Checkpoint: `backups/live-native-queue-cancel-1150-20261014.zip`.

## Rendered encounter, corpse fields and IEEE LOS (1144 tests)

`combat-area-path-near-encounter-cycle-ui.txt` verifies a living spawned
target573 atHP1, canonical ray/radial selection, actual player approach and
swings203, target fall219/220→held dead8 atHP−14, and zero presentation
failures across26 actors. Inspection uses camera/lighting controls only;
authored stats, AI and gameplay queues remain active. Earlier attempts are
retained: ray picking initially raced moving actors, a later target was dead
before its requested swing, and a distant different encounter did not complete
the requested attack. Acceptance chooses a living target from the nearest
activated encounter, polls pointer state after a real renderer frame and
checks canonical IDs. No authored tag/area exception enters runtime code.

GetItemCount1403916b0 and Get/SetLootable14052b590/1405436e0 match184
original executions with captured inventory/repository/VM/life-state helpers.
Counting traverses only14 equipment slots, direct repository nodes, optional
droppable+448 and one additional count for any gold. SetLootable stores raw
INT only for living, non-dying NPCs without possession. Bounded stats-GFF
ranges14040ff47..1404100da and1404104d8..140410504 match30 cases:
BYTEasBOOL fields, unsigned DecayTime with5000ms floor, BYTE BodyBag and
lootable raising/selection overrides. Constructor defaults are independently
visible at14037b1e7/14037b226..23f. Import/query owners are connected;
corpse scheduling, body-bag transfer and destruction are still unimplemented.

The stricter rerun `live-native-combat-readiness-owner-audit.txt` reproduced
the intermittent rotated-height rejection. The native itself divides using
canonical deltas after selecting the axis using world deltas. With a quarter
turn this yields NaN/Infinity; rejecting those values was a replacement-only
boundary. `native-los-interpolation-observations.json` executes64 complete
tile clip/rotation chains1404fd620/1402bbf60 and144 original box/AABB/
polygon kernel cases14022b400/1402bb230/1402bac30/1402c41f0, including
NaN/Infinity heights. No finite height is substituted. XY and initial area
inputs retain their data validation; computed IEEE Z passes to the verified
LOS kernels and XY traversal. Profiling/loading are excluded; synthetic
loaded geometry and material mask are explicit. The subsequent error-only
encounter passes in `live-native-combat-readiness-los-owner-audit.txt`.

The new `--require-combat-ready` gate also checks observed unimplemented
owners at every severity. It correctly fails on trap detection/recipients,
player queue display, dirty spell/combat refresh, corpse/body bags, automap,
platform achievement presentation and voice playback. The old error-only
gate excludes information/warning omissions and permits the two documented
missing installed resources; it is an integration check, not combat readiness.
Neither this fixture nor the readiness gate proves unexercised special/on-hit,
equipment, ranged/casting branches or original/network encounter parity.

## Live area path continuation (1139 tests)

Surface PlotIntraTilePath1402c3830..1402c41e2 matches364 original
executions for physical base-face admission, seeded queries, timer truncation,
FLOAT limits, resume-cache transfer and waypoint append. Tile wrapper
1404fe1b0..1404fe591 matches577 for original local/world rotations,
restored goal/exit arrays, appended-only rotation and far-NPC optimisation.
GenerateBestIntraTileExit1402bd950..1402be7f5 matches1731 original cases
for corridor widths, five candidates, direction weights, collision query
order, height padding and expanding fallback. Area PlotPath14036fc70..
140370e58 matches165 for partial budgets, physical route shifts, failed
entry/exit exclusions, retries, smoothing selection and pending/success status.
Profiling is disabled in the area capture. Search/collision/reset helpers are
captured boundaries in these owner comparisons; they are independently
tested elsewhere. These captures are not full encounter parity.

The active module's native geometry and canonical registry now connect the
verified graph/triangle owners to area route commit and existing native
smoothing. No campaign/tag exception or approximate path is used. Original
LoadWalkMesh1402c1020 stores base triangle count*64 at+70; route capacity
uses that value rather than depth2 subdivision count. Surface diagnostic
scratch+178 is uninitialised by its constructor and never drives a search
decision: unknown contents stay unknown, while supplied finite diagnostic
values still match the DFS capture.

`live-native-area-plot-installed-geometry.txt` commits77.3,102.7→84,81
on installed Prelude geometry in three resumable passes with zero exclusions.
The strict `live-native-area-complete-encounter.txt` completes authored Attack,
retaliation, approach to spawned targets and encounter481 exhaustion
(four spawned enemies killed, active/spawn count0). Only actual absent
plc_w02 PWK and script1 NCS resources are reported; no engine dependency
failure at error severity is filtered out beyond the two documented resources.
Warning/information omissions remain recorded and are now checked by the
separate readiness gate above. This supersedes the earlier unavailable areaPlot
blocker for this run. Rendered spawned radial/animation validation remains
pending; other combat owners and full original/network acceptance remain open.

## Encounter combat and dynamic animation continuation (1109 tests)

Encounter constructor/GFF import, descending stable CR lists, fractional CR
points, activation bounds/compaction, player/associate tally and spawn pools
are connected through active tables and canonical IDs. Spawn list preparation
matches3024 original owners; activation/pool/tally matches995. Safe/nonvisible
placement and CountVisibleToPlayers match512 captures; full spawn delivery
matches240. Native CountVisible uses the area's ID for client lookup and
increments candidate Z for each nearby admitted actor. Spawn orientation is
the unchanged unit vector despite the temporary sin/cos calculation; neither
quirk is replaced with an inferred design. Geometry/math/allocation helpers
in these captures remain explicit boundaries, not transitive parity claims.

Spawned creatures use the existing object allocator, native equipment and
repository imports, authored scripts and shared AI levels. Failed empty
loads remove their AI ID with RemoveObject rather than SetAILevel(-1), which
the original rejects. Native removal matches100 observations, including
the last-match shortcut in lists longer than16. Random-walk command/action
matches24/194 captures, preserving direct node disposal, front retry/waits,
two CRT draws, path shortening and move flags. GetLocked matches30, and the
location area accessor5; missing resources still produce durable diagnostics.

RemoveFromActiveCreatureCount matches144 full native observations. Death
decrements count and active points, queues exhausted event21/AI10 before
disabling/resetting the encounter and samples world time only for Reset==1.
The caller marks creature94c only when its canonical encounter exists.
Corpse/body-bag scheduling, full destruction, encounter AI respawn/heartbeat
and saved activation ID remapping remain unfinished.

Renderer bindings now load bodies/parts/textures/supermodels for creatures
created after scene load, retaining canonical object identity and disposing
aborted loads. SetBaseAnimation's generic extra-transition selector matches
31684 native executions and looping category matches1712. Its captured
creature emote helper/empty queue/zero timer do not validate the separate
weapon hooks, blending, queue interruption or packet timing. The rendered
Prelude radial Attack test passed enemy swing, player strike, sampled fall
and held corpse with zero animation failures across26 bound creatures.
The sequential headless test kills an authored goblin and a newly spawned
enemy; surviving encounter AI exposes cos, GetFirstObjectInShape and
GetAssociate. These observations do not establish full combat, casting or
original-server coexistence. Source/evidence checkpoint:
`backups/live-encounter-combat-1109-20261013.zip`.

## Skill and inventory transfer continuation (1095 tests)

UseSkill1403aa390 request guards and its pickpocket case now feed action54.
Passive/default IDs, including Parry10, intentionally return1 without queuing
an action in the original switch; they are not missing action implementations.
896 full original UseSkill executions match synthetic request guards/defaults
and captured AddAction inputs. Other active skill cases remain explicit.
AIActionPickPocket1403c50c0 executes the detection stage, animation37/retry,
approach, skill broadcast, gold/item selection, acquired feedback, detected
inventory event27 and ruleset cooldown in native order.486 full original owner
executions match synthetic ranks/rolls/repositories and captured dependencies.
The native last-scanned-item identification quirk is preserved independently
of the chosen item. Plot144 and cursed450 are distinct; selection tests450.
Matrices include empty bags, not arbitrary populated bag/destructor lifetimes.

RemoveItem1403d7490 and RemoveItemFromRepository14039eac0 match768 original
executions, including failed-removal weight update, one-parent bag ownership,
ignored bag remove BOOL, unequip and optional possessor/quickbar cleanup order.
Repository RemoveItem14046b250 matches720 cases with captured linked-list
primitives, first matching ID removal and container==1/property32 weight gate.
Native Gold Remove14039e9b0 is distinct from AddGold(-amount);900 Set/Add/Remove
observations now pass. Interactive unequip/quickbar allocation remain required
owners; carried NPC transfers use the existing canonical repositories.

ClearActivities1403877e0 matches80 masks, in its fixed order and excluding4/16.
Creature script event27 records caller19c/item1b0/type1b4, sets last hostile and
runs ScriptDisturbed slot5/context5005.24 full handler+RunEventScript and20 full
getter wrapper observations match; inputs are already spawned548=1, with VM,
hostile/accessor/destructor helpers substituted. Live dispatch tests retain
deleted canonical IDs in the script-visible histories. Creature state771 and
the legacy creatureState accessor now share one cell.

1095 tests/build pass. Installed Prelude smoke retains authored stats/scripts,
resolves enemy attack/damage (player158->157) and player kill (goblin17->-11).
`live-native-skills-observed-combat-trace.txt` retains real skill requests and
three unique errors: encounter entry provider and absent plc_w02/script1.
An earlier observed run completed NPC pickpocket approach/action/cooldown.
These are replacement integrations, not a full original encounter comparison.
Active skills, encounter activation/corpse cleanup, item owners, casting,
broader combat/status/on-hit/presentation and multiplayer parity remain open.
Checkpoint: `backups/live-native-skills-1095-20261013.zip`.

## Animation, life state and item-owner continuation (1059 tests)

Follow-up1086 tests/build pass. CreateItemOnObject and fresh creature acquisition
now use canonical allocation, UTI property loading, native stack caps/merges,
repository insertion, possession/module events and encumbrance. Target lookup
failure allocates nothing; failed template/stack validation consumes then deletes
the new ID. A failed acquisition BOOL still returns a registered unpossessed ID;
pointer replacement during merge returns the existing canonical ID and gold
consumption returns INVALID.1800 complete original creation-wrapper and384 fresh
AcquireItem owner executions match captured ctor/template/repository/lookup/
encumbrance/area/possession substitutes. This validates owner order/branches,
not full transfer or transitive acquisition/property/network behavior.

SetIdentified stores unrestricted INT and only exactly1 marks price dirty398;
24 complete native setter observations match. GetIdentified is connected.
Creature weight dirty96c/encumbrance970/total978 constructor zeros are now owned.
CResRef InitFromCharArray140190d30 copies16 bytes up to NUL; item creation retains
that raw reference while the resolver uses active resource precedence. Item
canonical tags retain full stored strings independently from truncated lookup
keys and the original authored Tag. A live resource-backed stack-merge test
confirms pointer/ID reuse and deletion without ID recycling.

Authored Prelude retaliation/kill now completes the goblin's loot creation and
identification scripts; CreateItemOnObject/SetIdentified no longer abort them.
Observed remaining errors are actual missing PWK/NCS resources, pickpocket skill
calls and an encounter activation dependency. Make-room dropping, old-owner
removal, placeable/store/container acquisition, container destruction, dynamic
world item placement/bodybags and casting remain explicit incomplete owners.
Backup: `backups/live-fresh-item-acquisition-1086-20261013.zip`.

Follow-up1082 tests/build pass. Generic talent random/best selection is connected
for owned noncaster constructor pools, actual item properties/repositories and
2DA feat/skill eligibility, retaining CRT branch retries/ranking and canonical
item IDs. Caster/known/memorized import and nonzero spell/component eligibility
remain explicit unavailable owners; this is not a fake empty spellbook for
casters. ReadStats140410bfb per-day BYTE import and1404122dc SLA WORD/BOOL/BYTE
import (caster-level cap15) are traced. CanUseItem PC ILR/minimum-level pricing
is still explicit, rather than assuming a server setting. Skill rank consumes
BYTE ID while HasTalent's untrained metadata consumes WORD ID at1403fae3e;
out-of-allocation reads are now explicit instead of returning an invented zero.

GetHasFeatEffect/GetHasSpellEffect, GetArcaneSpellFailure, GetAbilityModifier,
IntToFloat, GetIsPlayableRacialType, GetWeaponRanged and GetDistanceBetween are
connected.541 original body/wrapper observations cover feat/spell-effect scans,
signed armor/shield/effect BYTE summation, scalar conversion and cached ability
queries (DEX param0 bypasses armor cap). VM/lookup inputs are substitutes;
full ability/equipment cache materialization is still the existing rules
adapter, not independently validated here. Playable racial type intentionally
compares original constants0..6, not racialtypes.PlayerRace: wrapper140527660 and
DAT140dc3e58..70 are verified. DistanceBetween returns0 on invalid lookups and
does not reject different areas, unlike DistanceToObject. Original magnitude
1402303d0 uses native XYZ multiply/add order.

Two-sided authored Prelude smoke now passes: the goblin resolves a real attack
against canonical player565, player input resolves strikes/damage, and goblin475
dies. No creature stats/items/AI or roll results are patched. This smoke is a
replacement integration check, not original encounter/draw-order parity.
`combat-retaliation-prelude-b-ui.txt` also passes actual radial Attack, rendered
enemy attacks201/202/205, damage reaction214 and fall220→222→held8. All14 rendered
creature bindings have zero clip failures. Screenshots of attack/fall were
inspected; geometry can still occlude actors and native camera obstruction is
not mapped. A failed earlier radial attempt remains captured separately.
Remaining observed errors include missing plc_w02 PWK/script1 NCS, authored
CreateItemOnObject and ActionUseSkill, and an encounter-activation dependency.
Loot acquisition, skills, encounters, casting, ranged/special/status breadth,
full client animation queues and multiplayer parity remain open. Backup:
`backups/live-authored-retaliation-1082-20261013.zip`.

Follow-up1077 tests/build pass. Creature and one-level container item import now
allocates canonical objects before loading templates, admits actual property
pools, uses separate eighteen-ID equipment storage and head-inserted repository
nodes, and calls the mapped possession owner. Failed templates consume IDs;
failed carried-item fits retain registered unpossessed objects. Physical caps,
container stack merging, deferred tag registration and raw authored data are
preserved. Active base-row metadata is cached per table instance, not per module
or campaign name. NPC stats IsPC missing-field default is corrected to1.

CompareItem140466220 matches1080 native executions. SetGold1403a3180 and
AddGold14037eda0 match600 complete executions including signed/unsigned wraps,
caps and effective feedback deltas. CanEquipWeapon1403d19c0 matches6480 native
executions, and the import variant of CanEquipItem1403d12c0 matches8064 executions
with restriction/proficiency helpers stubbed true, DM/possessed false, NULL
client and flags(1,1,1,NULL). Native client preview mutation and interactive
identification/ILR gates are outside this import comparison. Required feat rows
use physical ReqFeat0..4 successful cells from LoadBaseItemInfo14029dfa0.

Module equipment events39/40 retain separate item/actor/slot histories and run
event scripts15/16;48 full original EventHandler/RunEventScript executions match.
Native ctor equipped slot378 starts-1. Current equipment combat effects/AC still
use the existing rules adapter after creature stats import, not a full native
EquipItem/ApplyItemProperties effect-ID/materialization oracle. Placeable/store
repository import, saved item effects, quickbar lifecycle, equipped item property
propagation, complete acquisition, talent spell state and skill actions remain
explicit open owners. Prelude authored smoke: initialization has no errors;
player attack17HP→-11HP passes. It is still one-sided: GetCreatureTalentBest/
CreateItemOnObject/ActionUseSkill remain unavailable, with two genuinely missing
resources. This is not full combat or multiplayer parity. Backup:
`backups/live-native-inventory-1077-20261013.zip`.

Follow-up1067 tests/build pass. Module item script events19/20 and six history
getters are connected: acquired/from/by/quantity and separate lost/by/quantity
cells retain canonical references after deletion and with empty scripts.288
original handler executions plus native RunEventScript/getter executions match.
VM script/stack/accessor/destruction helpers are captured; Tracy is disabled.
Native script context3007/3008 reaches the replacement VM frame; complete native
VM compilation-cache/profiling behavior is outside this scalar validation.
Native item initial import, CanEquip/Equip/Acquire, talent spell state and skill
actions still need integration. Backup:
`backups/live-module-item-events-1067-20261013.zip`.

Follow-up1064 tests/build pass. `setItemPossessor` matches1024 complete original
executions: one-level bag-to-creature attribution, acquired/lost/disturbed event
order, old-owner quickbar selection, PC stats b0 forcing drop/pickpocket flags,
canonical direct owner assignment and same-owner early return. Event/feedback/
quickbar handlers are captured substitutes; live import remains unconnected.

Active use counts/cache and visual selection match2430/90/3960 complete original
executions. Physical active property indices govern the eight display bytes and
x86 shift masking; daily display uses UsesPerDay with remaining as a flag. Native
GetUsedActivePropertyUsesLeft's declared WORD is compared separately from raw
RAX (cost6 can retain high bits). Item visuals retain first physical property
priority, including the zero-VFX damage property's stop flag and wrapped BYTE
values. Dynamic ItemPropDef SubTypeResRef/VisualFX columns precede legacy
switches; names/data come from active tables and required resource providers.
Packets and item visual rendering are not validated by these scalar oracles.

Research correction: OnApplyItemProperty's140466660 call is **ComputeWeight**,
not item-price recomputation. Its weight owner already exists in
`inventory_weight.js`; accepted pools need connecting to it.14046cf20 is active
use cache/message selection,14046d140 is visual selection. Native item ctor
initializes repository positions0/0, direct possessorINVALID, charges50,
stack1, drop/pickpocket flags1 and identified0; base CNWItem ctor uses base24.
Area creature import forwards load flags; ordinary new GIT load flag0 causes
ReadItemsFromGff script-events1. Those events require module handlers, so do not
connect initial ownership with an invented event-suppression flag.

Backup: `backups/live-combat-item-possession-presentation-1064-20261013.zip`.

Live radial attack now renders native-selected swings, reactions, directional
falls/death transitions and held body poses; see [animation evidence](combat-client-animation.md).
ModuleSession death/dying checks now use object INT89c rather than semantic
isPC and require associate WORD3 plus a controlling client for possessed-familiar
thresholds. GetDead1404953b0/GetIsPCDying140495620/possession1403d54d0 match432
native executions, including signed SHORT HP and two dying HP queries.

`item_property_pool.js` ports the OnApplyItemProperty acceptance/materialization
phase with required post-change providers: numeric physical ITEMPROPS columns,
ammo subtype remapping, separate preincremented uint64 property IDs, active/passive
records and native use restoration.144 complete original handler runs pass with
unpossessed synthetic items and explicit table/pool/post-cost substitutions.
This is not yet live import or complete dynamic item propagation. GFF new-format
property defaults are mapped; effect allocation precedes possible rejection.

`repositoryAdd` ports AddItem140464200 with required gold/merge/feedback/event
providers; placement uses actual CheckFit/FindPosition and AddPanel BYTE arithmetic.
384 complete native AddItem/CheckFit/FindPosition/AddPanel executions match on
the no-merge path, including scanning, failed fit, duplicate IDs and expansion.
Gold/merge branches have case tests only; their surrounding handlers remain
unconnected. SetPossessor14046c520 is traced next. No live repository is rebuilt
from the semantic inventory array and no unavailable owner is replaced by a
successful no-op.

All1059 tests/build and authored headless combat pass. Talent, creation/acquisition
and skill calls remain open; the full authored combat/casting cycle and original
encounter parity are not complete. Source/evidence backup:
`backups/live-combat-life-item-repository-1059-20261013.zip`.

## Item eligibility and repository continuation (1038 tests)

Creature inventory import now allocates equipped records before carried records,
with the native18 equipment/360 stats-PC carried record limits. This is connected
in ModuleSession. ReadItemsFromGff is14039c170..14039caf9, reached by LoadCreature
140397a1f. Its equipment list starts14039c2d2; carried list starts14039c86d.
Carried AddItem uses merge0/autoexpand0 at14039ca5a, and success with nonnull
item calls SetPossessor at14039ca7d. Equipment eligibility/fallback acquisition
and full possession events remain unfinished; import-order correction alone
does not establish full native inventory parity.

`src/item_use.js` ports CanUseItem1403d2410..1403d2821 with required providers.
`src/item_restrictions.js` ports alignment1403d2830, class1403d2c00,
race1403d2ce0, UMD1403d2ef0, proficiency1403d2d90 and scroll opposition guards.
These owners are not yet wired to live talent selection. UMD checks the first
physical cost bracket, uses a signed BYTE rank and distinguishes unsuccessful
requirement reads. Chest proficiency uses ModelType BYTE+16==3; size guards
read WeaponWield BYTE+8 and WeaponType BYTE+9. The loader verifies these names;
do not label+8 ModelType or+16 WeaponType. CanUseItem/proficiency match669
original machine-code runs with explicit metadata, restriction, controller
and configuration substitutions (`native-item-use-observations.json`).

`src/item_repository.js` supplies canonical-ID linked head insertion and the
native constructor/fit/initial grid scan. CheckFit140465c10..140465e59 matches
1050 original machine-code runs (`native-repository-fit-observations.json`),
including byte-wrapped rectangle endpoints, page limits, stale/nonitem/self
IDs and physical traversal. These are separate from AddItem's acquisition,
merge, expansion, drop and event owners. No live repository is synthesized
from the semantic inventory array to bypass those dependencies.

Research correction:140397ba0 is CNWSSpellScriptData::LoadData, **not** the
creature inventory loader. The earlier-named personal-import/inventory-import
captures are retained for audit; their headers identify the actual functions.
The verified creature item owner is in `live-native-creature-import-c170-*`.
Property initialization also needs correction: OnApplyItemProperty14042e793
stores effect INT8 into remaining DWORD+12. PropertiesList's Useable BYTE
defaults1 (14046a43f), so explicit UsesPerDay alone does not imply remaining0.
RestoreUsedActiveProperty only overwrites type15 counters when its flag is0
or UsesPerDay BYTE is255. This property owner is still unconnected.

All1038 tests and the build pass (`live-native-item-repository-tests.txt`,
`live-native-item-repository-build.txt`). Authored combat still damages the
goblin17 to-11 (`live-native-item-repository-combat-trace.txt`). That trace
contains seven distinct failures: three GetCreatureTalentBest sites,
CreateItemOnObject, one ActionUseSkill site and the absent plc_w02 PWK/script1
NCS resources. The other previously observed ActionUseSkill site remains an
open owner despite not occurring in this run. No unresolved call is suppressed
or marked implemented, and this is not full native encounter/casting parity.

## Talent owner continuation (1028 tests)

Six talent value/accessor calls are connected to ModuleSession. RSADD talent
allocation now uses the constructor instead of null (CreateGameDefinedStructure
14050d208..14050d222, CScriptTalent14048bd50..14048bd73). Type/ID are raw INTs;
validity only tests type!=-1. Constructor class0/metamagic255 differ from selector
class255/metamagic0. Copies retain independent engine values.

The generic selection owners in `src/talent.js` and `src/spell_talent.js` are
implemented with required providers. They are **not yet connected to live
GetCreatureTalentBest/Random**: item acquisition/property pools, CanUseItem,
spell import/remaining-use ownership and spell eligibility must be connected
first. No empty talent substitutes for an unavailable provider. HasTalent's
feat/skill branches and full selector traversal are ported; its spell branch
is still a required dependency. Full combat/casting remain incomplete.

Read-only native selector oracle `scripts/inspect-native-talents.py` executes
1403fb150..1403fb32a and1403fc050..1403fc290 in Unicorn. All60 comparisons pass
for selection, signed skill ranks, remaining-use BYTE narrowing, duplicate
candidates, native creature WORD state gates, effective-rank invocation order
and CRT draws. Table/ownership/rank and allocator/list operations are explicitly
substituted; this is not a full original encounter or spell oracle.
`backups/animations/native-talent-selector-observations.json` contains those
observations and the binary hash. Full disassembly is in
`live-native-talent-feat-skill-selector-full-asm.txt`.

Verified selection details:

- Stats dispatcher1403fae70 retains physical class order, retries already-failed
  branches while consuming RNG draws, checks spell-like abilities first, and
  uses item spell selection last. Categories17/18/20/21 go directly to items.
- Feat/skill Best only distinguishes maxCR==-1 from other INTs. It ranks highest
  metadata CR (initial-100) without imposing the supplied cap. Ties and physical
  duplicates remain candidates. Skill selection does not check class usability.
- Spell loader1402afb18..1402afbcb derives ranking CR from full INT Innate*2-1;
  suitability uses the separately narrowed BYTE Innate plus metamagic cost.
  SubRadSpell1..8 compact successful reads; Master falls back to its physical ID.
- Known1403fb330, memorized1403fb940 and spell-like1403fcc30 candidates retain
  duplicates. The known count is WORD but the traversal cursor is BYTE; unsafe
  wrapping input is diagnosed. Spell-like selection tests remaining!=0, while
  HasTalent's ability-list ownership helper tests remaining==1.
- Suitability1403f1bf0 checks ownership/parent before area filtering. Missing
  area skips category filtering; non-full effective PvP swaps categories1/11.
- Item selector1403fc3b0 checks equipped slots1..2^17 before repository nodes.
  **Equipped items call CheckSpellSuitability; carried items do not**. Carried
  potions are skipped for categories4..9/13..14 and accept the native paired
  aliases17/18/21/20. Canonical item IDs and active property indices are retained.

Unfinished owner evidence is retained, without claiming implementation:
`live-native-repository-owners-full-asm.txt` maps ctor140462d40, FindPosition
1404681d0, CheckFit140465c10, AddItem140464200 and SetPossessor14046c520.
AddItem140464a9b inserts at the **repository head**, not tail. Creature ctor
14037a702..14037a71b constructs width10/height36/boundary60. Native acquisition
may merge and destroy the new item, returning INVALID through the creation
wrapper even though the stack was acquired. Do not push into a semantic
inventory array to approximate these owners.

ReadStatsFromGff140410bee imports spontaneous SpellsPerDayList/NumSpellsLeft;
ReadSpellsFromGff14040f3e0 allocates slots through native rules and remaps known
spells through AddKnownSpell. SpecAbilityList140412201 reads WORD Spell,
BYTEasBOOL SpellFlags and BYTE SpellCasterLevel clamped15. Do not derive live
spell uses from displayed gains or class names. LoadDataFromGff140469440 and
OnApplyItemProperty14042e5c0 validate ITEMPROPS by base PropColumn before adding
active/passive records. Charges defaults50 and clamps250; RestoreUsedActiveProperty
14046b580..14046b5eb restores specific counters. This remains unconnected.

All1028 tests and production build pass (`live-native-talent-core-tests.txt`,
`live-native-talent-core-build.txt`). Current authored combat still has eight
distinct errors: three talent call sites, CreateItemOnObject, two ActionUseSkill
sites and the absent plc_w02 PWK/script1 NCS resources. Remaining failures are
retained; this checkpoint does not mark them resolved.

## Implemented owners

- ActionDoCommand: wrapper14050d8a0, commandability1404ab090,
  creature AI action1404a0500. Action37 owns its saved VM situation in the
  canonical object action list. Execution uses the actor's actual OBJECT_ID;
  consumed or cancelled situations are released. Failed script execution is
  recorded and consumed, never replayed on the next frame. Noncreature AI
  execution remains unsupported.
- GetIsInCombat / GetIsEncounterCreature / GetActionMode read native fields,
  including raw combat INT and exact detect BYTE==1. GetIsDay/GetIsNight use
  the cached module time-of-day BYTE. Keen Senses implicit detect mode is retained.
- Listening flag: constructor14048ba56, GFF BYTE import140397a69,
  unrestricted script INT assignment. Pattern parsing and speech matching remain
  separate owners and are not substituted by a boolean flag.
- First/next PC:14055fc40/140560cc0, constructor cursor14055c5ca.
  One shared cursor traverses actual client slots, skips holes/invalid IDs and
  does not enumerate authored IsPC creatures.
- Legacy emotions1405236d0 query target reputation toward source:
  enemy<=10, friend>=90, neutral11..89. These differ from the AI reaction
  wrappers140527780. Missing source remains native neutral50.
- Distance140522840 uses f32 3D magnitude and pointer-equal areas, including
  two null area pointers. Invalid source/target returns-1.
- Facing140541400 uses native XYZ and Vector normalize140230920; exact
  commandable INT==1. Class guards permit creature/item/placeable/waypoint,
  excluding doors. Placeable collision orientation updates remain unsupported.
  Degree facing uses the verified CRT sinf/cosf provider; unsupported CRT
  dispatch/exception inputs remain diagnosed.
- Commandability140521050/14053fc80 and constructor14048ba4c share fieldEc
  across script queries, action requests, facing and deferred commands.
  SetCommandable writes boolean INT, GetCommandable returns raw INT.
- Faction member wrappers140524320 and owner1404ae1b0 retain per-faction
  cursor18, physical member order and raw statsPC+b0 filtering. Exhaustion does
  not advance/reset the cursor. Class guards follow GetFactionOfObject14055fb00.
- Destroyability1405420a0/140526d50: constructorF0=1/F4=0/F8=0;
  script sets booleanF0 and raw raiseable/selectable INTs. Already-dead NPC
  enabling destruction unlocks orientation before scheduling event11 at3000ms
  with the last damager ID. Actual corpse/event11 destruction remains unsupported.
  PostProcess14039b4d3 copies statsPC+b0 into the distinct object89c cell.
- Achievement wrapper14054a630 routes object0/string0/int0..2 to the actual
  client using native message subtype0x14. Platform presentation is explicitly
  recorded as unimplemented; no external platform award or save flag is invented.

## Indoor hearing

PlotSoundPath140370e60 and InterTileDFSSoundPath14036e260 are connected to the
area's PathInformation288, allocated by the native area constructor. Sound
uses engine-defined graphs selected by active SET PathNode/VisibilityNode/
DoorVisibilityNode metadata and their rotations, independently of WOK resource
identity. No module names or custom free-space fallback are used.

Read-only Unicorn emulation executes ComputePathNodeInformation1402c84c0 and
ComputePathNodeRotation1402ca770 for all120 valid types and four rotations.
Only local memory allocator calls are substituted. The480 graph observations
are retained in `backups/animations/native-tile-path-node-observations.json`;
`scripts/extract-native-tile-path-nodes.py` reproduces them and
`scripts/generate-tile-path-nodes.mjs` generates replacement constants.
This validates graph constants, not a running-game hearing encounter.

The port preserves depth5, per-tile visited depth, physical entrance order,
native early out-of-array rejection, Manhattan pruning, f32 boundaries and
normal/visibility/closed-door graph selection. Region selection follows native
triangle half-plane tests and adjacency DFS1402bd480. A point outside walkable
triangles returns0; a disconnected triangle chooses the nearest centre with
first-index ties. Entrance lookup1402becd0 uses native epsilon0.0001.

Door membership follows AddToArea14041e410: floorf(position+/-0.5)/10 adds up
to four tiles in native insertion order. Shared-edge closed-door tests use
both SET Doors BYTEs, half-unit rectangle bounds and orientation dot threshold
0.707. Invisible models follow native GetOpenState and active doortypes
BlockSight lookup. Dynamic door insertion/removal/orientation ownership remains
diagnosed rather than silently reusing stale geometry.

## Validation and remaining work

### Trap queries, knockdown and byte conversions (1018 tests)

FloatToInt140313790 preserves f32 CVTTSS2SI, including INT_MIN on invalid
conversion. LowerCase14016bd70/UpperCase14016c8c0 use verified CRT ASCII
ranges140c7fe98/140c7fec4; non-ASCII locale conversion remains explicitly
unavailable rather than applying Unicode case folding.

NearestTrap14052ceb0 traverses CNWSArea+158's physical uint32 ID list,
skips stale IDs, uses squared f32 XYZ distance strictly below10000, retains
first ties, and checks object-owned known-ID lists only when detected==1.
DoorLoad1404208a0/PlaceableLoad1404b4900 read TrapFlag through BYTEasBOOL
1401a0f60; TriggerLoad140502ac0 sets its flag from Type DWORD==2.
Known lists start empty in constructors14041d6b0/1404af9c0/1404fea40.
Area import append sites140360c3c/140361d4a/140362f5c and remove owners
1404226c0/1404b6930/140504200 are connected to canonical storage. Query
does not filter TrapActive/TrapDetectable or recheck live TrapFlag. Detection,
firing and scripted creation remain separate incomplete owners. LoadGIT
140360f40's actual type order now drives local allocation, including ground
items before triggers and stores after sounds; exact original session ID
allocation still needs independent comparison.

EffectKnockdown constructor1405180b0 ordinal252 creates internal type46,
subtype8. OnApply14042e980 converts instant to temporary3s, preserves
immunity28/source-first feedback129, plot/dying guards, round pause, action
cancellation and commandableEc0. Creator lookup and normalized XYZ dot>=.707
choose native body/animation5/7 or6/5. Hidden linked type23 has the SAME
uint64 ID and duration+1.5s (copy ctor140423570). Its apply/remove owners
140431690/140438370 update canonical WORD8d4 and DEX modifier cache.
OnRemoveKnockdown140437770 restores pause/ambient state/control with native
quirks, including restoration while another knockdown remains. Native
RemoveEffectById140498280 removes ALL matching IDs from the live array,
callbacks before deletion: expiry of type46 also removes linked23 immediately.
UpdateEffectList14049e0a8 verifies that expiry calls this ID owner. The earlier
single-record removal was wrong for linked effects and has been corrected.
GetScriptEffectType140423fe0 returns knockdown34, death94 only with all!=0.
Saved effects, generalized status DEX/effect bonuses and MDL status animation
presentation still require their remaining owners; no full-status parity claim.

1018/1018 tests and production build pass. Authored full Prelude integration
passes HP17->-12 (`live-trap-knockdown-combat-trace.txt`) with eight distinct
errors left: GetCreatureTalentBest at three script sites, ActionUseSkill at two,
CreateItemOnObject, and absent plc_w02 PWK/script1 NCS resources. Every failed
occurrence remains recorded. Combat/casting and complete native encounter
comparison remain unfinished. Source/evidence archive:
`backups/live-engine-trap-knockdown-1018-20261013.zip` (all entry SHA256 checked).

### Listening, movement and script animation continuation (1008 tests)

Read-only native emulation executes ParseString140440970/TestString1404413c0
and their node helpers: 70 parser graphs/error observations and 1904
match/capture comparisons pass. Allocators/string memory helpers and ASCII
LowerCase are substituted explicitly; non-ASCII locale folding remains rejected.
`scripts/inspect-native-listen-expressions.py` records the original SHA256 and
substitution addresses. The object owns physical pattern slots, capacity and
IDs. Associate patterns come from executed SetAssociateListenPatterns1403d8160,
including native negative IDs and registration order. Imported ExpressionList
and the actual GetIsListening/SetListening names connect to those owners.
TestStringAgainstPattern uses a local expression, preserving native separation
from object speech-event captures. Speech dispatch remains open.

GetIsDawn140526c90/GetIsDusk1405270e0 read cached module BYTE3/4.
CExoString Right14016bfa0/SubString14016c710 and GetStringLength140313ae0
preserve byte boundaries for the current single-byte NCS/GFF codec; unsupported
text is diagnosed. Negative substring length means the remainder, while negative
Right length means empty. Native movement wrappers1405365f0/140536910 append
real move1/radius17 records, preserve the group, use-range floor, target-position
point, location-area fallback and differing commandability gates. Force variants
preserve the native timeout slot, default30. ActionWait14054b100 appends wait30
and uses the existing native wait owner.

Script animation switch140538ba0 is generated from bounded disassembly, with
active appearance MODELTYPE deciding IDs112/113. ActionPlayAnimation queues6;
PlayAnimation clears first and inserts at head. AIActionPlayAnimation1404a4700
preserves first-run clock reset, speed/duration conversion, fixed native timings,
long-animation consecutive merging and idle completion. Creature ClearAction6
uses the shared cleanup tail. Client MDL state routing, noncreature execution
and scripted-door automap lifecycle remain explicitly unavailable.
EffectDeath constructor1405180b0 ordinal133 creates type19 with raw flags and
delegates application to the existing death owner, which continues to record
its presentation/associate/corpse limitations.

1008 tests and production build pass. The newest full authored Prelude combat
run passes, HP17->-11 (`live-death-script-combat-trace.txt`), with ten unique
error messages. Remaining calls in that run are FloatToInt, EffectKnockdown,
GetCreatureTalentBest, GetNearestTrapToObject, CreateItemOnObject and
ActionUseSkill, plus actually missing plc_w02 PWK/script1 NCS. This closes the
listed wrappers, not complete combat/casting or native encounter parity.

### Earlier 992-test checkpoint

992 tests and production build pass. Installed unmodified Prelude.nwm,
area m0q1d, authored M1Q0D19Goblin and fighter.bic pass the integration harness:
queued player attack executes, target HP17->-11, repaired wrappers stay available
and indoor hearing no longer reports a missing sound path.
`backups/animations/live-engine-992-prelude-trace.txt` records this run.
The harness now asserts actual damage and repaired dependency availability.

Sixteen unique error messages remain in that run: listening patterns/associate
patterns, EffectDeath, EffectKnockdown, ActionPlayAnimation, creature talents,
nearest trap, item creation and ActionUseSkill, plus genuinely absent plc_w02
PWK and script1 NCS resources. Fixing wrappers allows scripts to reach additional
missing owners; this is not an assertion that all engine calls or combat are done.
Every remaining failure occurrence stays in the durable diagnostics journal.
Complete original encounter comparison, combat presentation, corpse/status/on-hit
owners, casting and multiplayer compatibility remain open.
# Complete encounter and weapon-query follow-up (2026-10-13)

`live-native-complete-encounter-combat-trace.txt` clears encounter481 through canonical death handling: authored retaliation and a player kill precede four spawned enemy deaths, the active count reaches zero and the encounter deactivates. Its only diagnostics are absent installed `plc_w02` PWK and `script1` NCS resources. This is an integration test, not a whole-fight native differential oracle.

New original instruction captures compare622 shape searches,630 associate/54 henchman queries,20 base-item reads,864 seven-call inventory enumeration sequences,32790 cosine/sine FLOAT results,40 location constructors,576 equip/72 unequip mutations,1296 AI equipment gates and864 melee/ranged/ammunition selectors. Captured dependencies and finite math domains are recorded in each oracle generator. Ranged selection uses attack modifier, not damage; all choices retain physical repository ordering and active base-item data.

The local runtime now connects those owners, safe-location approach fallback and lower equipment mutations. Passive item-property application/removal, queued gear execution, inter-tile area plotting, higher transfer/drop/effect owners, encounter AI/respawn and corpse cleanup remain explicit failures when selected. Casting and network compatibility are unfinished. Native location orientation storage is supplied by the constructor; GetFacingFromLocation and the existing GetLocation producer still need their own traces.

1119 tests and the production build pass (`live-native-weapon-cycle-full-tests.txt`, `live-native-weapon-cycle-render-build.txt`). Rendered authored attack/fall coverage from1109 remains valid for that version. The new spawned-target GUI approach test times out while the player attacks a nearer authored goblin; it does not establish spawned radial picking or current-build animation acceptance. No authored stats, AI or objects were overridden to make it pass.

# Timed equipment and cancellation follow-up (2026-10-14)

New captures compare864 AddEquipItemActions requests,3456 AddEquipAction round insertions/replacements,768 AIActionEquipItem completions,48 ClearAction action8 cancellations,1768 owned-item RunEquip executions and3912 RecomputeRound cases. The queue preserves record identity, first matching item-or-slot replacement, exact-one pause gates, original round rescaling and1500ms pause. Attack count(+c) and equip slot(+1c) remain separate fields. After-front insertion follows the first contiguous action group. Recompute retains the original newCount-currentAttack reduction count and unfiltered physical group scan, with class constants5/40 read from the binary.

`live-native-equipment-cycle-integration.txt` passes an installed plain-dagger fixture: ordinary action8 and timed round6 both execute, the old item returns to the repository, the new item leaves it, all canonical IDs/direct owners persist and no engine diagnostics occur. A short sword is correctly rejected for the authored goblin's proficiency; the fixture uses a permitted dagger. The fixture explicitly sets round timing/count fields and adds items through the engine, so it is not an authored-fight parity claim. Client/ILR, passive properties, bag/creature transfer, merges, failed-placement drops and RunUnequip still have explicit missing owners when selected; those transitive paths are not proved by the captured helpers.

Manual movement previously cancelled only the UI interaction queue, leaving native attack/approach actions active. WASD, Escape and the UI cancel control now enqueue ClearAllActions in the same local input FIFO as Attack. Identity guards discard cancellation after a controlled-object change, and unit coverage verifies ordering. This is local input integration, not reverse-engineered cancellation packet parity.

The rendered authored enemy check passes with26 actors and no animation failures (`combat-current-authored-cycle-ui.txt`); its attack screenshot was inspected. A stricter complete encounter rerun (`live-native-equipment-complete-encounter.txt`) fails after a wandering spawn moves behind obstructing geometry. Diagnostics identify the still-unimplemented area inter-tile plot owner and a rotated-height interpolation boundary. This supersedes any inference that one earlier full encounter pass proved reliable pathfinding. Current original path owners are captured read-only for continuation.1126 tests and the production build pass; full combat/casting/native network compatibility remain unfinished.

# Inter-tile search core follow-up (2026-10-14)

GenerateInterTilePath14036bc90 and InterTileDFS14036cba0 are ported in `src/intertile_search.js`;368 original instruction cases match (`native-intertile-search-observations.json`). Comparisons cover two-step iterative deepening, successful/failed physical route writes, per-region BYTE visited pruning, avoidance entry/exit pairs and three temporary allocation cleanup. Original fixed storage constants are32×32×6,8 successors per depth,13 exit-cache slots and terminal exit12. The wrapper uses explicit state parameters; no new 2DA or campaign assumptions were introduced.

Successor geometry and tile exit getters are captured dependencies. The core is not attached to the live area plot provider until native successor ordering, door/path-node selection and intra-tile routing are implemented. `live-native-intertile-*-plain.txt` and `live-native-intertile-core-full-asm.txt` preserve the next owners read-only. The new rendered spawned approach test still times out before retaliation; manual input ordering is unit-tested, but that GUI run does not establish its overall approach success. Authored rendered attack/fall coverage and the passing installed dagger switch fixture remain the verified bounds.1127 tests pass; combat is not ready.

# Inter-tile geometry follow-up (2026-10-14)

InterTileDFSGenerateSuccessors14036d560 now matches1152 original full-owner executions with captured centres/exits/entrances and correctly rounded FLOAT sqrt. IntersectLineSegments140297860 executes its original body in that oracle. Comparisons exposed signed-zero endpoint ties: the source now preserves native lower-endpoint tie selection, then stable descending physical exit order. Native exit-cache exclusions, first-step semantics, neighbour admission and region matching are retained.

Additional path-node getter adapters match25968 full original CNWSTile/surface executions with original quarter-turn rotations and the previously captured node graphs. GetExitNumber uses the full entrance corridor width, while GetRegionEntrance uses epsilon point matching; these are distinct native queries. Loaded mesh and GetTilePathNode lookup are explicit oracle boundaries. Failed/out-of-range output buffers and invalid tile indices remain diagnosed rather than fabricated.

`live-native-intertile-installed-geometry.txt` demonstrates an actual installed-module graph route from77.3,102.7 to84,81, through tile coordinates7,10→8,10→8,9→8,8. It does not establish intra-tile collision/waypoints or authorize replacing the missing area plot coordinator with a generic pathfinder. The live combat runtime still reports that missing owner. Native intra-tile DFS, successor, target-rectangle and best-exit bodies are captured read-only for continuation.1129 tests pass; full combat remains unfinished.

# Intra-tile core and hierarchy follow-up (2026-10-14)

Create/Delete/Get/SetFirstTileFValueAlternatives match240 original instruction cases, including dirty allocation buffers proving that only pointer cells are initialized. The replacement keeps INT cells unreadable until Set and retains successor allocation identity. Supported POD successor arrays now dispose through path reset; unknown pointer representations remain explicit errors.

IntraTileDFS1402bf970 matches312 original full-owner cases: goal/stop rectangles, physical route and triangle writes, two-key128-entry FLOAT budget cache, interruption/resume ownership and unsuccessful bound pruning. Successor generation and FLOAT sqrt are captured dependencies; original alternative-list owners execute in that oracle. Hash constructor defaults are two−1 keys and two−1 FLOAT budgets, independently read from1402ba7a0. Entry and successor work costs are12/300.

RunSubdivision1402c4600 twice, FindTriangle1402bd610 and raw triangle getters execute without geometry substitutions across five synthetic meshes,495 queries and304 getters. Source preserves three new vertices per physical parent (no deduplication), child0/1/centre2/3 order, reciprocal adjacency fallback, F32 midpoint arithmetic and seeded centre-first boundary ties. Subdivision storage must exist before subdivided getters/searches; failed outputs and negative indices are not fabricated.

1133 tests pass. These cores are not substitutes for the missing live area plot owner: native intra-tile successor/collision/best-exit and waypoint commit owners remain open. Full combat/casting/network parity remain unfinished. The source, research scripts and oracle captures are saved in `backups/live-native-intratile-core-1133-20261014.zip`.

# Intra-tile collision and complete successors (2026-10-14)

TestLineForWalkableOnTile/Area match864 full original wrapper executions, with original location, world rotation and NoNonWalkPolys forwarding. Surface clipping/denied polygons and area object/creature queries are captured dependencies. Source retains0.1 FLOAT height padding before strict endpoint rejection, squared endpoint tolerance1e−10, canonical-to-real rotation, tile elevation and exact1 short circuits. Live adapters use the same installed WOK, canonical collision and creature stores as attack approach.

Complete IntraTileDFSGenerateSuccessors matches960 full original bodies with original subdivision, encoded getters/searches and magnitude instructions; collision responses and FLOAT sqrt are captured. Source preserves three levels or level0 only for optimisation==1, native inherited edge masks, physical edge order, direct/corner goals, midpoint and centre traversal and its complete backwards level/score pass. The NPC shortcut skips area admission for direct goals and both collision queries for later midpoint/centre candidates; no broader shortcut is inferred.

Installed geometry acceptance now reaches84,95→86,96 in one pass and77.3,102.7→80,105 around the goblin-area obstruction in two passes, with real collision admission and no actor stat overrides (`live-native-intratile-installed-geometry.txt`, `live-native-intratile-blocked-segment.txt`). This is core integration, not live waypoint commit or full fight parity.1135 tests pass. Native best-exit/surface/tile/area coordinators, commit, corpse/effects/gear/casting and broader original/network acceptance remain open.

