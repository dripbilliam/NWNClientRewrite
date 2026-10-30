# Native control identity during loading

2026-10-27. Read-only original NWN:EE 89.8193.37-17 x64, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`,
rechecked against the installed executable. Evidence projection:
`../backups/animations/rea-loading-control-identity-v1.json`.

## Observed original behavior

Server `SendServerToPlayerGameObjUpdate_ObjControl` 0x1404d9b90..1404d9c2c
writes the recipient PLAYER_ID DWORD at 0x1404d9bc6 and client OBJECT_ID via
the original writer at 0x1404d9bd0; send at 0x1404d9c18 is private P/5/2.
The two identities are separate namespaces.

Receiver dispatcher 0x14079bce0..14079bfc8 subtype2 reads those fields, checks
overflow/underflow, and calls 0x140781380. That complete receiver first obtains
the previous controlled creature, then calls 0x1406acc50 unconditionally with
the transmitted OBJECT_ID before looking up the new creature. The setter's
complete assembly is MOV RAX,[RCX+8]; MOV [RAX+48],EDX; RET.
Getter 0x1406ac1a0 delegates to 0x1406d8ad0, which uses that same field48 for
the creature lookup through 0x1406ab9e0. Thus storing the ID does not require
that its creature proxy or geometry already exists.

Party receiver 0x1407a7440..1407a77f9 subtype14 reads the same scalar pair but
updates an existing player's field34 only. It does not call the local-ID setter.
Exact instruction/call addresses and complete recovered bodies are in the
saved projection. Pseudocode is decompiler evidence, not original source or a
complete runtime oracle. The large CC dispatcher 0x140770c80 and I-record
handler 0x1407b4f70 did not return usable dossiers in this investigation; no
claim about their complete behavior follows from those failed requests.

## Port correction and validation

Previously `NetworkWorld` treated both envelopes solely as roster-map updates.
It now also sets localObjectId immediately for exactly major5/minor2, clearing
old script targeting only when identity changes. Party14/14, player-list changes
and messages without the explicit 5/2 envelope cannot steal local control.
No new proxy, appearance, ownership, gameplay result or readiness is fabricated.
Input still requires a real current-area, nonremoved creature and the existing
session/generation/area-ready gates. Existing player-state updates remain intact.

`reports/native-loading-control-identity-tests-v3.txt`: 61 tests pass, including
wire high-ID/invalid-ID boundaries, missing/current/wrong-area proxies, unchanged
repeat targeting, transfer invalidation, party/list isolation, malformed packet
rollback and existing captured native area/player-state/session/vault cases.
These are port execution and existing oracle regressions, not new PE execution.
The first new fixture incorrectly used format0 with the format1 envelope decoder;
it was corrected to the actual format1 contract. An unprivileged suite then
could not read its installed module fixture; the read-authorized repeat passed.

`reports/native-loading-control-identity-local-v1.json`: owned unchanged Prelude
127.0.0.1:5121 loading check passes, no public connections or native exception,
engine exits0. This is loading only, not a new combat/door/possession acceptance.
The original receiver's conditional GUI update/14/2 response is outside this
identity correction; full possession/GUI acknowledgment parity is not claimed.

## Performance limit

The sealed loading recording contains already-adapted world frames, not every
original incoming envelope. It cannot establish whether 5/2 arrived before the
first I/player-state record. Initial-entry timing benefit is therefore unproven.
The observed first-area creature exists roughly411 ms before the adapted control
ID becomes valid, but inferring ownership from proximity/name remains rejected.
This fix follows explicit original server authority and is not a substitute for
reducing the remaining approximately3-second cold model preparation.
