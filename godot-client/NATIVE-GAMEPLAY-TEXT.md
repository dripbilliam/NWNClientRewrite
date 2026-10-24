# Native multiplayer text and examination

Status: **partial gameplay migration, locally verified**. The native client now
receives resolved NWN rich-text spans, server conversations, examination data,
speech/system history and formatted feedback. No Arelith connection was used.
This does not complete interactions, UI, combat, NUI or performance acceptance.

## Ownership

`tools/gameplay-text.mjs` adapts the existing speech/dialog/examine presentation
to data records. The existing `NetworkText` resolves active TLK, rule, identity,
named and custom tokens. `nativeRichText` preserves the fixed-width byte RGB
controls before interpreting token delimiters. Only literal text and numeric
RGB spans reach Godot. Server HTML and Godot BBCode are never interpreted.

`tools/gameplay-delivery.mjs` uses separate asynchronous speech, conversation,
examine and feedback queues. Examination/portrait IO does not block decoded
network packets, movement, chat or another examination. Completion retains the
connection, area generation and request owner. Closed dialogue, superseded
examination, retired areas and disconnected sessions cannot publish old text.
Portrait completion cannot reopen a user-closed examination window.

`systems/server_text.gd` writes spans through RichTextLabel's explicit
push/add/pop API. Black letter outlines and dark choice backgrounds keep bright
server colors readable. Multiline reply buttons grow their hit rectangles.
`server_conversation.gd` keeps the actual unsigned entry/reply IDs, suppresses
duplicate pending sends, supports numeric shortcuts and abort, and recovers
from a matching send failure. Title-bar close requests abort and waits for the
server's close confirmation. Text entry and covered menus retain keyboard input.

Right click / I / the live object-list selection now request the existing real
`session.examine` protocol path. `server_examine.gd` shows the received name,
description, condition/reaction, disclosed creature details, item properties,
effects and trap facts. It does not fabricate hidden stats or missing attunement
lines. Optional table failures keep the available description. Installed
portraits use the same original resource selection and image conversion as the
existing client, asynchronously. Portrait payloads remain transient, bounded
PNG data; original resource files are not copied into the workspace.

`server_chat.gd` supports Talk, Shout, Whisper, Party, DM and Tell requests with
an explicit Tell recipient. It displays only authoritative received speech,
retains speaker names/channel prefixes/colors, and caps ordinary and system
history independently at 200 rows. It does not echo unconfirmed drafts.
`NetworkFeedbackView` is reused for existing script/combat/spell/attack/damage/
initiative formatting. Actual server-script prompts reach native overhead
labels through `server_floating.gd`; no script or combat outcome runs locally.

Godot owns the visible windows, text layout and floating-label frame updates.
The JS backend owns the established protocol/resource/token/feedback providers.
These event-driven adapters do not restart Three's stopped render loop.

The launcher now keeps graphical Godot startup visible (`windowsHide` is only
used with explicit headless startup). The FPS HUD updates during benchmark
warmup; excluding warmup samples no longer blanks the player's counter.

## Evidence

- `reports/native-dialogue-examine-authorized-v1.json`: the user-authorized
  replacement of the FPS preview was followed by another real `GodotGameplay`
  local-server run on staging build v18. All **16** dialogue/examine checks pass;
  Godot exits 0, disconnects cleanly, and reports no renderer errors. The captured
  native frame was visually reviewed: examination and conversation coexist,
  the installed portrait and colored attunement are visible, custom tokens
  resolve, and both reply buttons remain intact. Existing missing particle
  bitmap/wind diagnostics remain; this is a functional regression check, not
  dense-scene performance acceptance or complete migration.
- `reports/gameplay-text-native-v5.json`: **35 native authored checks pass**.
  Literal markup, line breaks, outline styling, wrapped choices, unsigned IDs,
  pending/retry/abort ownership, title-bar close, stale errors, numeric shortcuts,
  chat focus/history bounds, simultaneous panels, portrait completion guards,
  undisclosed facts, connection/area routing, retirement and warmup HUD are covered.
- **9** new adapter/delivery Node cases, **7** protocol cases and **5** integration
  evidence cases pass. They include all 255 nonzero RGB component values with
  literal angle-bracket bytes, the actual token parser, original table lookups,
  independent asynchronous queues, late completion rejection and the existing
  script-feedback formatter. The **25** existing source text/dialog/examine/
  feedback cases also pass, including read-only installed TLK/resource checks.
- `reports/world-scope-gameplay-v1.json`: all **17** existing native area/scope
  regression checks pass with the new gameplay panels.
- **`reports/native-gameplay-local-v3.json`**: all **16 real local native-server
  checks pass**, actual Godot exit 0, explicit disconnect, renderer errors and
  diagnostics empty. The authored NPC is examined via the native HUD's ordinary
  request. Its server-authored attunement, name token, RGB colors, condition,
  disclosed details and installed portrait arrive. Real interaction starts the
  DLG; the native button advances to its second entry, runs the server script,
  and generates actual overhead feedback/history. Normal completion and a
  second conversation's abort execute their distinct server scripts and close
  choices. The native chat entry invokes the server chat/prompt script. Three
  dialogue entries, three reply lists, two server closes and two floating
  feedback events are delivered. Initial native import: 2,542 meshes, 1,631 ms
  observed; this includes a small authored room, not a loading benchmark.
- `reports/native-gameplay-local-v3-gameplay.png` was visually inspected:
  examination and dialogue coexist, original portrait and blue/green/yellow
  spans are visible, token-ready is resolved, choice hit areas are intact, and
  the FPS counter is present. Its instantaneous FPS is **not** sustained full
  captured-world performance acceptance.

The isolated browser staging build is **v13**. The authored module is
`GodotGameplay`, described by `reports/gameplay-server-fixture-v3.json`, SHA-256
`b390d815a3ff92781ed7e01bfdd3f644cd856daea9ec670466907eec9441f4ea`.
It derives only from the hashed authored lifecycle fixture, references installed
art, and contains authored DLG/NCS/GFF data. Its schema/action setup was checked
read-only against the installed script API, DLG field types and
`nw_c2_default4`'s BeginConversation call sites (header-inclusive 227/308).

Failed checks remain visible. Initial native v1 had a type inference parse
error; v2 passed but its relative logger path was invalid. Final v5 has a clean
isolated log. Local v1 examined successfully but its authored NPC used
GetPCSpeaker before a conversation existed. Correcting the fixture to the
original BeginConversation event path fixed that. Local v2 then passed all
dialogue actions but used reserved custom-token ID 7; the script API protects
IDs 0..9. Authored token 77 fixes v3. These fixture failures are not evidence
of a client protocol defect and are not promoted as passing runs.

Run the bounded integration against the owned server's authored module with
`join-local.ps1 -TextSmoke -Report <unused-name>.json`. It auto-selects the
installed wizard, uses normal native requests/buttons, and closes on completion.
No fabricated server replies, synthetic object movement or direct DLG execution
are injected into the client.

## Remaining work

- Full interaction/radial behavior, invisible portal/trigger picking, animated
  door states, health/reaction nameplates and broader target lifetimes.
- Native bitmap fonts and exact float32 floating-text rounding/lifetime,
  billboard/stacking/cue behavior, speech portraits and speech/audio cues.
- Broader real item/trap/effect and all feedback branches; only the described
  actual server flows are validated here. Chat layout resizing and full native
  window z-order across HUD/lobby layers are still incomplete.
- Server-vault-only admission/creation, metadata/per-part updates, full combat,
  spells/feats/targeting/quickbars, player windows, full NUI, controllers/effects,
  audio and the rest of the migration inventory.
- Sustained >=60 FPS in a complete moving captured/local scene, clean paired
  loading/CPU/GPU measurements and broad fidelity/performance acceptance.

The full migration goal remains active. The existing working main/dist client
is unchanged; owned local testing preserves unrelated games and the project editor.
