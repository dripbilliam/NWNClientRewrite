# Multiplayer feat, familiar and server-issued innate input — 2026-10-18

Previous goal turn: PROGRESS, generated-character native-type fix sealed.
Current turn: PROGRESS. Full multiplayer goal ACTIVE, not completed by this
casting/input milestone. No original-client concurrent play is claimed.

Read-only nwmain.exe build89.8193.37-17 x64 SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`;
owned unchanged nwserver.exe SHA256
`98951511ae7d06a251355f12d4f3e4b96269a2414fa3058e641afd70098690f6`.
No installed files, binaries, Ghidra database, server settings or ELC changed.

## Original owners and implementation

| Owner | Contract / evidence |
| --- | --- |
| Feat wrapper805310 → sender7c04e0 | Native6/6, feat WORD, auxiliary WORD, client raw OBJECTID. Object targets omit XYZ; location targets always carry XYZ, including zero. No spell-style Z offset or magnitude gate. Invalid target plus null point sends nothing. |
| Full server input4531b0 subtype6 | Native actor/block/read/area gates execute, followed by UseFeat3a91d0. Its gameplay implementation remains the server's. Object point is zero; location point retains native FLOAT values. The outer input return is separate from whether UseFeat accepted/queued a particular feat. |
| Mode wrapper8055c0 → sender7c02e0 | Native6/10 BYTE mode, with an OBJECTID only for mode5. Mode0 has an additional client GUI branch for feat240, outside the newly exposed feat-mode routes. |
| Original request oracle |1710 cases:174 feat sender/full server-dispatch cases and1536 mode sender cases across formats0/1, WORD edges, IDs, points/null and failed gates. Native serialization executes. Transport, object/area lookup and final UseFeat are captured leaves. Mode validation/effects are not executed by this oracle. Fixture `native-network-feat-request-observations.json`, script `inspect-native-network-feat-request.py`, log v1. |
| Targeter703310 and radial998520 | Reuses the existing original-compared shared feat targeter/radial selector, including auto-self, signed child selector, packed auxiliary retention/reset, registered type masks and compiled mode routing. Feat targeting permits either creature when either creature bit is registered; it does not install the ordinary spell creature-veto callback. |
| Quickbar activation85c8f0, type4 | Creates targeter702c30 mode1 with the packed INT parameter; no special spell cast path is substituted. Type38 separately calls possession sender7bff40 and remains a shortcut integration follow-up. |
| Familiar lookup6ab9e0 →6d8100; leaf9957a0 | Looks up the controlled creature's field27c as a creature, then changes the familiar leaf to native possession action/label523/icon. No matching by name or nearest creature. |
| Client update781e80 mask2000 | Master ID and native associate type2/3 update existing master's companion278/familiar27c. Its own companion/familiar pointers clear from the two transmitted flags. No absent-master backfill or fabricated master object. The port stages these cross-object changes with normal batch rollback. |
| Possession9980c0 →7bff40 →6/19 | Empty request. Server4531b0/19 checks GetIsAbleToPossessFamiliar391080 then calls PossessFamiliar3d6360. Live server owns control transfer and all creature resources. |
| Party transfer4ddf90 / client7a7440 subtype14 |14/14 DWORD player ID + client raw OBJECTID. Now decoded into the existing control map. Player-state I records select the controlled proxy; old PC and familiar keep distinct canonical IDs. Full party bar14/1/3/4 remains outside this patch. |

Typed trusted-frame/session IPC and controlled current-area guards connect feat,
mode and familiar inputs to the backend. Active module FEAT data validates row
metadata. Feat/mode success, ownership, rolls, spell execution, resources and
effects stay on the vanilla server. There is no multiplayer ModuleSession,
script VM, AI, feat resolver or local resource spend.

The wheel uses shared native feat/variant decisions. Type4 hotbar labels use the
low WORD; target initialization retains the high auxiliary WORD. Ready-use
overlays read replicated feat uses, with native100 omitted for unlimited feats.
Stale area, session or controlled-creature target selections cannot be reused;
async menus/assignment also retain their originating controlled actor.

## Racial type and static visual corrections

Client781e80 reads a WORD into stats+50, used to index racialtypes by7f6b20. The
existing parser's public `stats.race` name belongs to the different following
BYTE68. It was incorrectly used as the racialtypes index by model, voice and
spell-gain adapters. `racialType` now aliases the original WORD/fieldD20; those
adapters use it. Legacy raw fields remain for stored capture compatibility.
Replay verifies elf1 and familiar aberration7. Active human/dwarf Charisma
adjustment regression tests exercise the actual first-level casting gate.

The real innate ray loaded a model with no animation clips. Renderer code assumed
every model had an animator and destroyed it with a null dereference. Network
instances now retain parsed model metadata independently of their animator;
projectile/cast lifecycle tolerates static models. Native projectile stage
owner9ddd00 reports success even if Gob::PlayAnimation cannot find a clip. That
existing native contract is retained: valid static models still travel, impact
and expire; absent clips/events remain diagnosed, not fabricated. Changes apply
to model capability generally, not a named spell or projectile.

## Live evidence

Real hidden offscreen Electron GPU renderer, actual pointer/menu/F-key handlers,
unchanged installed wizard.bic, unchanged owned Prelude server on UDP5121. Private
input uses the one-use encrypted loopback helper. Each QA session disconnects.

- v57: three wheel inputs, one native6/6, familiar use1→0 and a new canonical
  server-created familiar;1719 GPU frames, zero runtime errors.
- v58: summon then native Possess Familiar wheel action; six UI inputs and
  native6/6 + empty6/19. Server transfers control to its familiar and replicates
  60 innate records, including24 ready frost rays.2254 GPU frames, zero errors.
  Do not confuse these with arbitrary uploaded BIC powers, correctly skipped by
  the fresh-PC import path established in the preceding checkpoint.
- v59: actual innate wheel and type44/F11 casts consume24→23→22. Both projectiles
  failed in rendering because of the null-animator assumption. This failure trace
  is retained, not counted as completed visual parity.
- Final v60:15 actual UI inputs, native feat/possession/innate requests and a
  type44 assignment. Server-owned24→23→22.3849 GPU frames, zero error or failed
  projectile records. Both models load, travel on native path5, attach at impact
  and expire: received/spawned/loaded/impacts/destroyed2 each, failed0, active0.
  Non-humanoid cconjure1/ccastout/ccastoutlp play. No cast models/dummies remain.
  Wheel and hotbar PNGs visually inspected. Short projectile lifetime is proven
  by actual lifecycle events; screenshots alone do not prove pixel-perfect rays.
- Final v61: six assignment/F-key steps, native type4 assignment and one6/6.
  Server uses1→0; second F11 sends no second feat request.1356 GPU frames,
  zero runtime error records. Native familiar spawn is separate from local UI.

Existing audio, persistent effects, body animation-node and other unsupported
packet warnings remain. Zero error records do not mean the entire client is
implemented or all original visual effects are exact.

## Verification and remaining work

317 focused integration tests PASS (`network-feat-input-tests-v8.txt`), covering
network trust/transport/replication, canonical world rollback, feat targeting,
shared casting, original native projectile paths and generated character import.
Production build PASS(v8, existing size warning); backend/preload/harness syntax
checks PASS. No full-suite/campaign-completion claim.
Credential audit covers3460 files across recursive source/evidence/tooling,
compiled dist, research/current captures and REA stderr: private hits0
(`network-feat-input-credential-audit-v1.txt`). Private server profile/settings/
identity/logs are excluded. All QA renderer processes have exited and their
sessions disconnected; owned server PID36824 still listens on UDP5121.

Next: native return-to-PC/unpossession, other associate commands and party bar;
type38 possession shortcut assignment; full mode active/cancel UI and live mode
effects; item powers/preparation/remaining spell feedback, persistent effects and
audio; broader shared combat and actual original-client concurrent gameplay.
Combat-mode projection is explicitly diagnosed by the ability menu, rather than
claiming complete stance/cancel availability from request serialization alone.

Verified checkpoint `multiplayer-feat-input-20261018-v1.zip`:13090 files,
255458871 bytes. Writer80664 finished terminal0; every entry length/SHA256
verified. Scope62 required present, forbidden0. Only audited REA stderr is
included from runtime-logs. Private server profile, binaries/assets and BICs
are excluded. Scope audit and this postseal note are outside the sealed archive.
