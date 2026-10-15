# Scripted one-liners and camera mode requests

Target NWN:EE 89.8193.37-17, x64; installed PE SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Read-only Ghidra and hash-checked PE analysis. No annotations or game assets
were changed. Runtime behavior uses object IDs and active DLG/NCS resources;
campaign tags occur only in the installed regression fixtures.

The user's log identified SetCameraMode (engine504) in `m1q0apaveslg03@0x20`
and SpeakOneLinerConversation (engine417) in `nw_od_feedback8@0x41`.

## Native observations

- ExecuteCommandSpeakOneLinerConversation `0x140546880..0x14054696f`: optional
  dialog string, optional token target default OBJECT_INVALID; resolve self as
  CNWSObject, call RunDialogOneLiner at `0x140546950`. Ghidra incorrectly stops
  at a cleanup thunk; full unwind-bounded PE disassembly verifies the remaining
  handler. No script return value is pushed.
- RunDialogOneLiner `0x1404994d0..0x1404997d8`: empty dialog name uses the
  object's native conversation resref. LoadDialog(...,0), then select an entry
  with GetStartEntryOneLiner (call `0x14049971c`). Token target's virtual gender
  getter supplies the byte at `0x140499762`; absent target uses default male0.
  Chat type8 includes speaker ID, token target ID, localized text and Sound
  resref (call `0x1404997b8`), followed by entry action script (call
  `0x1404997cd`). No full dialogue state, speaker locks, quest update or modal
  reply UI is created. Missing/unusable dialogs finish without a VM abort.
- GetStartEntryOneLiner `0x14041ada0..0x14041afd5`: starting links remain in
  authored order. Empty Speaker is required before the condition runs (call
  `0x14041ae11`); reply-bearing entries are rejected AFTER the condition test
  at `0x14041ae2d`. Selected text, sound and script/action parameters are copied.
  LoadDialog `0x14041b5c0` still loads entry RepliesList counts at
  `0x14041bb32..0x14041bb5a` when the global reply list is not requested.
- SendServerToPlayerChatMultiLangMessage `0x1404d2e70`: type8 enumerates player
  clients, requires the same area and inclusive 3D range20 (f32 constant
  `0x140dda4cc`). Eligible lines still run their action when no client receives
  the message. The local adapter uses the existing controlling-client provider.
- ExecuteCommandSetCameraMode `0x14053ea60`: resolve the controlling player
  client (call `0x14053eaa2`), narrow integer mode to a byte, send camera request
  at `0x14053ead0`. SendServerToPlayerCamera_SetMode `0x1404d1190` writes that
  byte and sends message family16/subtype2. Installed API constants identify
  chase0, top-down1 and stiff-chase2; its documentation specifies that invalid
  modes and non-player-controlled targets do nothing. The replacement preserves
  those routing/default rules and exposes the applied mode to the renderer.

Raw captures are `backups/animations/ghidra-feedback-*.txt`,
`native-feedback-engine-asm.txt`, `native-feedback-dialog-load-asm.txt` and
`feedback-installed-resources.txt`. The latter contains structured API/script
measurements rather than extracted NCS or NSS assets.

## Implemented behavior and limits

One-liners now select active eligible entries, resolve localized text with the
specified token target/gender, route explicit authored sounds, and execute entry
actions using the original owner ID and nested VM budget. They preserve existing
conversations and action queues. The GUI displays speech in its message/notice
surfaces. Native overhead bubble placement, the full creature-token vocabulary
and parameterized DLG scripts remain incomplete and are recorded explicitly.

Camera requests update only the controlling client's state. Top-down uses the
existing orbital/follow view; chase modes use a local camera adapter. Native
camera smoothing, input behavior and complete packet/client acceptance have not
been reconstructed. Chase requests explicitly record this presentation limit.
This change does not establish multiplayer protocol parity.

## Validation

- 1,291 tests and production build pass. New tests exercise eligibility order,
  named-speaker rejection, condition-before-replies behavior, owner/budget
  propagation, same-area and exact20m boundaries, unreceived actions, sound
  routing, token target/gender, preservation of active conversations, controlled
  clients, byte narrowing and invalid modes.
- `scripts/smoke-feedback-engine.mjs` executes both original reported NCS
  resources, through the actual VM. Pavel requests top-down mode; the door
  resolves its default `nw_all_feedback` DLG and emits string58435. That selected
  entry has no authored Sound, so silence is expected. No engine-unimplemented
  or script-failure records occur. The door's subsequent ActionDoCommand remains
  in its canonical action list; this fixture does not claim noncreature action
  queue scheduling has been completed.
- Electron `scripts/smoke-viewer.cjs --check-feedback-engine --play --character
  --full-scene --entry-at=24,14,0` selects the actual Pavel actor by mouse,
  follows authored reply0 three times, and reaches entry33 with renderer camera
  mode1 and no dialogue error. An initial camera view occluded the target;
  ordinary camera orbiting resolved it. Screenshot and result:
  `backups/animations/feedback-engine-rendered.png` and
  `feedback-engine-rendered-smoke.txt`. The fixture uses an in-memory entry
  override, startup disabled and a labeled preview sun; it is not a campaign
  playthrough acceptance test.

Existing missing `script1.ncs`, `plc_w02.pwk`, unrelated polling owners and other
campaign/script gaps remain recorded. They were not suppressed by these fixes.
