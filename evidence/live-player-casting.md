# Live ordinary player casting

This records the initial ordinary-casting pass. Later shared engine work,
conversion, touch/vision/dispel/shield effects and damaged-caster checks are
documented in [the current spell continuation](spell-ecosystem-shared-owners.md).
Its current status supersedes the pending items and test count below.

Target: installed NWN:EE89.8193.37-17, PE x64 `nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
The install and Ghidra project were read only throughout this pass.

## Native evidence and scope

- `HandlePlayerToServerInputMessage1404531b0`, decoded message18:
  spell lookup, target-mask echo, master metamagic and remaining uses precede
  ActionManager1 and AddCastSpellActions at `140454b9d`. Captures:
  `ghidra-client-input-spell.txt`, `native-live-player-cast-input-asm.txt`.
  The local decoded request does not claim NWN packet serialization. Spontaneous
  conversion is an explicit unsupported branch, not an ordinary-cast fallback.
- Existing separately captured `AddCastSpellActions14037d540` and ordinary
  `AIActionCastSpell1403ada70` now bind to the live object queue, active rules,
  inventory/spellbook, world clock, LOS, opportunities and combat round.
  `native-live-spell-cancel-asm.txt` verifies action15 cancellation at
  `140387205..140387247`; release flag0 returns0 before private cleanup.
  `AIActionCheckMoveToPointRadius1403b5b00` supplies action18 ground approach.
- `GetHasSomaticComponent1402af4d0` searches exact lowercase byte0x73;
  `GetHasVerbalComponent1402af500` searches0x76. Capture:
  `native-live-components-asm.txt`. The earlier helper-boundary fixtures used
  conceptual uppercase S/V while stubbing these owners. They now represent
  those captured presence flags with lowercase runtime data. A separate test
  checks uppercase does not satisfy the original case-sensitive search.
- `BroadcastSpellCast140384300` ordinary observer path follows spatial order,
  long-range cache, perception bits3, effective spellcraft, active PickSchool /
  Opposition and one authoritative d20 per eligible observer, including NPCs.
  Identified IDs are retained at the local representation of +808. A nearby
  counterspell controller is rejected explicitly before ordinary casting.
  The full counterspell coordinator remains unimplemented; ordinary broadcast
  is statically mapped and integration-tested, not an original end-to-end
  broadcast or networking comparison. Captures:
  `native-live-spell-adjacent-asm.txt`, `ghidra-cast-counterspell-count.txt`,
  `native-live-rules-constructor-asm.txt`, `native-live-spell-loader-asm.txt`.
- `SpellCastAndImpact14049c4b0`: ordinary payload allocation/copy at
  `14049c738..14049c8be`; AddEventDeltaTime at `14049c8f5` sends event8 to
  the caster, with caster as caller and target inside the owned payload.
  Delay is the previously calculated +220 travel time. +224 guards duplicate
  dispatch. `inspect-native-cast-impact.py` runs49 cases through untouched
  original instructions, capturing lower lookup/allocation/presentation and
  scheduler boundaries; `live-casting.test.js` compares calls and fields.
  This comparison covers ordinary non-projectile dispatch, not all branches.

## Replacement integration

`spell_input.js`, `spell_runtime.js`, `spell_cast_impact.js` and
`spell_cast_broadcast.js` connect the shared owners. No spell outcomes are
hardcoded. Active SPELLS ImpactScript runs through the existing deferred
event8 receiver and shared named-script engine. Existing native save,
resistance, effects and damage providers remain responsible for the script's
actual behavior. All objects keep registry OBJECT_IDs.

Spellbook buttons now pass class **index**, metamagic and computed domain
level, matching their dragged hotbar binding. Cast requests snapshot canonical
actor/area and point; changing control/area discards the stale input. The local
target cursor uses active TargetType bits, object picking and native XYZ
conversion for ground clicks. Escape/right-click cancel targeting without
clearing a previously queued action. Native client targeting details such as
inventory-item targeting, action modifiers and exact cursor presentation still
need dedicated reverse-engineering/acceptance. Rendered acceptance here covers
self-targeting only; ground approach is wired but not full campaign acceptance.

## Validation and remaining limits

-1319 tests and production build pass.
- `live-casting-installed.json`: installed wizard/Prelude, startup and native
  world AI disabled to isolate casting. Light uses2→1, conjure16/cast19,
  installed `NW_S0_Light` executes once and creates spell100 visual effects;
  action queue drains. No fabricated spell effects or readied slots.
- `live-casting-enemy.json`: same wizard, explicit PVP0 matching the UI,
  placed2m from an authored goblin in its area, real perception update.
  Installed Magic Missile107 uses4→3, conjure15/cast17, installed
  `NW_S0_MagMiss` executes once, target canonical466 changes4HP→-11HP.
  Fixture setup uses no general world AI and is not continuous combat/campaign
  acceptance. The first fixture run omitted PVP and correctly failed; the test
  configuration was corrected, not the reputation engine.
- `live-casting-ui.json/png`: isolated Electron profile, in-memory module entry
  override24,14,0, startup disabled. Spellbook click/self target and dragged F2
  both consume real saved Light slots. Captured clips conjure2/castup, followed
  by idle; second cast waits until the native six-second round permits it.
  No renderer console errors. This scene still reports an unrelated missing
  `plc_w02` sound; its diagnostic is retained, so this is not a clean whole-area
  or whole-client acceptance claim.

Counterspell resolution, spontaneous conversion, special feat/item casting,
script-cast command adapters, complete release/projectile rendering and client
message formatting remain open and explicit. Release presentation and projectile
presentation omissions are logged once per selected cast. Unsupported impact
script engine calls and missing assets retain their normal diagnostics.
Ordinary cast execution working does not establish complete spell, combat,
campaign, save-game or network parity.
