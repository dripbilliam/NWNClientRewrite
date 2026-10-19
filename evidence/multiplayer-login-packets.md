# Multiplayer login packets and credential responses

2026-10-17. Active goal: playable vanilla NWN:EE interoperability with original
clients. Prior key-exchange milestone remains verified. This section adds login
codecs and credential responses; it does not claim player admission.

## Native sources

Pinned client EE89.8193.37-17 SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Installed server SHA256
`98951511ae7d06a251355f12d4f3e4b96269a2414fa3058e641afd70098690f6`.
All addresses below are from the client/shared-code image. Evidence is retained
in `backups/animations/rea-network-*.json`.

| Owner | Address | Verified behavior |
| --- | --- | --- |
| SendBNCS | 1402502f0 | Login request, build/application/public-key/platform fields |
| SendBNCR | 14024ff50 | Password/key/community challenges, or rejection |
| HandleBNCR | 14023edf0 | Challenge ordering and mapped rejection reasons |
| SendBNVS | 140250fd0 | Conditional key/password response fields |
| SendBNVR / HandleBNVR | 140250e90 / 140243180 | Rejection or application/build acceptance metadata |
| UnScrambleKey | 14010fab0 | Extract public8 characters from41-byte formatted key |
| GetPublicPartFromCDKey | 1401141d0 | Uses that extractor; not a key-validity check |
| EncryptString | 1401664c0 | CBWCMD5 then lowercase32-character hex |
| CBWCMD5 Encrypt / EncryptBlock | 140112f90 / 140113130 | Original digest and padding/rounds executed |
| GenerateCommunityNameResponse | 140109b80 | MD5(MD5(community password)+challenge) |
| GetPlatformId | 1402956d0 | Returns2 in this installed build |

BNCS starts with port LE16+4, connection type BYTE+6, build INT+7,
constant WORD3+11, language BYTE+13, application DWORD+14, then BYTE-length
name/public-key/legacy-public-key, platform BYTE, BYTE-length platform identity,
revision INT, BYTE-length commit, postfix INT. The application field is
**CBaseExoApp::GetApplicationId**, virtual+78, not a world object or player ID.
The initial request carries the public key identifier, not the full CD key.

At **14023f3cc..14023f406**, assembly confirms the key proof order:
public8 + MD5(full canonical CD key + key challenge). At **140109be8**,
**140109c32**, **140109c7e**, assembly confirms the two community hashes and
concatenation order; **14023f4ba** supplies password/challenge as R8/R9.
Password proof is MD5(server password+password challenge). Missing required
password sets native error3 and still constructs the passwordless BNVS form.
CExoString operator+14016ab00 was read from retained REA evidence; it copies
explicit byte lengths, retaining embedded NUL, matching the captured storage.

## Implementation and bounds

`src/network_login_packets.js`: BNCS/BNVS writers and BNCR/BNVR readers.
It preserves unsigned application IDs, explicit CP1252 lengths, native leading
NUL assignment for received strings, rejection mapping, password branches,
trailing BNCR-byte visibility, and legacy BNVR build omissions. Unsupported
types/statuses, truncated required fields, missing inputs and >255-byte strings
throw explicit errors. Unsafe native out-of-bounds reads/length overflows are
diagnosed instead of fabricated. These are pure codecs; a transport caller
must catch/report errors and handle all login/session lifecycle decisions.

`electron/network_login_identity.mjs`: public-key extraction and main-process
challenge responses. Canonical key casing follows native key-validation input
normalization. Private key/password buffers are not enumerable or serialized;
disposal zeros owned buffers, and encoding errors omit offending secret text.
Public-key extraction is not a CRC/license validation claim. Server authorization
is still required. The provided real client key was not used, written, or added
to any oracle/capture. Tests use explicitly synthetic credentials.

## Verification

- `inspect-native-network-login-packets.py`:32 actual BNCS/BNCR/BNVS/BNVR writer
  cases, with captured platform/application/RNG/allocation/send boundaries.
  Encoded requests/responses match their recorded native outputs.
- `inspect-native-network-login-identity.py`:21 original MD5 round/padding cases,
  including55/56/63/64/119/120-byte and multi-block boundaries;6 whole original
  public extraction cases;5 original community coordinator cases with captured
  lower digest/string storage. Separate original MD5 cases verify the digest.
- `network-login-identity-tests-v2.txt`:16 focused tests PASS, including previous
  handshake/discovery tests, malformed packets, legacy responses, disposal,
  redaction and missing-password behavior.
- `network-login-client-build-v1.txt`:build PASS, existing bundle-size warning.
  No full suite run.
- `local-network-handshake-v3.json`:fresh real-server BNK1/2/3/4 exchange PASS,
  expected public identity verified, no diagnostics. Native server PID12956
  remained running on127.0.0.1:5121. This fresh check stops before login.

The two native observation JSONs are allowlisted for checkpoints. No executable,
credential file, server private identity or proprietary game asset is added.

## Next required work

Bind the codecs/credential owner into the actual connection state machine;
complete platform identity generation and its native validation; then perform
real BNCS/BNCR/BNVS/BNVR admission, including rejection and cleanup paths.
Reliable encrypted transport, retries/timeouts, resource/character admission,
replication and playable multiplayer remain incomplete.

Native platform owners are saved/read: GetPlatformSpecificIdentifier113ed0,
GetPlatformSpecificIdentifierKey114060, ValidatePlatformSpec114570. The target
generates a hex libhydrogen secretbox for an empty platform payload, context
`psid`, message ID2, using storage14140bab8. Static initial32 bytes are zero;
that alone is not proof of runtime initialization/portability, and no guessed
platform field was sent. Incoming-reference evidence is saved. The real binary
file version is89.8193.37-17; build.txt contains the full build commit. Use those
installed inputs when binding metadata rather than hardcoding the probe server.

Verified checkpoint `backups/multiplayer-login-codecs-20261017-v1.zip`:
11669 files/182128831 bytes, every archived length/SHA256 verified. Writer53425
completed exit0; required source/native evidence present and executable,
object/module, private server profile and credential-file exclusions PASS.
This seal note was added after verification.
