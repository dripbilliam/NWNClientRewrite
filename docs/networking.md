# Networking and multiplayer

Original-client interoperability on unchanged original servers is the acceptance target. Protocol services remain transitional JavaScript; native Godot owns presentation and UI.

## Main owners

`electron/network_peer.mjs` owns the peer and reliable/encrypted transport. `electron/network_game_session.mjs` owns admission, requests and canonical state. `src/network_game_messages.js` decodes server messages. The native session host forwards scoped data into `native_session_world.gd`.

A sent request is not an acknowledgment. Preserve original message order, build-specific fields, bounds and failure behavior. Unsupported-message diagnostics require classification against an actual player scenario; not every protocol number is necessarily required.

World delivery includes full/delta ordering, ACKs and actor/disclosure lifetimes. Reject deltas after reset until a full snapshot has been accepted. Retired connections, catalogs and raw frames must not affect the current session.

## What is established

Encrypted original-server admission, character selection, replicated worlds and many actual action outcomes have scoped owned-server evidence. Direct-route A→B→A transfer has accepted original character downloads/uploads, arrival waypoints, fresh catalogs and native retirement. Those results do not establish every transfer or failure path.

Earlier bridge-based NUI/NWSync/recovery checks have their own scope. Do not use them as automatic acceptance of a later direct-native entry.

## Current blockers

- [NWN-14](https://linear.app/nwnanalog/issue/NWN-14): intermittent entry/reconnect disconnects and stalled world delivery. NPC, Cleric and first-snapshot failures are retained symptoms; a shared timeout owner is not proven.
- [NWN-15](https://linear.app/nwnanalog/issue/NWN-15): composed handoff semantic validation rejects the expanded character proof before comparison. The audit reproduced a 70,321-character proof against a 32,768 capture limit. This is a harness integration defect, not evidence of production character corruption.
- [NWN-16](https://linear.app/nwnanalog/issue/NWN-16): cancellation, failed destination, retry and character continuity across all direct-route transfer stages.
- [NWN-17](https://linear.app/nwnanalog/issue/NWN-17): remaining pending-work retirement and retained native fault/stall signatures.
- [NWN-55](https://linear.app/nwnanalog/issue/NWN-55): required gameplay-message coverage.

Two replacement clients do not prove compatibility with an unmodified original client. Pair both clients and compare what each sees, authoritative state, item/spell consumption, party changes and travel.

Use the normal entry, real control actions and current source pins. Preserve failed attempts; a successful retry does not explain an earlier reset. The [local parity audit](../evidence/playable-parity-audit-2026-11-09.json) has paths, exact findings and the original test commands.
