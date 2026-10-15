# NWN Replacement Client Roadmap

This roadmap tracks a plausible replacement for the NWN: Enhanced Edition client. It does not assume that matching rendered screenshots is sufficient: the client must load modules, simulate the relevant world state, execute gameplay rules, present usable UI, and preserve progress.

## Target and completion tiers

Keep the current compatibility target fixed at NWN:EE `89.8193.37-17` unless a later decision expands it. The game install remains read-only; user-authorized Ghidra annotations require periodic backups. The replacement loads user-provided game data and does not ship BioWare assets.

There are two distinct goals:

- **Single-player replacement:** play the entire original campaign, Prelude through Chapter4, without launching the original client, with usable combat/casting/UI and persistent progress. This is the current priority. Representative local modules remain regression fixtures, not sufficient completion evidence.
- **Server-compatible client:** connect to an unmodified NWN:EE server and participate alongside original clients in authoritative multiplayer sessions. This is a required acceptance gate, separately validated from local play; it does not require replacing the server. Server authority and native identities constrain earlier implementation work.

A replacement server, toolset, and broad compatibility with community modules are explicitly beyond the initial target.

The base-game completion gate requires a continuous low-level-character
playthrough, quest/dialogue/journal and companion progress, normal combat and
casting, corpse loot, equipment/stores, resting/leveling, authored area/chapter
transfers, save/reload and final completion. Preserve native IDs and active data
tables throughout; fixes must not depend on a campaign name, NPC tag or a stock
high-level test character. Every selected unsupported owner or load failure
remains recorded until implemented and validated.

## Current checkpoint

- **2026-10-15 missing script-load behavior:** installed Prelude ARE fields
  reference absent script1 heartbeat/script2 exit resources; neither NCS nor NSS
  exists in the module, active base/retail catalogs or installed override folder.
  Shared named-script execution now returns native failure0/load error-634 while
  retaining a diagnostic for each attempt. Missing actions/exit scripts permit
  the caller to continue; missing dialogue conditions reject the branch. Failed
  loads are retryable, and parser/read/engine failures remain explicit. 1313
  tests/build and rendered out-and-back traversal pass without missing-script
  session errors or HUD interruptions. See [native evidence](evidence/missing-script-load-behavior.md).

- **2026-10-15 scripted doors and area exit:** StringToFloat and AngleToVector
  unblock the standard transition script. ActionOpenDoor/ActionCloseDoor now
  create native object actions20/21; canonical door AI drains them into deferred
  open/close events, linked-door state and source callbacks. Both original
  reported dialogue scripts and the m0q1a to m0q1b transfer pass. Physical binary
  parent indices prevent duplicate node names from creating self-parent errors
  during destination loading;106 model resources audit successfully. 1307 tests
  and build pass. Rendered m0q1a to m0q1b and back passes without renderer errors
  while retaining canonical IDs. Creature-owned scripted door approaches/locks,
  native door displacement/automaps and broader transition acceptance remain open.
  See [native evidence](evidence/door-actions-and-area-transitions.md).

- **2026-10-14 quickbar assignment and scripted unlocking:** the PC owns36 typed
  quickbar records with native QBList import/export fields and canonical item
  references reconstructed from equipment/repository coordinates. Inventory,
  spell and feat drag/drop, right-click assignment/clear, moving shortcuts,
  modifier rows and per-character local layout restoration pass Electron checks.
  SetLocked now preserves raw integer state and deferred lock/unlock callbacks;
  the original Bim unlock script completes. 1298 tests/build pass. Hotbar use
  emits typed requests; UI execution owners for items/spells/feats and native
  automatic default layout creation remain open and recorded. Radial category
  presentation is local, rather than a fully reconstructed native client menu.
  See [native evidence](evidence/quickbar-assignment-and-locking.md).

- **2026-10-14 dialogue feedback/camera requests:** SpeakOneLinerConversation
  selects authored DLG starts, routes text/sounds and runs entry actions without
  opening a modal. SetCameraMode targets the controlling client. Both reported
  original scripts now execute; rendered Pavel dialogue reaches entry33 and
  applies top-down mode without error. 1291 tests/build pass. Native speech
  bubbles, full token/parameter support and chase-camera smoothing remain open.
  See [native evidence](evidence/dialog-feedback-and-camera.md).

- **2026-10-14 world geometry and movement repair:** binary models now use
  native draw-index groups, restoring combined floor/furniture/wall geometry.
  Player movement loads snapped native tile surfaces, removing invisible cracks
  across tile seams. Repeating polling omissions retain counted records flushed
  periodically and on close/export. 1286 tests/build, installed floor coverage,
  animation smoke and keyboard traversal in both directions pass. Other logged
  engine gaps remain open. See [repair evidence](evidence/world-geometry-and-log-flood.md).

- **2026-10-14 character selection/creation:** module entry now waits for a
  confirmed character. The first-level wizard writes fresh BICs from active
  rules, packages and UTIs, with separate local-vault persistence and export.
  All154 stock race/gender/base-class combinations generate; eleven canonical
  imports and an Electron specialist-creation/save/reload/world-entry flow pass.
  Ghidra/native evidence includes2,304 alignment and36 ability-cost comparisons.
  1282 tests/build pass. Optional native wizard conveniences, arbitrary prestige
  prerequisites, manual level-up and original server acceptance remain open.
  See [character creation evidence](evidence/character-creation.md).
  Backup: `backups/live-character-creation-1282-20261014.zip`.

- **2026-10-14 silence/visibility continuation:** shared silence, invisibility
  and concealment are connected to hearing/observer checks and combat defense.
  110 silence plus242 visibility/concealment native cases compare. Installed
  Silence area callbacks and ordinary/improved Invisibility impact/removal
  probes pass.1271 tests/build pass.184 impact commands remain unbound; full
  casts, Darkness/blindness, rendering and campaign acceptance remain open.
  See [impact/defense evidence](evidence/casting-impact-defense.md).

- **2026-10-14 persistent spell objects:** location and attached area effects
  use canonical IDs, active VFX_PERSISTENT data, native caster metadata,
  geometry, enter/exit/heartbeat callbacks and ordinary removal.1067 isolated
  original-code cases compare; installed Cloudkill/Grease lifecycle fixtures
  complete without engine errors.1266 tests/build pass. Audit-v7 still has186
  unbound impact commands/22 missing scripts; separate persistent callbacks
  expose9 unbound commands/7 missing scripts. Full cast/UI/rendering, harmful
  target acceptance and campaign playthrough remain open. See
  [impact/defense evidence](evidence/casting-impact-defense.md).

- **2026-10-14 ability/bag-weight continuation:** ability buffs/debuffs now
  feed current stats, modifier caches and Constitution injury preservation.
  Standard six buff scripts and Haste pass direct application/removal checks;
  reduced bag weight is connected to Strength encumbrance refresh.1262 tests
  and build pass. All39 imports retain the sole prior PaleMaster HP mismatch.
  Persistent area effects, full casts/UI/rendering and191 unbound commands
  remain open. See [impact/defense evidence](evidence/casting-impact-defense.md).

- **2026-10-14 shared control effects:** Haste/Slow and movement controllers,
  Sleep/paralysis/stun/fear/charm state effects, script immunity queries and
  native ambient body selection are connected. Domination's association
  lifecycle remains explicitly unavailable.1257 tests/build pass; installed
  Haste and Sleep impact branches complete. Active audit still has196 unbound
  commands/22 missing scripts. Full cast/UI/renderer gates remain open.
  Next are area effects and ability modifiers; no campaign-specific handlers.
  See [impact/defense evidence](evidence/casting-impact-defense.md).

- **2026-10-14 linked/location/control foundation:** linked protections/icons,
  property queries, location visuals and Reflex handling are connected. Bless
  and Fireball impact probes complete; full casting/UI/render gates remain open.
  Original command/effect tables exposed and corrected Knockdown's wrong
  internal ID46→20.1251 tests/build pass; pure Haste/Slow controllers await lower
  owner binding. See [impact/defense evidence](evidence/casting-impact-defense.md).

- **2026-10-14 impact/defense continuation:** live visual apply/loop expiration,
  script log, resistance, absorption, immunity and faction equality are connected.
  Authored Magic Missile impact/deferred situations completes HP17→-11 with no
  engine-call errors.1241 tests/build pass. Full casting/render acceptance remains
  open; see [impact/defense evidence](evidence/casting-impact-defense.md).

- **2026-10-14 active full-spell continuation:** release failure ordering,
  automatic Quicken and concentration are mapped; live GetSpellSaveDC uses
  active class/spell/rules.3490 cast and2343 DC original traversals compare.
  Corrected automatic-feat rule labels to EPIC_AUTOMATIC_* and executed the
  original pre-seeded hash leaf in comparisons. See
  [release/DC evidence](evidence/casting-release-save-dc.md). Full impact/effect,
  request/action and presentation binding remains required; work continues.

Latest sealed source/research backup: `backups/live-native-spell-authored-helpers-1236-20261014.zip` (4029 verified files).1236 tests/build and authored combat regression pass. See [release/authored-helper evidence](evidence/casting-release-save-dc.md), [casting metadata/travel evidence](evidence/casting-metadata-projectiles.md), [casting actions evidence](evidence/casting-actions.md) and [spellbook evidence](evidence/casting-spell-book.md) for scope and failed acceptance gates. Full spell ecosystem work remains active.

- **2026-10-14 casting metadata/admission/caster/travel:**1225 tests/build pass. Active spell rows now supply native animation/path enums, timings and master/metamagic/components; ordinary component admission includes exact Silent/Still exemptions and automatic feat thresholds. GetCasterLevel and four further spell-context queries are live, preserving class penalty/scaling and native target-location area semantics. Original capture files contain11361 bounded cases, including the expanded action/context cases; projectile timing is pure and guarded against differing CPU outcomes. Installed-data fixtures check840 spell rows and45 class slots across39 BICs without failures; prior full-import/HP readiness failures remain open. Concurrent authored combat regression passes with the same missing resources/omitted owners. **Casting remains unbound:** release/impact/effects, actions15/18, interruptions and animation integration remain required. Original FMA/process CPU and full-cast/network parity remain open. See [Casting metadata/travel evidence](evidence/casting-metadata-projectiles.md).

- **2026-10-14 resumed casting actions/context:**1211 tests/build pass. Corrected dispatch4/19/49 and bound face-object/point plus wait16, preserving path storage and using trigger polygon centers. Six live spell-context queries use distinct constructor-owned current/history fields. Pure cast queue/timing/round start/removal owners are mapped;1910 bounded original executions cover queues/facing/timing/round/context and an observed ignored-region-query fix. Concurrent authored combat regression passes retaliation, approach and encounter clearing; missing resources and six omitted readiness owners remain recorded. **Casting is still not playable:** action15, admission/release/caster/DC/projectile/impact/effect/script and animation bindings remain required. See [Casting actions evidence](evidence/casting-actions.md). No original full-cast, campaign or network parity claim.

- **2026-10-14 casting foundations:**1194 tests/build pass. Live native spellbook import, readiness/talent/has-spell and class/uses queries now use canonical owned pools. Resource consumption, ability readiness and per-day maximum adjustment match1567 original bounded cases; the pure cast-command/query coordinator matches811 of814 captured cases (three VM-pop failures are separate). The spell panel reads live pools; a rendered wizard shows43 known and34 memorized entries. The installed39-character audit consumes17 caster class slots successfully but keeps `importReady=false` for the Pale Master's102/114 HP mismatch. Prelude's missing resources/startup owners remain recorded; melee retaliation/approach/encounter regression passes. **Casting is not playable:** cast requests and consumption/refresh coordinators still require native queue/action15 timing, caster/impact context, effects, interruptions and cast-animation bindings. See [Casting spellbook evidence](evidence/casting-spell-book.md). No campaign, original full-cast or network parity completion claim.

- **2026-10-14 original campaign startup:**1177 tests/build pass. A fresh-session audit covers all seven base-game modules and321 IFO-listed areas with startup scripts enabled. Fixed the replacement-only256-event fatal limit that aborted five modules' finite spawn batches. Five native script queries plus authored creature/waypoint/door orientation imports match2628 original bounded executions; runtime facing now observes the loaded canonical vector. The authored encounter still passes retaliation/approach and clears all four enemies. The strict startup readiness gate still **fails** on autosave, sitting, effects, casting and other recorded owners; this is not a campaign playthrough or combat completion. Rendered authored-target attacks and cancellation also pass with zero animation failures across26 actors; failed short-lived spawned-target attempts remain recorded. See [Base campaign startup evidence](evidence/base-campaign-startup.md). Corpse copying/loot and full persistence remain open. Sealed source/research backup: `backups/live-base-campaign-startup-1177-20261014.zip` (3544 verified files).

- **2026-10-14 corpse metadata and lifecycle cores:**1167 tests/build pass. Body-bag appearance/get/set matches144/16/48 original executions and installed creature/placeable script queries. Death flag/scheduling/event11 cores match108/432/3456 original bounded cases. Placeable acquisition/corpse collection match360/1296 original complete coordinator cases, with captured copy/storage/acquisition dependencies. Four equipment slots create new loot copies; five size buckets retain physical ordering; raw unsigned gold and native ignored fit returns are preserved. Queries and placeable BodyBag import are live. The lifecycle/transfer coordinators remain **unbound** pending complete item copying, body-bag construction, area removal/destruction and death-effect bridging; live corpse cleanup is still missing. Full combat/casting/original/network parity remains unfinished. Backup: `backups/live-native-corpse-transfer-1167-20261014.zip`.

- **2026-10-14 pending equipment and unequip:**1159 tests/build pass. Native unequip matches1008 original owner executions; eligibility378, pending conversion32, requests1296, round insertion/rescaling180, action dispatch576, cancellation48, page arithmetic400 and script wrappers188. Live attack cancellation and round end now convert pending gear records in native tail order; ordinary/timed unequip and ActionEquipItem/ActionUnequipItem use the same canonical owners. An installed plain-item NPC fixture passes equip/unequip and cancellation with pending gear, with no errors. The full authored encounter passes retaliation/approach and clears its four spawned enemies; six observed omitted owners still prevent readiness. PC item-level restrictions/passive effects, alternate client panels, drops and broader transfer/merge/effect owners remain explicit limitations. Backup: `backups/live-native-unequip-1159-20261014.zip`.

- **2026-10-14 native queue display/cancellation:**1150 tests/build pass. Ten physical queue records match227 original executions; forward normal/special mappings match131072 inputs and the reverse cancellation map matches65536. Cancellation traversal/ownership matches240 original executions. The HUD resolves icons from active actions/spells tables, retains canonical target IDs, and sends cancellation through the local input FIFO. A separate rendered encounter verifies cancellation of group0, fresh radial Attack, approach, swing/fall→held-dead and zero animation failures across26 actors. This establishes the bounded local owners, not packet/network or full combat parity. Corpse/body bags, traps, dirty-stat refresh, automap, voice/achievement presentation and remaining equipment/special/on-hit/casting owners remain open. Backup: `backups/live-native-queue-cancel-1150-20261014.zip`.

- **2026-10-14 rendered spawned combat, corpse fields and LOS:**1144 tests/build pass. A living enemy from the nearest activated encounter is picked by canonical ID through the real radial, approached and killed, with swing/fall→held-dead presentation and zero animation failures across26 actors. Corpse query gates/item count match184 original cases; authored BOOL/BYTE/unsigned decay import matches30. Original rotated LOS generates IEEE nonfinite heights;64 complete clip/rotation and144 box/AABB/polygon executions now verify propagation through the native kernels, removing the replacement-only rejection. The encounter error gate passes again. The all-severity readiness gate deliberately **fails** on seven observed omitted owners (trap checks, queue display, dirty-stat refresh, corpse/body bags, automap, achievement presentation, voices). Remaining special/on-hit/equipment/ranged/casting and original/network comparisons also remain. Backup: `backups/live-native-los-corpse-fields-1144-20261014.zip`.

- **2026-10-14 live area path commit:**1139 tests/build pass. Surface/tile/best-exit/area coordinators match364/577/1731/165 original executions with documented helper boundaries. Native graph and triangle search, corridor collision probes, resumable cache ownership, rotations, route commit and smoothing now drive live attack approach. Installed obstructed geometry commits a route in three passes; the strict authored encounter clears all four spawned goblins with only installed missing-resource diagnostics. Rendered spawned-target radial/animation acceptance is still being checked. Combat remains incomplete: remaining special/on-hit/status and equipment owners, corpse lifecycle, ranged validation, casting and full original/network comparisons are open. Backup: `backups/live-native-area-path-1139-20261014.zip`.

- **2026-10-14 intra-tile collision and successors:**1135 tests pass. Tile/area walkable wrappers match864 original cases; complete triangle successor generation matches960, including hierarchy masks, NPC optimisation, direct/corner goals, midpoint/centre traversal and level/score ordering. Real installed geometry reaches a clear goal in one pass and routes around the goblin-area obstruction in two resumable passes. These core tests do not commit a live area path. Native best-exit, surface/tile/area coordinators and waypoint commit remain to connect, followed by strict full-encounter and rendered spawned-target acceptance. Backup: `backups/live-native-intratile-collision-1135-20261014.zip`.

- **2026-10-14 intra-tile core and hierarchy:**1133 tests pass. Native saved-alternative Create/Delete/Get/Set match240 cases; IntraTileDFS matches312 cases with captured geometry; original subdivision and encoded queries match two passes across five meshes,495 searches and304 getter calls. Path reset now disposes supported resume nodes instead of rejecting every allocation. Native collision checks, intra-tile successor generation/best exits, waypoint commit and the area plot coordinator remain to connect before reliable full encounters. Backup: `backups/live-native-intratile-core-1133-20261014.zip`.

- **2026-10-14 inter-tile geometry and successor ordering:**1129 tests pass. Native successor exclusions/ordering/scoring match1152 original cases; path-node getter/rotation adapters match25968 original cases. Installed Prelude geometry reaches the formerly blocked target tile through7,10→8,10→8,9→8,8 using the verified core. This is an inter-tile graph route, **not a committed walkable path**: intra-tile search/waypoint construction and the live area plot coordinator remain next. No approximate route is substituted. Backup: `backups/live-native-intertile-geometry-1129-20261014.zip`.

- **2026-10-14 inter-tile search core:**1127 tests pass. GenerateInterTilePath/InterTileDFS now match368 original instruction comparisons, retaining two-step iterative deepening, per-region BYTE pruning, avoidance exits, failed route writes and cleanup. This is a verified core with captured successor/exit geometry; it is **not connected as a live area plot provider yet**. Next map native successor ordering and intra-tile routing, then repeat the strict full encounter test and spawned radial/animation test. Backup: `backups/live-native-intertile-core-1127-20261014.zip`.

- **2026-10-14 timed equipment and manual combat cancellation:**1126 tests/build pass. Native equipment request/round queue/execution, owned-item replacement, cancellation and round recalculation are connected;864/3456/768/48/1768/3912 original cases match captured helper boundaries. An installed plain-dagger fixture completes normal and timed switches, keeps canonical ownership/repository membership and applies the1500ms pause without engine errors. WASD/Escape/UI cancellation now clears the native action queue through the local input FIFO. Rendered authored retaliation/Attack/fall→corpse passes with26 actors and zero clip failures; a stricter encounter rerun fails when a wandering enemy requires the unavailable inter-tile path owner. Combat is **not ready**: path reliability, passive item properties, higher unequip/drop/transfer, corpse lifecycle, casting and complete native/network parity remain open. Backup: `backups/live-native-equipment-cycle-1126-20261014.zip`.

- **2026-10-13 complete authored encounter and weapon selection:**1119 tests/build pass. The installed Prelude run includes enemy retaliation, player damage/death handling, all four spawned enemy kills and encounter exhaustion with no engine failures in that capture; two installed resources remain missing. Native shape, associate, inventory enumeration, degree trigonometry/location and melee/ranged/ammunition selection owners now have original instruction comparisons. Lower equip/unequip mutations are connected; queued equipment execution, passive property callbacks, blocked inter-tile plotting, corpse cleanup, encounter AI/respawn, casting and broader native/network parity remain unfinished. Rendered authored attack/fall coverage is retained; a spawned-target keyboard approach test has not passed. See [dependency evidence](evidence/live-engine-dependencies.md). Backup: `backups/live-native-weapon-cycle-1119-20261013.zip`.

- **2026-10-13 encounter combat and dynamic animations:**1109 tests/build pass. Native encounter activation, CR pools, spawn selection/placement, canonical creature template/equipment imports, wandering, lock/location queries, AI removal and death active-count/exhaustion are connected. The authored Prelude test kills an existing goblin and a newly spawned enemy. Rendered radial Attack, enemy swing, player damage and fall→held corpse pass with zero animation failures across26 bound creatures, including dynamically loaded encounter actors. Generic transition selection matches31684 original executions; loop classification matches1712. Corpse cleanup, encounter respawn/AI, shape/associate queries, casting, remaining combat branches and full native/network parity remain unfinished. See [dependency evidence](evidence/live-engine-dependencies.md). Backup: `backups/live-encounter-combat-1109-20261013.zip`.

- **2026-10-13 native skills and transfer:**1095 tests/build pass. Pickpocket request/action, carried item removal, inventory disturbance scripts/getters and ordered activity cleanup are connected;896/486/768/720/24/20/80 original owner observations match captured dependencies. Latest authored campaign run includes enemy damage, player kill and three remaining distinct errors. Other active skills, encounters/corpse, casting and broader combat/presentation/network parity remain unfinished. See [dependency evidence](evidence/live-engine-dependencies.md). Backup: `backups/live-native-skills-1095-20261013.zip`.

- **2026-10-13 combat loot creation:**1086 tests/build pass. Authored creature item creation/acquisition and identification now complete after the goblin kill, preserving canonical IDs, stack merges and module events.1800/384/24 original wrapper/acquire/setter observations match. Old-owner transfer, other inventory owners, make-room dropping, pickpocket skills, encounters, casting and broader combat parity remain unfinished. See [dependency evidence](evidence/live-engine-dependencies.md). Backup: `backups/live-fresh-item-acquisition-1086-20261013.zip`.

- **2026-10-13 authored retaliation and combat animations:**1082 tests/build pass. Noncaster talent selection and eight additional native script queries now let authored enemy AI resolve attacks. Installed-module smoke passes enemy attack, player attack/damage/death; rendered UI passes radial Attack, enemy swing/reaction and fall→held corpse with zero clip failures across14 creatures.541 native query observations pass. Caster eligibility/import, loot acquisition, skills, encounter activation and broader combat/network parity remain open. See [dependency evidence](evidence/live-engine-dependencies.md). Backup: `backups/live-authored-retaliation-1082-20261013.zip`.

- **2026-10-13 canonical inventory import:**1077 tests/build pass. Creature/container loading now uses separate equipment IDs, repository nodes, admitted item properties and mapped possession events. Stack comparison, gold and weapon/import equipment gates match1080/600/6480/8064 original executions; module equipment events match48. Authored player attack still reaches damage/death; enemy talent, item creation and skill owners remain open before a full combat cycle. See [dependency evidence](evidence/live-engine-dependencies.md). Backup: `backups/live-native-inventory-1077-20261013.zip`.

- **2026-10-13 module item-event routing:**1067 tests/build pass. Acquired/lost item events and six NWScript history getters are connected and match288 full native handler observations, with separate histories, canonical IDs/quantities and script contexts. Live native item import/equipment/acquisition/talent/skill integration remains unfinished; the full enemy combat cycle is not ready. See [dependency evidence](evidence/live-engine-dependencies.md). Backup: `backups/live-module-item-events-1067-20261013.zip`.

- **2026-10-13 item possession/presentation owners:**1064 tests/build pass. SetPossessor matches1024 full original executions; active use counts/cache and item visual selection match2430/90/3960 runs. Correct native initial item state and inventory script-event flags are traced. These item owners still need live module-event/import/equipment integration before talent/creation/skill calls can complete the authored combat cycle. See [dependency evidence](evidence/live-engine-dependencies.md). Backup: `backups/live-combat-item-possession-presentation-1064-20261013.zip`.

- **2026-10-13 life/item-owner continuation:**1059 tests, build and authored combat smoke pass. Live radial swings/reactions/fall/death/body sequence passes on installed models. Death/dying reads native object INT89c and actual familiar control, matching432 original executions. Item-property admission/counters match144 runs; repository no-merge insertion/position/panel handling matches384 runs. Item possession/equipment/cost/talent/skill ownership still prevents a full enemy combat cycle; item phases are not yet live import. See [dependency evidence](evidence/live-engine-dependencies.md). Backup: `backups/live-combat-life-item-repository-1059-20261013.zip`.

- **2026-10-13 client combat animations:**1048 tests and build pass. Canonical attack deliveries now select and sample native-named melee/reaction clips on rendered bodies, with separate presentation RNG.30672 native name lookups,2592 selector cases,60 death-animation phase cases and72 body-transition cases pass. Authored radial attack integration passed strikes/reactions/corpse; fall transitions are connected but their follow-up UI camera check is pending. Enemy talent/item/skill calls and other combat owners still prevent a full cycle. See [animation evidence and limits](evidence/combat-client-animation.md). Source/evidence checkpoint: `backups/live-combat-animation-1048-20261013.zip`.

- **2026-10-13 item eligibility/repository continuation:**1038 tests and build pass. Creature inventory allocation now follows native equipment-before-carried order and record limits. Required-provider item eligibility/restrictions/proficiency and repository fit/scan owners are ported;669 eligibility/proficiency and1050 fit comparisons execute the original native bodies. Talent selection, creation/acquisition and ActionUseSkill still need live owners. Authored combat deals damage; seven distinct failures remain in the latest trace, and the other previously observed skill site remains open. See [live dependency evidence](evidence/live-engine-dependencies.md). Source/evidence checkpoint: `backups/live-engine-item-repository-1038-20261013.zip`.
- **2026-10-13 talent owner continuation:**1028 tests and production build pass. Talent values/accessors and VM reservation are connected; feat/skill selectors match60 read-only original machine-code observations. Generic spell/item selection, category/CR and physical traversal owners are ported with required providers. Live GetCreatureTalentBest/Random still need native spell eligibility, item property/repository and CanUseItem owners; the eight recorded combat failures remain open. See [live dependency evidence](evidence/live-engine-dependencies.md). Source/evidence checkpoint: `backups/live-engine-talent-core-1028-20261013.zip`.

- **2026-10-13 trap/knockdown continuation:**1018 tests and production build pass; full authored Prelude combat passes HP17->-12 with eight distinct errors remaining. Native trap ID/known-ID queries and GIT allocation order, FloatToInt/ASCII case conversion, knockdown pause/control/body state and linked effect cleanup are connected. Effect removal now handles every record sharing a native 64-bit effect ID. Trap detection/firing, status animation presentation and full combat/casting remain incomplete. Continue real skill/talent/item owners and native encounter comparison. See [live dependency evidence](evidence/live-engine-dependencies.md). Source/evidence checkpoint: `backups/live-engine-trap-knockdown-1018-20261013.zip`.

- **2026-10-13 listening/movement/script-animation continuation:**1008 tests and production build pass; the full authored Prelude combat harness passes (HP17->-11), with ten unique errors remaining. Listening parser/matcher matches70 native parse observations and1904 match/capture comparisons; object patterns, associate IDs, imported ExpressionList and actual GetIsListening are connected. Native dawn/dusk, byte-string operations, script movement/force movement, waits, animation queue/timing/cancellation and EffectDeath constructor are implemented. Speech dispatch, client animation presentation and death cleanup are still recorded as incomplete. Continue FloatToInt, knockdown, real skill/talent/trap/item owners and original encounter comparison. See [live dependency evidence](evidence/live-engine-dependencies.md). Source/evidence checkpoint: `backups/live-engine-listen-animation-1008-20261013.zip`.

- **2026-10-13 live engine dependencies:**992 tests, production build and an asserted full Prelude combat smoke test pass (authored goblinHP17->-11). Canonical ActionDoCommand ownership, state queries, client/faction iteration, legacy emotions, commandability, distance/facing and destroyability wrappers are connected. Indoor sound now uses traced SET-selected engine graphs, tile/region DFS and door checks; all480 graph shapes/rotations match read-only native emulation. **Sixteen unique errors remain in the campaign run; combat/casting are not complete.** Continue listening expressions, actual skill/talent/animation actions, death/status/item/trap owners and native encounter comparison. Platform achievement presentation is recorded separately. See [live dependency evidence](evidence/live-engine-dependencies.md). Source/evidence checkpoint: `backups/live-engine-dependencies-992-20261013.zip`.

- Source backup: `backups/combat-reputation-lifecycle-checkpoint-20261012.zip` (source, tests, scripts and evidence; original game/Ghidra state unchanged).
- Native-traced FAC/PC/associate/PVP/personal reputation, a persistent 50-record attack pool, target changes, attack cancellation, idle/body/orientation state, melee/ranged group sequencing, independent animation RNG, defender timing and delayed strike signaling now extend the shared runtime. Creature damage events reach live HP at the scheduled impact time; other live combat events remain diagnosed. Attack-history script getters translate native internal IDs. All 358 tests and the build pass; installed reputation/action/timing/damage checks cover Prelude and Witch's Wake, with 39-character bonus checks and bundled character rendering. **Ordinary attacks are still not playable and casting is not implemented.** Dynamic perception/LOS/approach, native attack preparation/default strike and post-hit providers, event/associate/ammunition/projectile integration and presentation must be completed, then compared against the original game. The earlier preview-actor startup/UI failure remains open. See [Reputation/lifecycle evidence and limits](evidence/combat-reputation-lifecycle.md). The prior object-action archive is `backups/combat-object-actions-checkpoint-20261012-181210.zip`.
- The earlier 302-test checkpoint connected pause/round timing before effect expiry, direct OnCombatRoundEnd scripts, provider-level requests, grouped attack-action dispatch and active-rule reach. See [Timing/action evidence and limits](evidence/combat-scheduler.md).
- Damage-effect bonuses now select active 2DA Rank values, preserve native source/hand/critical/RNG rules, project mapped enhancement/damage equipment properties, and update attack components through ordered live resistance budgets. All 278 tests, the build, 39-character checks and existing creature/script-damage checks pass in Prelude and Witch's Wake. Base-only GetSkillRank is mapped; effective ranks remain explicitly unsupported. **Ordinary attacks are still not playable and casting is not implemented.** Native attack scheduling/presentation and independent encounter/server validation remain open. See [Damage-effect evidence and limits](evidence/combat-damage-bonuses.md).
- The earlier 255-test checkpoint connected script damage to live base/temporary HP, mitigation, damage history, direct creature OnDamaged/OnDeath and queued player dying/death events while preserving IDs. Its bundled UI check is historical. Full death/AI/presentation and casting/status/shield damage branches remain incomplete; authored scripts retain missing ActionEquipMostDamagingRanged/effective GetSkillRank diagnostics. See [Live damage evidence and limits](evidence/combat-damage-runtime.md).
- The earlier 233-test provider checkpoint established damage dice/critical/bonus, weapon flag/power, resistance/reduction and base/temporary HP primitives, installed retail KEY precedence and script immunity cache updates. See [Damage provider evidence](evidence/combat-damage.md).
- Shared native-traced AC, nominal melee/offhand/ranged bonuses and final save modifiers now include mapped equipped properties and positive stat effect application/removal/expiry. 159 tests and bundled character/startup checks pass; 39/39 AC and 38/39 final save BIC snapshots match under two module rule chains. Opponent-specific modifiers, immunity-aware decreases, actual equipment mutation, melee resolution and native/server differential checks remain open. See [Final modifier evidence](evidence/combat-final-modifiers.md).
- Persistent runtime diagnostics now retain unsupported/failed engine calls, resource attempts and scene/UI/audio omissions across area/module changes. Electron writes ignored per-run JSONL files; Tools provides status/export/retry and browsers retain/export saved sessions through IndexedDB. 130 tests and native/browser renderer checks pass. See [Diagnostic evidence and limits](evidence/runtime-diagnostics.md). Resume the shared class/feat/skill/stat validation milestone next.
- Static MOD/ARE/GIT loading, KEY/BIF/ERF/HAK resource resolution, ASCII and supported binary MDL rendering, TGA/DDS/PLT textures, lighting approximations, and static creature assemblies are implemented.
- The viewer selects `Mod_Entry_Area`, parses WOK walkability, loads a BIC player model (or a preview capsule), and constrains basic movement to walkable faces.
- Available placeable PWK and state-selected DWK meshes block capsule movement. Expanded exporter-header support brings the Witch's Wake entry area to 1,223 walkable faces and 82 object-collision faces.
- Visible door clicks, E and the movement HUD enter a shared use-action queue. The actor approaches DWK use points before changing state; locks are rechecked on arrival, opening side follows actor position, and authored transitions drive appearance/collision. Doors rest until used. State persists across development area switches.
- Right-click world radial menus share eight-slot modal input, lazy submenus, installed icons, state-based disabling and explicit placeholders. Door Open/Close uses the action queue, including linked-door Close; creature/placeable/player/ground menus are available, with item/associate providers awaiting their systems. See [Radial evidence](evidence/radial-menu.md).
- A shared binary/ASCII controller runtime supports transform/opacity playback and supermodel inheritance across tiles, placeables, doors, creatures, attachments, and standalone models. Idle/default clips and diagnostic clip previews are available; mapped skin geometry follows bone updates.
- Shared native-style numeric object identities/tags, render picking, cancellable approach/use/settle actions, local routing, an NCS VM, deferred events and real linked-door traversal are implemented. BIC character/owned-item state, journal and positive script XP awards are connected to the UI. The area dropdown and opt-in animation tools remain development affordances. Broader AI, gameplay animation selection, interactions, saves, audio and networking remain open.
- Existing code and research state: [README](README.md), [Research Tracker](RESEARCH_TRACKER.md), [First object-render milestone](evidence/first-object-render.md), [Rendering pipeline evidence](evidence/rendering-pipeline.md).
- NPC click/radial Talk and placeable OnUsed execute authored DLG branches, conditions/actions/endings, once-only XP and quest states. Movement-trigger enter/exit, native nearest-creature filtering and cutscene/input state are connected. All 66 local DLG resources validate; Angmar and TearsMessage pass pointer/keyboard UI checks. See [Dialogue and trigger evidence](evidence/conversations-triggers.md).

## Roadmap

### 0. Reproducible compatibility baseline

**Status: Mostly established.**

- Keep a small test corpus: Witch's Wake start, one interior, one transition, one module with HAKs, and one CEP module.
- Record expected resource resolution, entry area, starting position, creatures, doors, walkable surfaces, and known unsupported features for each.
- Add automated parser fixtures and headless resource smoke tests; preserve screenshots for visual regressions.
- **2026-10-12:** implemented the full occurrence journal and persistent diagnostic sinks. Missing lookup probes remain distinct from final omissions; aborted scripts still report their real failure location. See [Runtime diagnostics](evidence/runtime-diagnostics.md).
- Keep evidence, inference, and unknowns distinct. Use Ghidra when behavior or a binary contract is target-specific and not established by formats or validated reference code.

**Exit gate:** a clean checkout can build, run the test suite, and load each local test module reproducibly.

### 1. Reliable local movement and area traversal

**Traversal gate remains open. Core object/action/script systems now take priority.**

**2026-10-11 progress:** separated closed/open1/open2 DWK collision using target-binary evidence, added local door interaction, swept object collision and continuous floor-support checks, safer spawn checks, focus handling, parser regression tests, and local-resource/hidden-renderer smoke tools. Witch's Wake entry, Angmar's House, and Brogan's Arm pass resource/movement checks; nine unlocked door instances pass closed/open/closed collision checks. See [Movement and door evidence](evidence/local-movement-doors.md). This does not yet satisfy the traversal exit gate.

- Finish walkmesh edge cases: stacked floors, slopes/steps, narrow passages, tile seams, rotated tiles, partial PWK/DWK availability, and movement tunneling.
- Add interaction targeting and door state changes; select the correct DWK state, animate or otherwise represent open/closed state, and prevent false blocking from alternate door poses.
- Replace the development area dropdown with module-driven transitions through doors, triggers, and scripted area changes.
- Add robust spawn placement, facing, camera modes, pause/focus handling, and keyboard/mouse controls; retain collision diagnostics for test builds.
- Extend collision to relevant creatures and dynamic blockers, and validate against in-game movement rather than only synthetic geometry.

**Exit gate:** a player can enter the module, traverse a representative route, open a door, transition areas, and cannot pass through walls or closed blocking objects.

### 2. Actor and object simulation

**2026-10-11 foundation:** shared controller playback, inherited clips, mapped skin updates, attachment movement, idle/default selection, and authored door transitions are implemented. Nine real model samples pass all-clip resource checks; the Electron viewer checks playback/pause across tile, door, placeable, and creature categories in Brogan's Arm. Blending, event dispatch, animated-mesh/dangly channels, full controller coverage, exceptional skin variants, and gameplay actor state selection remain open. See [Animation evidence](evidence/model-animation.md). This does not satisfy the phase exit gate.

- Evaluate MDL animation controllers and supermodel inheritance; animate skeletal creatures, equipment, doors, and simple placeables.
- Replace the capsule-only controller with a selectable player creature, authored appearance/equipment, facing, idle/walk/run transitions, and movement feedback.
- Implement area object lifecycles for creatures, placeables, doors, triggers, waypoints, encounters, and transitions; resolve object tags and linked objects.
- Add path planning and movement requests where the game expects click-to-move or scripted movement, rather than treating WASD displacement as the final control model.

**Exit gate:** representative actors animate and change state from gameplay events; object placement, collision, and facing remain coherent through transitions.

### 3. Interactions and core game loop

**Current priority: gameplay foundations.** Door behavior is the first vertical slice of shared object/action/event systems. [Door click evidence](evidence/door-click-gameplay.md) traces native input through queued use, range checks and state events. Object picking, approach planning, cancellation and door state events are implemented. A first bytecode VM now executes shipped door transition scripts through the shared event scheduler, with persistent native-style uint32 object IDs. Broader interactions and the phase exit gate remain open.

- Select/inspect objects and execute context-sensitive actions: talk, use, open, attack, loot, and examine.
- Populate the shared radial providers from real character, inventory, faction and skill rules; replace placeholder requests with validated simulation actions incrementally. Preserve native default-use versus explicit radial action behavior.
- Implement conversation loading and branching, journal/quest updates, party/faction state, and common encounter triggers.
- Implement combat/action queues, round timing, attacks, damage, effects, saving throws, spells, feats, and inventory/equipment rules incrementally.
- **2026-10-12 combat requirement:** nearly identical behavior alongside original clients, demonstrated through native evidence and side-by-side differential scenarios. Validate modifiers, RNG consumption, action/round/event ordering, consequences and presentation for each claimed slice. Keep network requests/presentation separate from authoritative server resolution. Placeholders and approximate combat cannot pass the gate. See [Combat compatibility contract](evidence/combat-compatibility-contract.md).
- Build essential UI workflows: character selection/creation as required by the target module, HUD, action feedback, conversation, inventory, journal, map, pause, and settings.

**2026-10-11 UI checkpoint:** shared native GUI/MDL/texture/font presentation, gameplay HUD/quickbar/message log, working journal text/completion and session notes, examination, and principal gameplay/front-end panel shells. All 104 installed GUI layouts are available through the resource catalog; missing engine-backed actions produce structured placeholders. Character creation, inventory rules, dialogue, native automap/pause, saves and networking remain open. See [UI evidence and validation](evidence/game-ui.md).

**2026-10-11 player checkpoint:** BIC player import, canonical owned/equipped item IDs, portrait/body/chest armor assembly, racial/class/equipped-ability state, mapped PC HP and positive XP awards. Character, skills, feats, equipment and spellbook read real imported data. Brogan's native compiled script awards 100 XP once and the clicked-door round trip preserves actor/owned-item state. All 39 installed BICs parse; one archived Pale Master HP discrepancy needs native runtime comparison. General effects/item rules, leveling/creation, gameplay movement animations and full equipment visuals remain open. See [Character evidence and validation](evidence/player-character.md).

**2026-10-11 conversation checkpoint:** native-checked dialogue order/participant IDs, stale-reply rejection, journal progression, once-only XP, click/radial Talk, placeable use points/range, movement triggers and cutscene plot/input state. 103 tests pass. Full-module UI checks verify Angmar's 15 XP once and TearsMessage's 50 XP / quest state 20. Startup/audio/effects, automatic camera obstruction, dialogue timing and broader AI remain open; test fixtures explicitly bypass initial startup. See [Evidence and limits](evidence/conversations-triggers.md).

**Exit gate:** complete a representative scripted encounter and conversation with visible, persistent consequences, not just a walkable scene.

### 4. NWScript and module behavior

**Largest single-player risk.**

**2026-10-11 execution checkpoint:** native-style object array allocation/insertion/lookup/deletion and internal/external namespaces; persistent module-wide records including inventory/equipment IDs; typed variable tables; NCS decoder/core VM; deferred script situations; linked-door mirroring and real Angmar/Brogan round-trip traversal. Witch's Wake client entry adds its 11 journal entries once, and the real transition script rejects possessed familiars. All 866 module/HAK NCS resources decode; 3,362 objects across 29 IFO-listed areas are indexed. Full startup remains blocked by character/XP, audio, cutscene and other unsupported engine calls, which produce explicit script/PC diagnostics. See [Evidence, tests and limits](evidence/script-object-runtime.md). This does not satisfy the phase exit gate.

- Implement an NWScript bytecode VM with stack/frame semantics, instruction behavior, errors, and event scheduling.
- Add engine calls in measured groups: object lookup, events, actions, inventory, dialogue, combat, effects, area transitions, and persistence.
- Validate each group against shipped scripts and target behavior. Do not treat xoreos or another implementation as proof of exact NWN:EE behavior without checking differences.
- Implement module/area/creature/placeable/door event ordering, timers, delayed commands, and script-driven state changes.

**Exit gate:** the target campaign's startup scripts and representative module scripts run without hand-coded per-module substitutions.

### 5. Resources, saves, audio, and presentation

- Complete format and lifecycle coverage needed by the corpus: remaining MDL mesh types/controllers, TXI/material parameters, fonts, portraits, GUI resources, and sound/music formats.
- Add audio playback, spatial/ambient audio, music changes, lip sync where practical, and sound cues for actions.
- Implement save/load for player and module state, versioned settings, recovery from corrupt/unsupported records, and deterministic resume tests.
- Replace approximation-only lighting, shadows, environment maps, transparency, and particle behavior where the compatibility corpus demonstrates a meaningful mismatch.
- Provide clear diagnostics for missing resources/scripts and preserve user-installed modules and HAK precedence.

**Exit gate:** the campaign can be saved, closed, resumed, and completed with required resources and feedback intact.

### 6. Single-player replacement candidate

- Remove development-only controls from the player workflow; keep them behind a developer mode.
- Add module selection, install/data discovery, content validation, settings, accessibility, input remapping, logs, and graceful unsupported-content reporting.
- Run a compatibility matrix over the chosen base campaigns and selected user modules; fix blockers in startup, traversal, combat, conversations, saves, and UI.
- Profile large areas and long sessions; test memory/resource disposal, alt-tab, resize, controller focus, and common display configurations.

**Candidate gate:** a user with a legitimate NWN:EE installation can launch and finish the agreed single-player corpus without starting the original client, with no progression-blocking defects and documented remaining differences.

### 7. NWN:EE multiplayer client compatibility

**Required interoperability gate.** Transport/session implementation remains a separate milestone; native IDs, server authority, action requests and reconciliation must shape earlier architecture. The replacement is intended to coexist with original clients, not merely reproduce a local encounter.

- Reconcile existing protocol research in `../FullDecomp`; map handshake, authentication, version negotiation, message framing, compression/encryption, and disconnect/error behavior.
- Implement protocol and session state, then server-authoritative area/object replication, player actions, chat, party state, inventory updates, and area transitions.
- Validate against an authorized local NWN:EE server across reconnects, latency/loss, version mismatch, and multiple clients. Keep server simulation authoritative; do not silently substitute local state.
- Treat anti-cheat, account services, persistence ownership, and server extensions as explicit compatibility questions.

**Candidate gate:** connect to an unmodified target server alongside an original client, pass the documented combat/state compatibility matrix with no unexplained divergence, and recover cleanly from reconnect and version/error cases. Compare both participants' authoritative outcomes, identities, event attribution and presentation; a successful connection alone is insufficient.

## Recommended next milestone

2026-10-13: Interactive combat session configuration now supplies selectable local PvP and keeps native AI/perception active when opening scripts are skipped. Failed individual perception queries are recorded without freezing other queries or action clocks; this is a replacement recovery policy, not native indoor-sound parity. Repeated HUD errors notify once per area while retaining every diagnostic occurrence. An installed Prelude/fighter input trace starts a real round and changes the authored goblin's HP17→−11 without creature overrides; the user observed rolls/damage. **966 tests, build and eight original perception observations pass; combat is not ready.** NPC scripts, indoor sound, presentation and the existing ranged/death/equipment/full-fight gates remain. See [UI session evidence](evidence/combat-ui-session.md). Checkpoint: `backups/combat-ui-session-966-checkpoint-20261013-v2.zip` (active launcher stdout/stderr excluded).

2026-10-13: Native ranged ammunition availability/release/consumption, separate post-hit owner, projectile timing/reactions, miss trajectories, called-shot coordination and event21 recipient delivery are connected. Active2DA data supplies limb, damage-projectile, weight and encumbrance rules. Three replacement fixture strikes consume100→97 arrows and damage20→14HP without engine failures. **963 tests, production build,45 original combat observations, eight perception events and three death/XP observations pass; combat is not ready.** Complete event11 destruction/unequipping and auto-equip side effects, status/on-hit/death owners, remaining frame/faction/movement/presentation and full independent native encounter comparison before the combat gate; casting follows. See [ranged evidence and limits](evidence/combat-native-ranged.md). Checkpoint: `backups/combat-native-ranged-963-checkpoint-20261013.zip`. This supersedes the916 checkpoint below.

Verification for the following death/movement checkpoint: **916 tests, production build,45 original combat observations, eight perception events and the three scripted death/XP observations pass.** Saved source/evidence: `backups/combat-native-death-movement-916-checkpoint-20261013.zip`. Ranged owners are next.

2026-10-13: Independent original scripted death/XP comparison now matches before/OnDeath/after observations, including HP−80 and50XP. It exposed and corrected NWScript GetIsPC to query attached client ownership independently of stats PC flags. Death magic-immunity/bypass/feedback and active visualeffects.2da purge rules are connected. Native safe-direction fallback and blocked movement event31/GetBlockingDoor are connected; both clear and overlapping loaded-fighter approaches complete kills and1806XP awards without engine failures. Full encounter/RNG/network validation, faction/PVP/associates/history, corpse/encounter, status/on-hit/ranged/traps and animation/UI remain open. **Combat is not ready.** See [XP evidence](evidence/combat-native-death-experience.md) and [movement evidence](evidence/combat-native-bump-friends.md). This supersedes the901 checkpoint below.

2026-10-13: Native faction owners now retain ordered canonical member IDs, append-index allocation and deleted slots; normal creature loading and combat broadcasts use these lists. Ordinary creature death clears shared actions, adjusts witnesses, assigns killer/runs OnDeath/applies native XP, clears the same status WORD used by movement/perception, and retains the corpse ID. Native AddExperience/SetExperience award/feedback coordinators are connected; native level-history side effects and full death/corpse owners remain incomplete. Actual loaded fighter input approaches, kills HP20→−11 and receives1806 XP with no engine errors in an explicit authored fixture. Direct BumpFriends displacement and fallback ordering are mapped; safe-direction search/event31 remain open. **901 tests, production build,45 earlier original combat observations and eight perception events pass; combat is not ready.** Continue independent original death/XP encounter comparison, remaining faction/PVP/associate/history, death/corpse/encounter, movement fallback, status/on-hit/ranged/traps and animation/UI owners before combat readiness; casting follows. See [faction evidence](evidence/combat-native-factions.md), [XP evidence](evidence/combat-native-death-experience.md) and [friend displacement](evidence/combat-native-bump-friends.md). Checkpoint: `backups/combat-native-faction-death-901-checkpoint-20261013.zip`. This supersedes the881 checkpoint below.

2026-10-13: Native creature frame timing/active timer selection, decoded normal Attack input, radial target Attack, canonical creature render positions and Cleave/Circle Kick insertion are connected. Death XP calculation/recipient coordinator follows active physical XPTable data but is **not yet bound to native faction storage/death awards**. **881 tests, production build, eight-event original perception comparison and45 earlier original combat observations pass; combat is not ready.** Native-style ordinary NPC melee and decoded-input fixtures repeat attacks/delayed damage without errors; immortal targets and omitted scripts do not validate a complete fight. Continue full death/faction/XP/corpse ownership, status/on-hit/ranged/traps, remaining movement, native clip/presentation and complete original encounter comparisons before the combat gate. See [frame/input evidence](evidence/combat-native-frame-input.md) and [death XP evidence](evidence/combat-native-death-experience.md). Source/evidence checkpoint: `backups/combat-native-player-frame-xp-881-checkpoint-20261013.zip`. This supersedes the849 checkpoint below.

2026-10-13: Native module/area AI rotation, calendar/day/night transitions, heartbeat scripts and shared weather RNG are connected after the AI master traversal. **849 tests, production build and the eight-event original-server perception comparison pass; combat is not ready.** GetTimeHour/Minute/Second now read the same world clock. Continue native creature active-timer/frame ownership, remaining movement/sound, trap/encounter/effect/status/death/ranged owners, combat input/presentation and full original encounter comparisons before the combat gate; casting follows. See [module clock evidence](evidence/combat-native-module-clock.md). Source/evidence checkpoint: `backups/combat-native-module-ai-849-checkpoint-20261013.zip`. This supersedes the837 checkpoint below.

2026-10-13: Native Spot/Listen/stealth, visibility gain/loss, ScriptOnNotice, constructor RNG order, spawn/heartbeat, AI level storage/script locking and AI master event traversal are connected. **837 tests, production build and an eight-event original-server perception comparison pass; combat is not ready.** The live AI loop reproduces those same flags/events with target movement replayed manually. Complete native tile/indoor sound/safe-location/friend displacement, effect/status/death/ranged owners, area/module clock/trap/encounter updates, combat input/presentation and full original encounter comparisons before the combat gate; casting follows. See [perception evidence](evidence/combat-native-perception.md) and [AI evidence](evidence/combat-native-ai.md). Source/evidence checkpoint: `backups/combat-native-perception-ai-837-checkpoint-20261013.zip`. This supersedes the785 checkpoint below.

2026-10-13: Native blocked-path selection, grid search, route smoothing, creature bumpability, personal-space initialization and movement/approach cancellation are connected to canonical local state. **785 tests, production build and 50,003 independent grid-math instruction comparisons pass; combat is not ready.** A live action-queue fixture now routes around a blocking creature on real tiles. Native tile search, safe-location/friend displacement, perception/frame ownership, encounter activation, presentation and full native encounter comparison remain. Continue these dependencies and the remaining combat owners before casting. See [grid-search evidence](evidence/combat-native-grid.md). Source/evidence checkpoint: `backups/combat-native-grid-checkpoint-20261013.zip`. This supersedes the759 checkpoint below.

2026-10-13: Native approach/retarget/use-range owners, retry/wait actions, active CreatureSpeed rates, tile height, direct path plotting, waypoint walking and action1 are now connected to canonical local state. **759 tests and build pass; combat is not ready.** Actual blocked/interarea/safe-location searches, friend/door movement event owners, native perception/frame ownership, encounter activation, presentation and complete encounter comparison remain. See [approach/direct movement evidence](evidence/combat-native-approach.md). Continue those owners and the remaining combat branches; casting follows. Source checkpoint: `backups/combat-native-live-path-checkpoint-20261013.zip`. This supersedes the695 status below.

2026-10-13: Native combat steps now use real direct-line collision, persistent canonical uint32 spatial arrays, subarea membership/event10 dispatch and finite embedded-CRT orbital math. **695 tests and build pass; combat is not ready.** Native approach/pathfinding, perception, encounter/trap/AOE activation, presentation and independent encounter comparison remain. See [movement evidence](evidence/combat-native-movement.md). Next implement the native group-preserving approach action sequence and actual movement/check owners. Source/evidence backup: `backups/combat-native-movement-checkpoint-20261013.zip`. This supersedes the671 checkpoint below.

2026-10-13: Native ordinary tile/area LOS now drives default attack eligibility from active authored WOK AABB trees, surfacemat LineOfSight values and canonical door/placeable collision storage. **671 tests and build pass. Combat is not ready:** spatial lifecycle, approach/perception, orbital math, presentation and full native encounter differential validation remain. See [native LOS evidence](evidence/combat-native-los.md). Resource queries cover303 Prelude and1195 Witch's Wake tiles without failures; these are integration checks, not encounter parity. Next trace native position/subarea updates and actual approach/pathfinding. Source/evidence checkpoint `backups/combat-native-los-checkpoint-20261013.zip` supersedes652 below.

**2026-10-13 object collision checkpoint:**652 tests and the build pass. Initial area collision now uses native parallel arrays with canonical object IDs, capacity/hole/compaction rules, physical active placeables/door 2DA selection, original PWK/DWK transforms and detailed polygon/transparent-door queries. Installed Prelude/Witch's Wake collision stores contain143/630 placeables and38/89 doors; known missing PWKs follow the traced empty-mesh failure path while retaining diagnostics. Dynamic geometry mutations and ambiguous native scratch results fail explicitly. **Combat remains unfinished:** native tile AABB/area LOS, subarea/position lifecycle, approach/perception, orbital math, Attack input/presentation, remaining combat branches and ranged require completion and full encounter comparison. See [current object geometry evidence](evidence/combat-object-geometry.md); this supersedes statuses below.

**2026-10-13 native geometry checkpoint:**621 tests and the build pass. Canonical areas now retain signed native tile placements and lazily resolve active SET/WOK/surfacemat data. Native vertex snapping/deduplication, face classification, adjacency, clipping, triangle-height traversal, quarter turns, denied-tile polygons and creature-line eligibility are ported. All303 Prelude and1195 Witch's Wake tiles load through the same resource chain. A stationary world-frame melee fixture reaches delayed damage and another round with explicit LOS/stationary flags. **Combat remains unfinished:** detailed door/placeable collision/LOS, orbital math, subarea updates, approach/perception, Attack UI/presentation, special/status/on-hit/death and ranged need completion and full native encounter comparison. Native scratch-state/CRT-dispatch ambiguities are diagnosed instead of guessed. See [current native geometry evidence](evidence/combat-native-geometry.md); this supersedes implementation statuses below.

**2026-10-12 live action/clock/mode checkpoint:** shared object actions now drive the mapped attack owner during world updates. Native hostility/witness changes, module world-clock arithmetic, ordinary mode switching, target cleanup, round startup, strike dispatch and delayed damage are connected. Startup now preserves the native extra 500ms combat-step decrements and invalid-mode current-round attack bonus. **565 tests and the build pass**; installed Prelude/Witch's Wake action fixtures and the existing independent server capture comparison pass. **Combat is not ready:** Attack input/presentation, dynamic perception, native LOS/approach/pathfinding/combat-step movement, replacement target search, special/status/on-hit/death branches and ranged remain unfinished. Next finish geometry/movement and full encounter comparisons, then remaining combat branches; casting follows. See [current action-loop evidence](evidence/combat-action-loop.md). This supersedes the older checkpoint implementation statuses below.

**2026-10-12 strike/save/skill/oracle checkpoint:** native-traced roll, preparation, precision, defensive and damage/post-damage stages now have partial shared runtime adapters; saving throws preserve native bonus caps, immunity timing, rerolls and feedback ownership. Effective skill arithmetic, use gates and live skill effects follow active tables and native source stacking. All **443 tests** and the build pass. An authored fixture run by the unmodified native server independently agrees on three stat baselines, IsImmortal damage/history, three poison-immune saves, bare Parry/Spellcraft and stacked Parry buff/debuff results. Its logs are bound to the fixture hash. **Combat is still not playable end to end**, and Attack remains a placeholder. Complete the remaining live action/approach/perception, modifier/AC/parry/skill, spell/feat-use, on-hit/death, event-delivery and presentation providers; connect the complete round loop and compare full encounters. Casting remains unimplemented. See [Strike/save/native-oracle evidence](evidence/combat-strike-saves-oracle.md). This supersedes the checkpoint below.

**2026-10-12 reputation/lifecycle checkpoint:** shared creature reputation and persistent attack storage now support native-traced target changes, attack cancellation, group sequencing, defender timing and delayed damage events. All 358 tests and the build pass, with installed module checks and bundled character rendering. **Combat remains incomplete:** complete dynamic perception/client ownership, native geometry/approach, attack preparation/default strike/post-hit providers and all live combat event handlers; then drain the shared action queue into actual round/strike/presentation work. Finish special/defensive/death/AI/status/shield/concentration branches and compare full encounters against the original game. Casting follows combat and is not implemented. Original-server coexistence remains a separate required gate. See [Reputation/lifecycle evidence](evidence/combat-reputation-lifecycle.md), [Object-action evidence](evidence/combat-object-actions.md), [Timing/action evidence](evidence/combat-scheduler.md), [Damage effects](evidence/combat-damage-bonuses.md), [Live runtime evidence](evidence/combat-damage-runtime.md) and [Resolution evidence](evidence/combat-resolution.md). This supersedes the next-work recommendations below.

**2026-10-12 final modifier checkpoint:** script-visible AC, nominal melee/offhand/ranged bonuses, final saves and positive stat effects now refresh shared canonical state through XP changes, area entry and effect lifecycle. Character UI and authored startup checks pass with 159 tests. All 39 AC snapshots match; 38 final-save snapshots match under both Prelude and Witch's Wake. The Weapon Master discrepancy remains recorded, with no character/campaign exception. Next: opponent-specific AC/attack, immunity-aware decreases and temporary ability effects, actual equipment mutation and an independent native modifier oracle; then a narrow melee round with RNG/event comparisons. See [Final modifier evidence](evidence/combat-final-modifiers.md). This supersedes the next-work recommendation in the historical base checkpoint below.

**2026-10-12 base combat checkpoint:** shared native-traced class/epic base attack and base save providers, feat/ruleset bonuses, uint64 ruleset hashing and native ability-modifier arithmetic now recompute from live character state. `GetBaseAttackBonus` and clearly labeled base values in the character panel are connected. 141 tests pass; all 39 BICs load under Prelude and Witch's Wake, all 17 available base-attack snapshots match, and native startup rollback changes BAB 7→0 with base saves 5/5/9→0/0/2. Eight partial save snapshot discrepancies remain recorded. Next: effective armor class, final attack/save modifiers and equipment/effect lifecycle, then a narrowly scoped melee round with an independent native oracle. Combat resolution and multiplayer parity are not established. See [Base combat provider evidence](evidence/combat-stat-providers.md).

**2026-10-12 character rules checkpoint:** native-mapped PC XP reduction and stored future-history replay now reconcile class slots, abilities, feats, skills, HP and spells on shared live state, retaining canonical IDs and immutable imported data. Class table references and equipped bonus-spell-slot counters are loaded through general rules/providers. 121 tests pass; all 17 installed high-level BICs pass loss/replay checks under Witch's Wake and Prelude resource chains. Startup-enabled UI observes level 1 / 5 HP; CopyObject and EffectDamage still block the opening. See [Character progression and broader rules map](evidence/character-progression.md).

**Priority after the user's rules/combat clarification:** shared runtime class/race/feat/skill/stat, attack/AC/save, equipment/effect providers and canonical object/item lifecycle come first, followed by a narrowly scoped, native-verified melee loop. Build class availability/alignment/prestige prerequisites, feat grants/selection prerequisites and skill purchase validation before enabling manual character creation and level-up UI; the entire selection UI need not block basic combat. Keep trusted stored-history replay separate from new-choice validation. Implement native mutation side effects and continue startup without campaign-specific substitutions. Apply the [Combat compatibility contract](evidence/combat-compatibility-contract.md) throughout; multiplayer coexistence is required.

**2026-10-11 startup checkpoint:** mapped Heal/CutsceneGhost records, separate uint64 effect handles, enumeration/removal/expiry, direct SetXP within the current level, and queued script sound routing with in-memory IMA decoding/output. 113 tests pass; real reward sound plays in the full-module UI check. Startup-enabled testing now reaches clone creation and native level rollback; it does not complete the opening. See [Startup effects/audio evidence](evidence/startup-effects-audio.md).

Continue **core gameplay systems** through the shared rules work above and canonical clone/item creation/destruction, then advance the actual opening script without a bypass. Its authored setup resets the PC to level 1 and replaces equipment; the XP/history slice now handles the reset, while object/equipment replacement remains open. Add damage and gold/equip rules, cutscene visuals/fades/camera and dynamic conversation objects in measured groups. Native cutscene abort, journal timestamps/party propagation, perception updates, camera obstruction, trigger/area-transfer ordering and the remaining HP discrepancy also remain open. Keep native object IDs canonical, including future authoritative external objects. Combat and multiplayer remain later gates.

## Risks and boundaries

- NWScript API breadth, exact event ordering, and target-specific behavior are likely to dominate single-player compatibility.
- NWN:EE networking is an independent protocol and authority problem; a working local client does not imply server compatibility.
- Visual completeness is cheaper than behavioral completeness; prioritize progression blockers and representative workflows.
- Use locally installed assets only. Do not copy game binaries/assets into this workspace or patch/inject/alter the running game.
- Ghidra remains valuable for unresolved target-specific behavior. The current WOK/PWK/DWK slices were readable text resources, so they did not require binary modification or speculative Ghidra edits.
