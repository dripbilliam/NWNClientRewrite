# NWN Replacement Client Roadmap

This roadmap tracks a plausible replacement for the NWN: Enhanced Edition client. It does not assume that matching rendered screenshots is sufficient: the client must load modules, simulate the relevant world state, execute gameplay rules, present usable UI, and preserve progress.

## Target and completion tiers

Keep the current compatibility target fixed at NWN:EE `89.8193.37-17` unless a later decision expands it. The game install remains read-only; user-authorized Ghidra annotations require periodic backups. The replacement loads user-provided game data and does not ship BioWare assets.

There are two distinct goals:

- **Single-player replacement:** start and complete representative local modules without launching the original client. This is the first credible target.
- **Server-compatible client:** connect to an unmodified NWN:EE server and participate alongside original clients in authoritative multiplayer sessions. This is a required acceptance gate, separately validated from local play; it does not require replacing the server. Server authority and native identities constrain earlier implementation work.

A replacement server, toolset, and broad compatibility with community modules are explicitly beyond the initial target.

## Current checkpoint

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

2026-10-13: Native blocked-path selection, grid search, route smoothing, creature bumpability, personal-space initialization and movement/approach cancellation are connected to canonical local state. **785 tests, production build and50,003 independent grid-math instruction comparisons pass; combat is not ready.** A live action-queue fixture now routes around a blocking creature on real tiles. Native tile search, safe-location/friend displacement, perception/frame ownership, encounter activation, presentation and full native encounter comparison remain. Continue these dependencies and the remaining combat owners before casting. See [grid-search evidence](evidence/combat-native-grid.md). Source/evidence checkpoint: `backups/combat-native-grid-checkpoint-20261013.zip`. This supersedes the759 checkpoint below.

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
