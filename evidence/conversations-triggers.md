# Dialogue and movement-trigger checkpoint

Target: NWN:EE **89.8193.37-17**, `../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`, SHA-256 `3B7CB1252E0EDB2CE22D7971F333AADE027039AE30A45B4BC64732C3E6BEC73A`.

## Observed native contracts

Validation: read-only Ghidra plus PE/Capstone disassembly using `scripts/inspect-gameplay.py`. Some unwind ranges split functions, and Ghidra truncates control flow at a misidentified cleanup helper; explicit bounded disassembly covers those continuations. Traces are in ignored `backups/animations/conversation-native-*.txt`. No binary/script assets were extracted or Ghidra annotations changed.

| Contract | Function / decisive call site |
| --- | --- |
| First active starting link wins; check speaker before condition | `GetStartEntry` `0x14041aca0`; condition `0x14041ad13` |
| Blank condition succeeds; compiled condition runs as dialogue owner and returns integer | `CheckScript` `0x14041a110`; VM `0x14041a20c`, result checks `0x14041a232–244` |
| Entry updates quest, runs action, then evaluates replies | `SendDialogEntry` `0x14041c9c0`; journal `0x14041cc0e`, action `0x14041ce50`, replies `0x14041ce62` |
| Reply uses link ordinal; reply action precedes ordered next-entry conditions | `HandleReply` `0x14041afe0`; action `0x14041b479`, condition `0x14041b4dc` |
| PC speaker belongs to SELF's live dialogue; invalid BeginConversation target falls back to SELF's last speaker | `GetPCSpeaker` `0x14052ed20`; `BeginConversation` `0x140511010`, fallback `0x1405110d0–e5` |
| Normal/aborted endings select different scripts | `RunEndConversationScript` `0x1404997e0` |
| Tagged speakers cache canonical nearest IDs within ten metres; reject dead/out-of-area/already-owned speakers | `GetSpeaker` `0x14041a7e0`; nearest-name `0x14041a90d`, range `0x14041ab41`, ownership `0x14041ab4e–bb7`; `GetNearestObjectByName` `0x1404958f0` |
| Nearest queries search X list outward; distance ties retain encounter order | `GetNearestObject` `0x14052c160`; reference search `0x14052c52d–571`, 3D float32 distance `0x14052cbc7–cbf4`, strict insertion compare `0x14052cc60` |
| Three creature criteria are ANDed; DM excluded; friend/enemy thresholds 90/10 | Criteria `0x14052c860–93a`, DM `0x14052c840`, reputation `0x14052c973–9dc` |
| Target quirks: race-ALL checks FIRST criterion value; dead-selection flag persists across candidates | `0x14052c8b5`; flag initialized `0x14052c1fc`, set `0x14052c9fe`, consulted `0x14052ca08/ca37` |
| PC/familiar dead at -10 HP; -9 through 0 dying; ordinary creatures dead at 0 | `GetDead` `0x1404953b0`; `GetIsPCDying` `0x140495620` |
| Seen/heard read visibility bits 0/1; noncreature observers return zero | `GetObjectVisibility` `0x14052e400` |
| Cutscene acts on PC/familiar, saves plot once, restores it on disable; retains raw mode and left-click allowance | `SetCutsceneMode` `0x140540750`; `StoreCutsceneVars` `0x1403a5280`, `RestoreCutsceneVars` `0x14039f740` |
| Trigger containment is XY polygon crossings, ignoring altitude/radius; GIT geometry adds position without rotating | `InTrigger` `0x1405019b0–1b50`; `LoadTrigger` `0x140502ac0–4290`, adds `0x140503e78–82` |

Talk range: `AIActionDialogObject` `0x14049f6b0` calls `GetIsInUseRange(target, 1.0, false)` at `0x14049fffe`. Its separate non-approach branch uses ten-metre 3D distance at `0x14049ffaa`; that is not the walking approach distance. `GetUseRange` `0x140396480` combines both CREPERSPACE values plus 0.3, or 0.8 if the target has a combat target. `GetIsInUseRange` `0x140391310` adds 1.0 + 0.1 tolerance, tests raised-endpoint line of sight and horizontal squared distance. `UpdatePersonalSpace` `0x1403a7c50` loads appearance.2da PERSPACE/CREPERSPACE into pathfinding +4/+8 (`0x1403a7d1e`, `0x1403a7e4a`). These replace the old fixed three-metre talk distance.

Placeable use: `AIActionUseObject` `0x1404a9790` passes 0.0 to that range function (`0x1404aa017`): actor PERSPACE + 0.5 + 0.1. PWK loader `0x1402ce0b0` accepts `*_pwk_use01/02` and `*_pwk_dp_use_01/02`. `GetNearestActionPoint` `0x1404b3f20` selects point two on equal 3D distance and falls back to origin without point one. PWK faces retain source ownership so use visibility can exclude the target's own collision; movement still collides with it.

`GetCurrentAction` `0x140521770` returns script action IDs or idle 65535. The shared queue publishes move=0, open=5, close=6, dialogue=7, use=15 on the canonical actor. Attempted attack/spell targets map +0x728/+0x73c (`0x14051f630`, `0x14051f680`); last attacker maps +0x194 (`0x140529e40`). These query stored state, not simulated combat.

## Implemented and verified

- DLG parsing/link validation, authored NCS conditions/actions/endings, canonical participant ownership, named-speaker caching, original reply ordinals, visible unsupported-condition errors, and stale/concurrent reply rejection. Quest state advances through `NW_JOURNAL_ENTRY<tag>` before the entry action; the journal/XP UI refreshes.
- Creature default click and radial Talk approach through the shared queue and invoke authored ScriptDialogue. Placeable use runs OnUsed with GetLastUsedBy; deferred ActionStartConversation reaches the same runtime. Movement-trigger membership handles overlapping polygons, exit and reentry with canonical actor context.
- Numbered replies capture keyboard input. Cutscene mode blocks movement/camera/right-click and ordinary GUI actions; allowed left clicks can drive the approach queue. Native cutscene-abort event dispatch remains open.
- **103 unit tests pass**: script order/SELF, ID zero, stale/concurrent replies, cleanup after end failure, monotonic quest state, named speaker caching, nearest ordering/filters/native quirks, plot restoration, use points, and concave/overlapping triggers.
- `smoke-conversations.mjs` validates all **66** installed module/HAK DLG resources in memory. Real Angmar ScriptDialogue opens `ww1_angmar`, exposing intelligence-filtered link ordinals 2/4/6/8. Asking about strangers runs `ww_xp_angempty`: **15 XP once**, entry 1; repeat gives **0**. TearsMessage OnUsed `ww_startconv` opens `ww1_tearsmessage`: elf reply runs `ww_xp_tearsmsg2`, awards **50 XP**, reaches entry 4 and quest `WW_TearsUntranslated` state **20**. Ending scripts including `nw_walk_wp` run. Actual FilchableOn/Off triggers **915/925** set/clear `bPCInFilchMaze`. PC **3361** and owned item IDs remain unchanged.
- Electron `--check-conversations --full-scene` passes actual picking/approach, radial Talk, mouse/keyboard replies, once-only XP, movement capture, clickable TearsMessage and readable journal text. It orbits around scenery without hiding walls or directly calling the conversation. `backups/animations/conversation-final*` contains screenshots/logs; the interactive run leaves Angmar's initial dialogue open in the full Brogan's Arm area.

## Open boundaries

This is a verified interaction slice, not complete startup or subsystem parity. Open work includes voice/audio, dialogue animations/delays/timeouts/one-liner completion, script parameters, private/spectator/hello behavior, pause/resume, journal date/time and party propagation. Native `AddJournalEntry` `0x140419e70` writes DATE/TIME before ENTRY (`0x140419fdb`, `0x140419fee`, `0x14041a000`); only state progression is currently implemented.

Autonomous perception/reactions, cutscene perception invalidation/abort/TURD behavior, effects/spell-use pools, NPC AI/action queues and exceptional object HP providers remain open. Empty perception maps can be queried but are not perception simulation. Nearest queries reconstruct the X list from area membership; full dynamic tie ordering needs a persistent native-style spatial list. Trigger exit/area-transfer event ordering needs more native validation. Local navigation and swept walkmesh support still approximate native pathfinding/raised-endpoint visibility.

Later checkpoint: Heal/CutsceneGhost effect records, direct SetXP within the current level and real queued reward audio are now implemented; see [Startup effects/audio](startup-effects-audio.md). Startup-enabled testing reaches CopyObject and SetXP level rollback. Filcher AI still reports EffectDamage. Automatic camera/roof obstruction handling is still open; orbit works and the test chooses a clear side. No unsupported engine call is reported as successful.

The Tools **Run startup and initial area-entry scripts (next load)** checkbox defaults on. Explicit `--play` / `--check-conversations` fixtures turn it off: omit module load/start/client-entry and the initial area's enter event, while subsequent area/object scripts and initial-area exit remain enabled. The message log identifies test mode. This avoids unfinished openings/delayed jumps and does not satisfy the startup gate. **Release cutscene (testing)** explicitly calls the mapped cutscene-off operation; errors never release it automatically.

Periodic source snapshots: `backups/conversation-*.zip`. Original game inputs remain read-only.
