# Remote multiplayer key exchange

2026-10-17. The goal API accepted the new vanilla-server/original-client
interoperability objective after the user ended/saved the prior goal.
This is a connection milestone; multiplayer gameplay remains incomplete.

## Binary evidence

Client EE89.8193.37-17 SHA256:
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Installed server SHA256:
`98951511ae7d06a251355f12d4f3e4b96269a2414fa3058e641afd70098690f6`.
Addresses below belong to the client/shared networking code, independently
checked against the running original server:

| Owner | Address | Behavior |
| --- | --- | --- |
| StartConnectToSession | 140254ed0 | Remote hydro_kx_xx_1,36-byte BNK1, stage1 |
| HandleBNK0 | 140241c30 | >=4 bytes, reset only before stage3, client error13 |
| HandleBNK1 | 140241da0 | Accept36 bytes; server sends84-byte BNK2 |
| HandleBNK2 | 140242320 | Exactly84 bytes/stage<3; authenticate/pin server, stage3/keys flag, send52-byte BNK3 |
| HandleBNK3 | 140242890 | Accept52 bytes; authenticate client, create crypto identity, send8-byte BNK4 |
| HandleBNK4 | 140242c60 | Exactly8 bytes/keys/stage>=3/identity0; store DWORD identity and dispatch BNCS |
| SendBNKAnyMessage | 140250c30 | BNK0..4 wrappers; reset clears10c bytes |

At **1402424e9**, assembly confirms all seven hydro_kx_xx_3 arguments:
state, session keys, packet3, peer public key, packet2 on stack+20, nullPSK+28,
local static keypair+30. The shortened decompiler signature omitted trailing
arguments. At **14024212e**, assembly confirms hydro_kx_xx_2's static keypair+20.

ConnectionCryptoState: key-present BYTE+0, rx32 bytes+1, tx32 bytes+21,
stage INT+44,160-byte XX state+48, peer public key32 bytes+e8, crypto identity
DWORD+108. **Crypto identity is neither a world object ID nor a player ID.**
No world-object allocation/remapping occurs here.

Raw REA procedure/assembly evidence: `backups/animations/rea-network-*.json`.
BNCS/BNCR and lower encryption analyses are saved for the next milestone;
those complete paths are not implemented.

## Implementation

`src/network_key_exchange.js` implements client BNK state/length guards,
reset/error13, optional server public-key pinning, diagnostics, and unsigned
crypto identity. BNK4 emits `readyForLogin`; BNCS remains a separate owner.

`electron/network_crypto.mjs` runs a hidden, pipe-only helper built from
`scripts/native/nwn_network_crypto.c` plus unchanged ISC libhydrogen source
already at `references/libhydrogen`, revision
`850c6bdbb0ca9a26fd105dbb6b973dc22c2dc6c0`. Build refuses modified source.
No game binary is loaded/patched/injected into. Windows secure random seeds
the library. Private static/session keys stay in the helper. Only public
exchange packets and server public identity cross its pipes. EOF clears
private state; a stuck helper is terminated after500ms.

The helper currently generates a transient static identity per process.
Persistent client identity and payload encrypt/decrypt remain open. The
supplied CD key is not used/persisted. No private session key is written to
source/logs/captures. Compiled helper/objects and server profile are ignored
and excluded from checkpoints; helper C source is included. The ISC license
is retained in the reference and copied beside the built helper.

## Validation

`inspect-native-network-key-exchange.py` executes original BNK0/2/4 machine
code with captured crypto-provider, peer-lookup, log and send boundaries.
34 cases cover lengths/stages0..4/null peer/crypto failure/missing keys/prior
identity/high and zero IDs. These are wrapper tests, not primitive crypto
oracles. `native-network-key-exchange-observations.json` records all34.

Focused tests compare31 present-peer cases against replacement state, errors,
unsigned identity and outgoing dispatch. Three null-peer native cases exercise
a separate transport lookup not implemented yet. Additional tests exercise
pin mismatch/reset and the compiled helper's rejection/restart/EOF lifecycle.
`network-key-exchange-tests-v1.txt`:6 tests PASS including discovery tests.
`network-crypto-build-v5.txt`:helper build PASS; compiler warnings are upstream
unsigned arithmetic/constants, none in the helper. Visual Studio registration
reports incomplete, but its actual compiler/SDK work; no installation changes.
`network-handshake-client-build-v1.txt`:client build PASS with existing
bundle-size warning. No full suite run.
`network-key-exchange-tests-v2.txt`:7 tests PASS, including default runtime
diagnostic retention with packet payloads omitted from records. Finalv3 adds
public-key Buffer ownership coverage:8 tests PASS. Pinned/accepted public keys
are copied so caller/provider buffer reuse cannot alter connection identity.

`local-network-handshake-v1.json` and `v2.json` independently complete actual
secure-random exchanges with the installed original server, verifying its
advertised public identity:

```text
client BNK1 (36 bytes) -> original server
client <- BNK2 (84 bytes)
client BNK3 (52 bytes) -> original server
client <- BNK4 (8 bytes)
```

Crypto IDs differ across exchanges. No CD key, BNCS login, character admission
or world state is involved. Server remainsPrelude/127.0.0.1:5121 with0/2 players.

```powershell
./scripts/build-network-crypto.ps1
node --test test/network-key-exchange-native.test.js test/server-discovery.test.js
node scripts/probe-local-network-handshake.mjs
```

The probe only targets the owned local server and reads its public identity
from the startup log, never the private secret file. Reports retain only
tags/lengths, public identity, connection identity and diagnostics.

Next: actual BNCS/BNCR/BNVS/BNVR login with native build/platform identity and
rejection lifecycle, then reliable encrypted transport and character/resource
admission. Actual shared gameplay remains required to complete the new goal.

Initial checkpoint `multiplayer-key-exchange-20261017-v1.zip` sealed11617
files/180347425 bytes; writer60359 exit0, every file length/SHA256 verified.
Default diagnostic retention was added and retested after that seal.
Final checkpoint `multiplayer-key-exchange-20261017-v3.zip`:11621 files,
180350544 bytes. Writer43632 completed exit0; every archived length/SHA256
verified. Required C/JS/oracle sources are present; no executable/object/module,
CD-key file, private crypto secret or local server profile is included.
This seal note was added after verification.
