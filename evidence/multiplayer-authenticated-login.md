# Native authenticated multiplayer login — 2026-10-17

The replacement networking code completed authenticated login against the
unmodified installed NWN:EE server. `local-network-login-v3.json` and `v4.json`
record BNK1/2/3/4, encrypted BNCS/BNCR and encrypted BNVS/BNVR, no diagnostics,
and native acceptance with server build8193/revision37/postfix17. The server log
independently reports accepted community authentication, accepted key
authentication and `ReplacementTest ... Joined as Player 1` at22:14:52 and22:18:53.
These are login connections, without selected characters or replicated worlds.
The server times them out after the probe closes; graceful disconnect/reconnect
and reliable transport are not yet implemented or claimed.

## Targets and authorization

Read-only original client `../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`,
SHA256 `3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`;
original server `nwserver.exe` SHA256
`98951511ae7d06a251355f12d4f3e4b96269a2414fa3058e641afd70098690f6`.
File version89.8193.37-17; installed `bin/win32/build.txt` commit
`26c6e57364a45246e3b58e4f2c49366df72d15db` (wire prefix26c6e573).
Server PID12956, Prelude, isolated profile, localhostUDP5121.

The user explicitly authorized recording/capture and inspection of this owned
server. `inspect-runtime-platform-key.py` opens only QUERY_INFORMATION/VM_READ,
verifies executable path/hash, resolves its exported getter, verifies running
getter bytes, and reads32 bytes. It never writes process memory or prints key
bytes. No injection, binary changes or server extensions were used.

## Native evidence

- Platform ID: CAppManager::GetPlatformId1402956d0 returns2. This is a pinned
  native value; no vendor/OS interpretation is inferred.
- CConnectionLib::GetPlatformSpecificIdentifier140113ed0: secretbox empty
  payload, message ID=platform ID, context `psid` padded to8 bytes, key at
  client14140bab8. Output36 bytes converted to72 lowercase hex characters.
  ValidatePlatformSpec140114570 reverses the hex and authenticates it. Initial
  client PE storage is zero. Server exported getter RVA24a70 resolves storage
  RVAb4b198; authorized runtime observation confirms32 zero bytes and matching
  zero-filled PE virtual data. Do not confuse this shared platform-validation
  storage with the server's private cryptographic identity file.
- CAppManager constructor14003d280 assigns Windows GetTickCount to+24;
  CServerExoApp::GetApplicationId14055b2d0 returns that field. The helper captures
  GetTickCount once at startup. Probev4 uses this method rather than v3's explicit
  test application ID1. Application-wide identity ownership still needs binding
  when integrated with the real app's connection controller.
- CExoNetInternal::PacketRequiresEncryption140176360 and inline SendMessageA
  140176fa0: packets length>=4 beginning BN pass through **except** third byteC
  orV. Consequently BNCS/BNCR/BNVS/BNVR require encryption, even though their
  higher-level SendDirectMessage calls pass flags0. This corrects the earlier
  inference that raw direct-send flags implied raw login datagrams.
- NWCrypto::Initializer1402f5360 initializes PLAYER_CONTEXT to `player` padded
  to8 bytes. SendMessageA140177959..1401779d6 writes byteI, crypto identityLE32,
  and libhydrogen secretbox using tx key at ConnectionCryptoState+21 and message
  ID0 (fifth stack argument). UdpMessageArrived14017aad0 checks identity+108 and
  decrypts with rx key+1, PLAYER_CONTEXT and message ID0. Retained full receive
  pseudocode is in `rea-network-packet-receive-text.json`.
- `inspect-native-network-encryption-policy.py` executes the actual original
  predicate267 times: every possible third byte plus length/prefix boundaries.
  All outputs match the new classification. Original code remains unchanged.

## Changes and validation

`NetworkCrypto`/the C helper now generate platform tokens, provide a startup
application ID and encrypt/decrypt peer data. Session/static private keys remain
inside the helper. The pinned unmodified ISC libhydrogen revision remains
850c6bdbb0ca9a26fd105dbb6b973dc22c2dc6c0. Ciphertext is bounded to native UDP
datagram capacity. Private IPC request buffers are zeroed after pipe writes.

`installed_network_build.mjs` verifies the client hash, reads its PE file version,
platform storage (including zero-filled virtual data), and installed build commit.
Unsupported client builds are diagnosed instead of borrowing these ABI offsets.
`NetworkPacketCipher` implements the peer envelope and validates unsigned crypto
identity before decryption. Cryptographic identity and application ID remain
separate from uint32 world-object IDs; no world IDs are assigned here.

`NetworkLogin` binds exchange to native codecs and the private credential owner,
diagnoses malformed/out-of-phase/rejected responses without payloads, and exposes
the accepted remote application/build identity. Cross-realm Uint8Array/Buffer
validation fixes an actual tool-runtime probe failure while excluding other
typed-array/data views.

The local probe accepts credentials only from an in-memory caller/private stdin
pipe. The purchased key was used for the two successful logins. It was not put in
source, argv, environment, reports or configuration files. Reports retain tags,
lengths, encryption flags and acceptance metadata; no raw challenge/proof bodies.
Its owned credential buffers are disposed at exit. No JavaScript string-GC
erasure guarantee is claimed.

- v1 probe stopped before network I/O on cross-realm byte validation.
- v2 reached BNCS and timed out because it lacked the encrypted envelope.
- v3/v4 real server authenticated the complete final sequence.
- Helper buildv3 PASS; upstream compiler warnings only.
- 21 focused tests PASSv2, including prior native login/MD5/key-exchange/discovery
  fixtures,267 policy comparisons, phase/rejection/redaction, cross-realm input,
  wrong-identity envelope, platform randomness/disposal and size limits.
- Client build PASSv1, existing bundle-size warning. No full suite run.
- Source/new-capture credential audit:1941 text files checked,0 full-key
  occurrences. Focused whitespace check PASS after removing an old resume EOF
  blank line. Native server remained responsive at the verification boundary.

## Next boundary and limitations

Implement native reliable M frames, acknowledgements, sequence wraparound,
fragmentation/reassembly, compression, timers/retries and connection cleanup;
then resource/character admission, UI connection and authoritative world updates.
Research saved for FrameSend14023d1e0, Initialize140245990 and
FrameNumberBetween14023c5a0. SendBNDS250760/HandleBNDS240f30 describe server
description discovery, not reliable framing. BNDP250680/2408b0 is a disconnect
family. Do not infer their semantics from the names alone.

Observed FrameSend uses M; bytes1..2 checksum, bytes3..4 frame sequenceBE16,
bytes5..6 received sequence-minus-oneBE16, byte7 type bits4..5 and compression
bit6. It uses the owner's checksum lookup table over bytes3 onward. Control
frames allocate/zero12 bytes. These observations are a research frontier, not
implemented transport. Full original-client concurrency/gameplay remains open.
The multiplayer goal remains ACTIVE. Existing singleplayer code is unchanged.

Verified checkpoint `backups/multiplayer-authenticated-login-20261017-v1.zip`:
11713 files/183274289 bytes, every archived length/SHA256 verified. Writer85177
completed exit0. All14 required new source/capture entries present; no executable,
object/module, private server profile or credential file included. Post-seal note.
