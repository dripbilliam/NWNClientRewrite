# Player-state replication and persistent connection owner

Target: unchanged installed NWN:EE89.8193.37-17 `nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
This supersedes the previous checkpoint's open I-record decoder. Renderer/UI
attachment and actual shared gameplay remain open; the full goal is ACTIVE.

## Native evidence and implemented fields

`WriteGameObjUpdate_PlayerUpdate1404e8420..1404ea6bf` emits I, controlled-creature
OBJECT_ID and a WORD section mask. Retained native pseudocode was read completely
in three bounded pages (60399 characters), `rea-network-player-update-writer-view`,
`rea-network-player-state-view-two`, `rea-network-player-state-view-tail`.
`native-network-player-state-pseudocode.txt` joins those pages for research.
No Ghidra annotations, native executable or live-process writes were made.

The decoder covers combat/level-up fields, skill/player flags, memorized slot
counts, known/prepared spell changes, spontaneous uses, feats/remaining uses,
effect icons, action-queue changes, automap encodings, visibility, abilities and
special-ability vector changes. Unknown field meanings retain native offsets.
Unused mask bits are not assigned invented payloads.

Key native ownership checks:

- ComputeLastUpdate_GuiKnownSpells1404c9ae0 stores old spell removals at last-update
  b98 and new spell additions at c18. The serializer writes removals first.
  Matching that data flow prevents an inverted spellbook update.
- ComputeLastUpdate_GuiMemorizedSpells1404c9d80 constructs DWORD spell, BOOL
  ready/domain, BYTE metamagic/index/level at offsets0/4/8/c/d/e. Slot/level are
  transmitted explicitly; no local spell-level computation replaces them.
- WriteGuiEffectIconsUpdate1404ee2d0 widens counts/icon IDs from BYTE to WORD at
 8193.37.2. Icon state is not an invented effect/property identity.
- CNWRules::LoadSkillInfo1402ac6f0 stores the physical skills2DA row count as BYTE
 107. A level-up block requires that resource-derived count; absent ownership is
  diagnosed rather than replaced with a fixed base-game skill count.
- Native action differences use A/S/D with branch-dependent target, point and
  DWORD fields. Native automap encoding has three distinct mode pairs, verified
  with sparse/dense/reset fixtures. Their raw modes/points are retained for a
  future map owner; writer evidence alone does not establish client map baseline
  semantics. No local exploration is performed.

`network_player_state_store.js` applies authoritative differences without local
spell-use, slot, feat or ability calculations. It preserves unaffected cached
state, resizes prepared slots, clears removed slots, and applies special-ability,
icon and visibility changes. Removal after a slot-count reduction does not grow
the array again. Invalid additions fail transactionally. The I record identifies
the connection's controlled object directly, avoiding names or assumed player0.

## Native execution and actual server validation

`inspect-native-network-player-state.py` executes the original serializer:

- 198 cases in both scalar formats and builds8193.34/36/37; independent mask
  sections and combined initial state; level-up/skill count and field-width gates.
- Native known/prepared list serialization, actual feat and icon differencing,
  A/S/D action-queue difference generation, special abilities and all automap
  wire modes. Old/new icon widths include IDs above255.
- Stat/rule/build/lookup getters, coordinate translation, cache cleanup and memory
  allocation are captured fixture boundaries. These tests prove serialization
  paths, not the game rules computed by those captured getters. No AI runs.

Fixture `native-network-player-state-observations.json` is covered by focused
tests. The existing original-server v5 capture now decodes all five P/5/1
messages completely. Its caster cache contains43 known spells and34 prepared
slots, plus native feats/uses and abilities. Every truncation of a combined
native I record is rejected. Missing level-up skill ownership is reported at I.

`electron/network_peer.mjs` is a reusable main-process connection owner. Crypto,
authentication, reliable framing/ACK/reassembly, decompression and outbound game
messages are serialized independently of resource/render work. The owner has
no observation-duration shutdown and no singleplayer simulation. Only the probe
sets a finite observation deadline. Packet telemetry excludes raw authentication
bodies and secret state. Requests before admission fail without destroying the
owner; cancellation during asynchronous endpoint setup closes resources once.

Two fresh unmodified-server runs through that owner:

- `local-network-peer-v1.json`:60 received frames; server join00:05:53,
  leave00:06:09 on2026-10-18.
- `local-network-peer-v2.json`:59 received frames; server join00:07:43,
  leave00:08:00. Clean reconnect, clean raw BNDM logout, crypto helper exited.
- Both: resources ready, unchanged installed wizard admitted, area-ready sent,
 33 registered proxies, controlled object0xffffffff explicitly mapped to player0;
  all received object-update records complete. No malformed/decompression/import
  or unhandled-record errors. Other unsupported game envelopes stay diagnosed.

54 focused network/native-scalar tests PASS: `network-player-state-tests-v2.txt`.
Client build PASS: `network-player-state-build-v1.txt` (existing bundle warning).
No full-suite rerun was needed for this protocol/store change.
Credential audit:2010 source/evidence/script/test/root-note and selected capture
text files, zero full-key occurrences. Probe credentials stayed in private input.

## Remaining objective

The peer is not yet connected to Electron renderer IPC or the game UI. The
server-owned world still needs presentation/input adapters; GUI G/character
sheet/inventory records and native player requests remain to implement. Map and
queue presentation, native deletion cleanup, timing/retry/adaptive-window parity,
all shared interactions/combat/casting and actual original-client concurrency
remain open. These successful protocol runs are not playable multiplayer proof.

Post-seal checkpoint: `backups/multiplayer-player-state-20261018-v1.zip`,11979
files/195351280 bytes, every archived length/SHA256 verified. Writer47810 exited0;
all16 selected source/oracle/evidence/capture entries present, excluded executable,
object/BIC/module/credential-profile artifacts absent. This note was added after
sealing. The server remains running; no network crypto helper was left running.
