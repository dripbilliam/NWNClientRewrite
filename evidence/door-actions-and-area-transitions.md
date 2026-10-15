# Scripted doors and the Prelude exit

2026-10-15. Target NWN:EE89.8193.37-17 x64; installed binary SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
The install and Ghidra project remain unchanged. Ghidra HTTP reads,
unwind-bounded PE disassembly and isolated instruction execution supply the
native observations. No proprietary assets or binary code were copied out.

## Reported failures and native owners

The user's runtime log
`runtime-2026-10-15T05-07-45-810Z-de8fb059-4a69-4b06-90fa-e08824ea630f.jsonl`
records ActionOpenDoor, engine43, at `m0q01a0bimelc1@0xf5` and
`m1q0apavelslg03@0x70`. Six transition attempts stop at StringToFloat,
engine233, `nw_g0_transition@0xa28`. Executing the repaired script subsequently
exposed AngleToVector, engine144, at0xa67. These are general engine calls;
campaign identifiers are used only in the regression fixtures.

- ExecuteCommandStringConversions `0x140547900..0x1405479b9` pops a string.
  Command232 calls atoi at `0x140547965`; the float branch calls the
  common_atof_l wrapper `0x140c86b88` at `0x140547981`, narrows DOUBLE to FLOAT
  with CVTSD2SS at `0x140547989`, then pushes at `0x140547994`. Ghidra truncates
  this function at a cleanup call; full PE disassembly verifies the body.
  The replacement parses numeric prefixes using C-locale whitespace, decimal
  and hexadecimal notation, exponent rollback, signed zero and special values,
  then rounds to f32. Local Windows CRT C-locale `_atof_l` measurements are an
  independent parser-provider comparison, not an observation of the game's
  process-global locale. NaN payload/FP exception state is not established.
- ExecuteCommandVectorConversions `0x14054a9b0` handles AngleToVector144 by
  multiplying FLOAT degrees by the f32 radian constant. Calls at
  `0x14054aa96`/`0x14054aaa1` use CRT cosf/sinf, returning native XYZ(cos,sin,0).
  This is distinct from the existing script cos/sin DOUBLE path. The adapter
  reuses the previously traced bounded native float trig implementation;
  exceptional/large-angle branches still report their unavailable owner.
- ExecuteCommandOpenDoor `0x1405379f0..0x140537ac5` pops target and optional
  run INT(default0), resolves self and requires its area and commandability
  exactly1. It calls AddOpenDoorAction at `0x140537aa3`.
  ExecuteCommandCloseDoor `0x140512190..0x140512251` requires an area and calls
  AddCloseDoorAction at `0x14051222f`; its queue owner rejects commandability0.
- AddOpenDoorAction `0x14048dc70..0x14048ddc4` and AddCloseDoorAction
  `0x14048d750..0x14048d8a4` append internal action20/21. These differ from
  script-visible ACTION_OPENDOOR5/ACTION_CLOSEDOOR6. The records have two
  parameters: canonical object ID(type3) and run INT(type1), generated group
  ID, group-counter wrap skipping65535 and native initialization. Direct queue
  owners accept any nonzero commandability; the open command's stricter1 gate
  occurs before that owner. Sixteen original-instruction captures agree with
  the replacement, including noncanonical commandability and high object IDs.
- AIActionOpenDoor `0x1404a2fb0`, AIActionCloseDoor `0x14049eb30`: the mapped
  noncreature path rejects dead/dying actors or missing targets, queues event7
  or6 respectively with caller=self and target=parameter0, pushes Wait(.5) to
  the front with the same group, and returns completed2. Constants are verified
  at `0x140dfc160`(7), `0x140dfc164`(6), `0x140df04e0`(2),
  `0x140df04e4`(3), and `0x140d81930`(.5). This is the path used by the reported
  scripts assigning the command to the door itself. Creature approach, lock
  evaluation, trap/reputation and interaction-animation branches remain
  unavailable, explicitly recorded, and preserve their queued record.
- Door EventHandler `0x14041e760` handles7 by resolving the caller and selecting
  side1 only for a strictly positive f32 native XYZ orientation dot product;
  absent caller selects2. It stores last opener+0x4ac, calls SetOpenState, mirrors
  the state to a linked door, then runs source OnOpen(script0). Event6 stores
  last closer+0x4b0, sets/mirrors0 and runs source OnClosed(script1). Linked doors
  do not receive fabricated opener/closer events or scripts.
- SetOpenState `0x140423230` preserves the native open-state byte independently
  of animationD8. Field498==0 forces destroyed3. Native state/animation mapping
  is0/22,1/50,2/51,3/72. The renderer receives actual state changes. Native
  UpdatePlayerAutomaps and BudgeCreatures side effects remain recorded gaps;
  this patch does not invent creature displacement to approximate them.
- Door constructor `0x14041d6b0` calls SetAILevel0 at `0x14041d7f7` after
  acquiring the master at `0x14041d7e9`. It initializes field498=1 and heartbeat
  time fields49c/4a0=0. Door AIUpdate `0x14041db30` checks heartbeat/action/effect
  activity, performs the strict >5999ms heartbeat test, suppresses the first
  callback when the previous time is0, then updates effects and runs the shared
  object action list. The replacement now registers/updates canonical door IDs
  and can drain their captured ActionDoCommand situations as well as door/wait
  actions. It does not run creature combat rounds on doors.

Raw captures: `backups/animations/ghidra-door-actions-*.txt`,
`ghidra-transition-vector-conversions.txt`, `native-door-command-asm.txt` and
`native-door-constructor-vector-asm.txt`. Independent queue observations and
CRT measurements are in `native-door-queue-observations.json`.

## Renderer repair discovered during transfer validation

The first completed rendered out-and-back traversal exposed a THREE self-parent
error. Destination model `c_horror` contains two distinct binary nodes named
head, with one a child of the other. The parser had reduced binary child-offset
edges to names; the name map then attached a group to itself. Duplicate Impact
and head labels also occur in other installed models.

Binary parsing now retains physical parent indices. Hierarchy construction,
mesh/light/emitter attachment and skin bone references use node identity;
cloned renderer nodes retain their physical index for animated skin updates.
UI hierarchy construction uses the same parent-edge policy. Name aliases remain
for existing animation/attachment consumers. Actual parent cycles fail with an
explicit error, while the ASCII NULL parent remains a root sentinel. Animation
tracks ambiguously targeting duplicate names have a separate diagnostic because
their complete native resolution policy has not been reconstructed.

This fix follows the existing binary child arrays. It is a structural correction,
not a new claim about native animation-name lookup or all model extensions.

## Validation

- 1307 tests and production build pass. New tests compare16 native queue
  observations,22 independent C-locale parser cases, native angle axes, queued
  event/wait timing, linked-door callback ordering, caller/event contexts, door
  AI registration and captured-situation dispatch. Hierarchy tests retain
  duplicate parent/child names in world/UI trees and reject real cycles.
- `scripts/smoke-area-transition.mjs` runs both original reported dialogue NCS
  resources. Bim's sequence unlocks and opens the door through canonical
  actions/events, scripted closing/reopening works, and the actual generic
  transition script transfers to m0q1b. No engine/script failures occur in the
  tested chain. The destination's authored missing script2.ncs remains recorded.
  Character-import events are isolated in this fixture, and module startup is
  disabled; it is not a campaign-playthrough acceptance test.
- `scripts/audit-area-model-hierarchy.mjs` loads106 destination-area model
  resources. Every physical node is retained exactly once; the known duplicate
  name cases have distinct parent/child groups. No hierarchy failures occur.
- Rendered regression uses the actual dialogue exit reply, pointer selection,
  approach/transition, next-area scene loading and normal return interaction.
  The final run passes m0q1a to m0q1b to m0q1a with actor565 and door IDs2/45
  preserved, no renderer errors, and arrival/return positions recorded. Earlier
  test attempts selected camera tutorial/abort branches before the exit reply;
  the fixture now chooses the authored unlock reply. The first completed
  traversal exposed the duplicate-name hierarchy error repaired above.
  The fixture's entry-position override and preview sun are explicitly testing
  conveniences. Original files are unchanged. Final result is recorded in
  `backups/animations/area-transition-rendered-smoke.txt` and its PNG capture.

Native automatic door displacement, creature-owned scripted door interactions,
full automap side effects, missing authored resources, spell/item UI execution
and the other existing polling/runtime omissions remain open. Inter-module
traversal and server-authoritative transition acceptance are separate gates.
