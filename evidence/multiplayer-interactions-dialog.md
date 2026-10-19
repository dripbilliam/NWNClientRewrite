# Native interaction requests and dialog — 2026-10-18

The multiplayer client now submits typed door open/close, talk, use-object and
single-controlled-actor attack requests. The shared radial renderer/layout is
connected to these actions; missing branches produce explicit diagnostics.
No local ModuleSession, action executor, DLG graph, conditions, scripts, damage,
spell resolution, lock mutation or object-ID allocation runs in this path.

The server owns dialog text references, reply availability, reply IDs, current
entry value, advancement and closure. A separate dialog view displays those
values and sends the selected wire ID. Stale session/area/entry selections are
rejected. Native Escape behavior when secondary reply count equals one is
preserved. The installed base/custom/female TLK reader uses the previously
original-derived FetchInternal owner. Name/gender tokens use the original-derived
ParseStr and StringTokens2DA action callback with replicated appearance/name
context. Missing class/stat/world/custom-token providers remain diagnosed;
their values are not computed from local gameplay. Plain text suppresses color
control tokens, consistent with the existing plain-text presentation adapter.

## Evidence and scope

Read-only original NWN:EE89.8193.37-17 x64 nwmain.exe, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original binaries and existing Ghidra project unchanged. REA retained dossiers
are under backups/animations/rea-network-*.json. Instruction scan candidates are
explicitly provisional; subsequent full function analysis established these paths:

| Client sender | Envelope | Native server dispatch/result boundary |
| --- | --- | --- |
| 1407bf860 | p/6/3: target OBJECT_ID, WORD action | 1404531b0: action21 open, other action close; ActionManager2 then queued door action |
| 1407bf180 | p/6/2: target OBJECT_ID | AddAttackActions(target,0,1,0), clear special attacks; group branch separate |
| 1407bf900 | p/6/8: target OBJECT_ID | reaction/commandability gates, queued action24 dialog |
| 1407c07c0 | p/6/11: target OBJECT_ID, two BOOLs | optional event42 and update flag, ActionManager2, AddUseObjectAction |
| 1407bbc50 | p/20/3: owner OBJECT_ID, reply DWORD, abort BYTE, entry DWORD | 140448a00, ReplyDialog140498df0 with authenticated player ID |

Placeable click wrapper1408720a0 sends flags0,1. Creature use paths can send0,0.
Door selection14086e810 sends action21 for animation22, action22 for50/51.
Native door SetOpenState140423230 maps0/1/2/3 to animations22/50/51/72;
the shared model animator now follows those replicated states. Initial pose is
closed/opened1/opened2/dead; following changes use opening/closing clips. Precise
native client timing and collision/pick proxies remain incomplete.

Client dialog handler1407962f0 and localized reader1409735f0 establish server
P/20 subtypes1 entry,2 reply set,4 selected transcript,5 close. Three entry IDs
are owner, speaker and token context; reply set retains both count groups and
flags. UI6fb560 sets panel owner130;6fb8e0 stores entry134 and secondary countbc0.
Selection6f81e0 uses transmitted reply IDs, not an assumed DLG index, and has the
special Escape branch. Selected transcript subtype4 decodes but its transcript
presentation remains explicitly unimplemented.

`inspect-native-network-interactions.py`:80 original sender/full server input
dispatcher cases PASS, including scalar modes, high-bit IDs, action words,
all use flags, blocked/absent actors, commandability and hostile talk reactions.
`inspect-native-network-dialog.py`:110 original reply sender/full server dialog
handler cases PASS, including IDs, entry values, abort flags and owner lookup/
cast failures. Actual scalar readers/writers execute; allocation/copy/logging,
client group selection, lookup/reaction and queued action/ReplyDialog boundaries
are captured. These oracles do not execute live AI or DLG scripts. Native unused
padding bits are excluded from byte comparisons; all defined bits are compared.

## Real original-server application runs

Owned server PID48532 remained running, Prelude UDP5121. Hidden Electron probes
did not take desktop focus. Credentials were provided only through the encrypted
one-time test channel, never argv/environment/files. Server-bound replies used
the actual dialog buttons, preload/owned IPC/session and persistent native peer.

v11: native talk request approached the NPC and received entry/replies. v12:
eight reply choices advanced the actual Prelude Pavel conversation; unresolved
tokens were visible and diagnosed. v13 exposed the name-context defect (NO STATS)
and is retained as a failed presentation regression. Appearance P records own
the character name; the adapter now reads that owner.

Final `local-network-renderer-v14.json`: join02:02:18/logout02:03:33, eight
server-driven choices, correctly resolved Spectorial Melimion and gender text,
native P/20/5 closure clears the UI, final state closed, failedObjects empty.
The locked hallway door remained animation22/closed after the submitted open
and close requests; no local unlock/state toggle occurred. This is not a live
successful door-opening claim.90 captured diagnostics, zero errors, malformed
game messages, object/clip failures or token-provider warnings in that run.
Raw post-authentication game messages are retained for further decoder work;
login/authentication packets are not exposed to the renderer.

## Remaining acceptance

Successful opening/closing and area-transition gameplay still need native-server
verification. Default use of an open transition door is explicitly diagnosed;
the radial Close action remains separate. Native picking priorities, approach/
transition target wiring, smooth movement, physical desktop input verification,
complete text tokens/transcripts/voice/portrait/camera, examine/container/inventory,
full multiplayer UI, combat/casting/effects and concurrent original-client play
remain incomplete. The full interoperability goal remains ACTIVE.

Validation:45 focused tests PASS (`network-interaction-tests-v10.txt`), covering
native wire oracles, actual campaign dialog capture, stale/owned requests,
installed TLK/StringTokens and prior movement/object/peer/parser regressions.
App build PASS (`network-interaction-build-v7.txt`), existing bundle-size warning.
Credential audit:3032 source/root-note/network-evidence files, zero private
full-key occurrences, four synthetic fixture keys recorded separately
(`network-interaction-credential-audit-v1.txt`). No full-suite rerun was needed.

Post-seal checkpoint: `backups/multiplayer-interactions-dialog-20261018-v1.zip`,
12134 files / 200008934 bytes. Writer43950 exited0 after verifying every archive
entry length and SHA256. All30 selected source/test/capture/validation entries
present; forbidden native/compiled assets, character/module files, CD-key config
and private server profile absent. This paragraph was added after sealing.
Owned server PID48532 remains running; the integration peer logged out cleanly.
