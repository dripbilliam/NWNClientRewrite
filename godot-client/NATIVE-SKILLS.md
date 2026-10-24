# Native skill shortcuts

Skill bindings now activate from the Godot quickbar. The native action owner
keeps targeting, cursor replies, cancellation and actor/area lifetimes; the
small JS adapter sends the original native skill message. This fills a missing
network activation path in the earlier JS client rather than reusing an
existing skill session handler. The full migration remains incomplete.

## Original behavior and evidence

Read-only analysis uses the installed original `nwmain.exe`, SHA-256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Neither its file nor a running original client is modified.

- Quickbar activation `0x14085c8f0`, type 3, passes the full packed skill INT
  into target initializer `0x140702c30`, mode 2. Exact value 10 (Parry) sends
  mode 2 immediately. Exact value 22 (Craft Trap) targets the controlled actor
  immediately. These comparisons use the full INT, not its low byte.
- Open Lock, exact value 9, accepts doors and placeables. Other pending skill
  selections accept creatures. Native good/bad cursor IDs are 37/39.
- Callback `0x140702b80` calls wrapper `0x140805480`. The wrapper supplies a
  zero vector; a mouse-hit position must not become the skill request position.
- Sender `0x1407c0860` writes envelope 112/6/7: skill BYTE, high-WORD low BYTE,
  client object ID and three FLOATs. The full dispatcher `0x1404531b0` subtype 7
  calls `CNWSCreature::UseSkill`, `0x1403aa390`, with those fields, the actor's
  area, invalid item ID and force zero, subject to its actor/area gates.
- `CNWSCreature::AIActionHeal`, `0x1403bf4e0`, requires an item with property
  type 0x50 before proceeding. The shortcut request supplies no item. An
  otherwise trained Heal shortcut can consequently finish silently without a
  kit; the client must not invent success text. This does not verify actual
  healing-kit use or healing outcomes.
- Craft Trap queues the original `x0_skill_ctrap` script. Its local-server
  conversation is observed below; the client does not emulate that script.

`reports/native-skill-{wrapper,use,heal}-rea-v1.json` retains function identity,
pseudocode, call boundaries and analysis limitations. `tools/inspect-skill-native.py`
checks full PE exception-record bounds and emits read-only disassembly metadata.
`tools/inspect-native-skill-request.py` executes the complete original sender,
wrapper and input dispatcher in isolated Unicorn memory, capturing transport,
lookups and the final UseSkill call. It does not execute skill outcomes.

The oracle's 238 cases cover both native message formats, packed modes, IDs,
zero/nonzero vectors, absent message/actor/area and blocked actor gates.
`reports/native-skill-request-observations-v2.json` repeats v1 identically.
The synthetic protocol fixture is backed up under `tests/fixtures`; 107 format-1
packets compare against our writer over every defined bit, excluding undefined
padding. Proprietary executable or asset bytes are not saved in the project.

## Local validation

`reports/native-skill-local-v3.json` passes all 45 functional checks against
127.0.0.1:5121, including the previous inventory/item-power/assignment checks:

- Heal assignment, targeting and cursor 37, one actual native skill submission,
  selection retirement and clear. No Heal feedback is fabricated.
- Two Parry mode-2 requests without an intermediate target cursor, then clear.
- Craft Trap assignment and immediate self request; real server dialog-entry
  strRef 86902 and four dialog-replies arrive, display and close normally.
- Four equipment acknowledgements, potion stack 3 to 2, prepared Light uses
  2 to 1, menu command submission/clears and WASD through simultaneous menus.

Native exit is zero, disconnect is observed, no commands are rejected, no
renderer/native errors occur and pending inventory icons retire to zero.
The skill cursor check supplies a synthetic native hit and temporarily holds
physical polling so an unrelated OS mouse position cannot overwrite it.
This is functional evidence, not a physical-device or clean FPS benchmark.
The user's original client/editor are preserved; no public server is contacted.

`reports/native-skill-node-v4.log` passes 75 backend tests with no failures or
skips, including codec oracle comparison, canonical ownership, targeting types,
packed special cases, retirement, duplicate selection and shared action routing.
Seven rendered shortcut GUI checks pass in `native-skill-shortcut-ui-v2.json`.
`native-skill-action-ui-v1.json` passes 8,000 authored input/action checks,
predominantly the existing native-derived hit-band oracle, not 8,000 gameplay
scenarios. Their awaited engine exits and explicit logs are clean.

Retained failed local v1 incorrectly required Heal chat feedback. Local v2
proved the crafting conversation but caught a synthetic-hover/physical-polling
race in its driver. Both remain rejected. Existing missing particle providers
and unhandled game-message diagnostics are unchanged and remain open.

## Remaining scope

Actual healing-kit use, trap submodes, other skill outcomes/rolls and feedback,
skill radial handlers, passive-skill UX, custom server variants, broader reconnect
persistence and physical input/fidelity review remain. Heal/Parry/Craft Trap
bindings now survive actual saved-character reconnect, with crafting activated
by native Ctrl+F input; see [shortcut persistence](NATIVE-SHORTCUT-PERSISTENCE.md).
The original writer and
shared target owner do not prove every skill action succeeds. Full UI,
rendering, combat and moving-scene 60 FPS acceptance remain open.
