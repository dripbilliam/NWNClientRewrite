# Object actions and attack eligibility — 2026-10-12

Updated live dispatch, target cleanup, startup and mode status: [Combat action-loop checkpoint](combat-action-loop.md). Older test counts and unavailable-provider statements below are historical. Self-target eligibility calls SetAnimation(0), not combat-state cleanup.

Creature/player sessions now own a shared native-traced object action list,
AI action summary and cached visibility list. Attack requests can populate that
list through explicit providers; eligibility evaluates life, cached perception,
LOS, reach and full 3D range through explicit geometry providers. These extend
the [timing checkpoint](combat-scheduler.md).

**Ordinary attacks are still not playable; casting is unimplemented.** Native
perception updates, cancellation side effects, live geometry/approach and strike
dispatch remain dependencies. World updates do not automatically drain this
new queue. Existing script/UI movement and use actions retain their local queue.
Passing replacement tests does not establish native/server encounter parity.

Target: NWN:EE `89.8193.37-17`, x64 `nwmain.exe`, SHA256
`3B7CB1252E0EDB2CE22D7971F333AADE027039AE30A45B4BC64732C3E6BEC73A`.
The installed binary/assets and original Ghidra project remain unchanged.

## Controlling evidence

Hash-checked disassembly under `backups/animations/`:
`perception-queue-full-asm.txt`, `perception-primitives-full-asm.txt`,
`perception-initialization-full-asm.txt`, `perception-attack-gates-full-asm.txt`
and `perception-ranged-list-full-asm.txt`. Earlier scheduler exports supply
request callers, AIUpdate ordering and active base-item loading.

Saved-copy, read-only headless analysis produced complete exports for
`1404ac010`, `140490b80`, `14048d2c0`, `1403d3760` and `14048b760`:
`resolution-<address>-copy-decompile.txt`. The three controlling logs are
`headless-perception-actions-copy.txt`, `headless-perception-parameters-copy.txt`
and `headless-perception-constructor-copy.txt`; all discard project changes.
RunActions ends at RET `0x1404ad2c8`; subsequent jump-table bytes are data.
Explicit leaf ranges cover functions absent from the PE unwind table.
Initial truncated/failed exploratory exports are superseded by these files.
Disassembly controls widths, constants, boundaries and call arguments when
Ghidra's inferred types or returning cleanup thunks obscure the result.

| Native function / call site | Implemented behavior and limits |
| --- | --- |
| CNWSObject constructor `0x14048b760`, list allocation/store `0x14048b80e`; action-node constructor `0x14048bcf0` | Separately allocated linked-list cells and action records. Twelve type/data slots, group ushort at node +98, count ushort +9A, field +9C initialized to 1. Local records preserve identity; they are not native memory or wire packets. Sessions currently attach this state to creatures/players. |
| AddAction `0x14048cb80`; AddActionToFront `0x14048d3f0`; allocation branch `0x14048cc17..0x14048cc57` | New group sentinel 65535; reuse sentinel 65534; generated counter skips 65535 on wrap; explicit groups leave last-generated group unchanged. Parameter collection stops at the first zero type; front/tail insertion preserves record order. |
| AddActionNodeParameter `0x14048d2c0`, caller `0x14048cc7c`; destructor `0x14048c470` | Types 1/2/3 retain signed raw int32 bits; typed float/object reads decode them. Type 6 narrows to byte, type 4 copies bytes, type 5 retains owned situation identity and requires disposal. Count updates before the index>=12 rejection. Malformed counts fail before dispatch/removal instead of simulating native out-of-bounds memory behavior. |
| ComputeAIState `0x140387dc0`, calls `0x140387e13/0x140387e56`; ComputeAIStateOnAction `0x140387e70` | Reset +8D6/+8D8, walk queued records before the currently executing action. First priority state wins; movement/attack summaries have their lower priorities. Queued attack target comes from raw parameter zero, executing target from +94. AI summary, animation state, creature status and script action state remain distinct. |
| ActionManager `0x14037cbc0`, ComputeAIState call `0x14037cbea`, clear calls `0x14037cc03/0x14037cc15` | Requires actual client lookup. Movement requests 1/2 clear only below summary 10; requests 4/8 always clear. This is a provider-level helper, not a PC-flag approximation of client ownership. |
| ClearAllActions `0x140490b80`; ClearAction creature `0x1403870b0`, base `0x14041e710` | Exact commandable==1; advance traversal before callback, recheck current-head identity, remove only exact-one cancellation successes, dispose and reset creature path. Creature-specific cancellation effects/packets/round cleanup remain required callbacks. |
| RunActions `0x1404ac010`; AIUpdate call `0x14037c6f7`, later ComputeAIState call `0x14037c752` | Lifecycle exposes executing record/+90 and attack +94, tracks start/last-run time, retains result 1 at the head ahead of newly prepended records, and disposes other integer results. Completed attack clears +724/+728 independently of +738. Strict uint64 elapsed >1000 microseconds and actions 1/5/48/51 stop the frame. Native per-action dispatch/type gates, last-action AI-master state and overflow policy are explicit callbacks. This is not a full RunActions port. |
| CNWSCreature constructor `0x14037a300`, stores `0x14037a8c3..0x14037a9ed`, `0x14037adf0..0x14037ae63` | Verified initial +8D4 byte 255, +771 status 0, +700 zero, +8D6/+8D8 summary zero/invalid, +90/+94 executing sentinels, and distinct +724/+728/+738 targets. These are constructor values, not substitutes for dynamic status/perception updates. |
| AddToVisibleList `0x1403d0db0`; GetVisibleListElement `0x1403d5850`, attack call `0x1403dd533`; RemoveFromVisibleList `0x1403d7390`; ClearVisibleList `0x1403d3760` | Ordered ID/flag records; first duplicate retained, capacity starts at 16 and doubles; reverse removal removes all matches, self removal warns; clear preserves the first self record with capacity 1. Seen/heard bits share GetObjectSeen/GetObjectHeard storage. Upper reserved bits are zero locally on creation, preserved on explicit updates; uninitialized native bytes are not reproduced. |
| GetAIStateReaction `0x1404ab6c0`; GetReputation `0x1404abcd0`; GetCreatureReputation `0x1403d4e20` | Threshold/PVP classification is translated for supplied reputation/same-faction inputs. Native target-owned reputation lookup, personal lists, master/associate/DM handling are researched but not ported. Static FAC values alone cannot stand in for this provider. |
| AIActionAttackObject `0x1403dcd50`, entry/gates `0x1403dd41f..0x1403dd8b8` | Sets unnamed +748 to 6000; checks actor death/dying and raw +8D4 mask 0x84, self-target, target life/dying-PC and cached visibility. Missing nodes reject ordinary PC/familiar creature targets; present state bits 0x0C==4 or 0x13==0x10 reject. Request-time visibility differs and does not require a node. These return decisions; ChangeAttackTarget, combat-state cleanup, round start and approach insertion remain external. |
| Attack range calls `0x1403dd5d9/0x1403dd5eb`; ClearLineOfSight call `0x1403dd79e`; melee virtual area query `0x1403dd814` | Active-rule maximum then desired reach; LOS endpoints raised by float32 1; sentinel point -10000000 uses the target's current position for LOS only. Melee creature query temporarily uses path +8=0.01/+28=target ID and restores both. Full 3D range uses float32 0.01 slack and area identity. Replacement coordinates map native vertical Z to render Y. The virtual area query's backend remains unimplemented; it is not the differently shaped TestDirectLine function. |
| GetRangeWeaponEquipped `0x140392f80`, attack call `0x1403dd737`; base-items RangedWeapon load `0x14029ec52`, byte store `0x14029ecab` | Right-hand slot 16 and base-item +18 byte use active RangedWeapon. This stays distinct from MaxAttackRange's AmmunitionType branch. |

`CombatRuntime` supplies verified identity, storage, life-state, initiative and
active-rule reach operations. Missing request/geometry operations report through
the persistent occurrence journal with canonical object/module/area context.
No campaign-specific branch, fake perception success or protocol was added.

## Validation

All **322 tests** and the production build pass. The 20 new tests cover linked
identity, group wrap/reuse, raw typed arguments, AI priorities, cancellation
refusal, executing state, pending reinsertion, strict frame budgets, visibility
flags and attack eligibility. Missing providers preserve queued work; melee
path overrides restore on failure. Live-session fixtures confirm real canonical
storage, existing initiative and RNG order, duplicate-request suppression,
shared script seen/heard queries and persistent failure context. The world
pump retains the new action record because dispatch is not yet connected.

`scripts/smoke-combat-actions.mjs` passes for **62 Prelude** and **229 Witch's
Wake** actors. It checks independent queues/caches, constructor state, IDs,
authored data, shared stats and HP; explicit placement/cache fixtures demonstrate
absent LOS and request providers being recorded without queued work or RNG use.
Startup is disabled. It neither simulates native perception nor resolves a
strike. Existing scheduler/range and authored script-damage checks pass under
both installed rule chains. Hidden bundled full-scene character verification
passes, including imported stats/equipment/spellbook. Prior preview-actor
startup/UI failure remains open and was not reclassified as passing.

Logs: `actions-all-tests.txt`, `actions-build.txt`,
`actions-{prelude,witch}-installed.txt`,
`actions-{prelude,witch}-{scheduler,damage}.txt` and
`actions-character-renderer{,-error}.txt`, under `backups/animations/`.
These are replacement integration checks and translated branch tests, not an
independent native encounter oracle.

Source was backed up before edits in `backups/combat-actions-before-20261012.zip`.
The final source/test/script/evidence archive is recorded in the roadmap.

## Next work

Map and implement dynamic perception/status updates and their authored events,
actual client/reputation ownership, action-specific cancellation and native
geometry/use-point/approach behavior. Then connect the shared action queue to
live AI ordering, target changes, round creation, strike records/HP consequences
and gameplay animation. The native action/effect overflow thresholds are
researched but not ported. Broader object action ownership, equipment mutation,
special/defensive attacks and complete death/AI/status behavior remain open.

Compare an ordinary encounter against the original game before accepting the
combat gate. Then implement casting slots/DC/metamagic, interruption, impact
scripts/effects and presentation through the same canonical state. Original
server coexistence remains a separate required validation gate.
