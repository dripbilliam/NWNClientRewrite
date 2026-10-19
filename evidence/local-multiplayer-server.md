# Installed local multiplayer server and discovery

2026-10-17. User requested starting the local installed server and beginning
multiplayer work. The spell/combat/campaign goal remains incomplete; this is
the initial connection research, not a claim of networked gameplay.

## Native test target

- Executable: `../FullDecomp/NwnRootInstall/bin/win32/nwserver.exe`.
- SHA256: `98951511ae7d06a251355f12d4f3e4b96269a2414fa3058e641afd70098690f6`.
- Profile: `runtime-logs/local-multiplayer-server`, separate from normal user data.
- Module: installed `Prelude.nwm`; original and server-generated currentgame
  copy both SHA256 `3daae6b779197cd71a202d87a06bd9c5b2362d3957067490562ea32740d5adb8`.
- Started PID12956 at local21:15:20; UDP5121 verified owned by that process.
  PID is an observation, not a fixed configuration.
- Name `Replacement Client Compatibility`, max2 clients, local vault.
  Public listing and relay connections disabled; NAT punching disabled for this
  launch. The socket binds all IPv4 interfaces, so the loopback address is the
  intended test endpoint, not an assertion of a loopback-only bind.
- Runtime logs confirm loading Prelude and the masterserver advisory
  `Server hidden: Requested not to be listed.` An undefined-alias warning and
  an empty GFF field-label error were also observed on startup. They have not
  been diagnosed or suppressed; successful queries do not prove gameplay.

No CD key is required for these server queries. The supplied client key was
not written into source, profile, logs or captures. The native server generated
its own cryptographic secret in its ignored runtime profile. That profile,
its runtime module copy and secret are excluded from research checkpoints.

## Static evidence and live validation

Shared native protocol owners were examined in the pinned **client** executable,
SHA256 `3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
These addresses belong to nwmain, not nwserver:

| Owner | Address | Observed wire behavior |
| --- | --- | --- |
| SendBNESDirectMessageToAddress | 1402507f0 | BNES, LE16 local UDP port, section byte;7 bytes |
| HandleBNESMessage | 1402419c0 | Accepts >=7 bytes; returns BNER marker55, server port, echoed section, BYTE-length server name |
| HandleBNERMessage | 140241420 | >=9 bytes; section<=5, name length checked; requests extended info |
| RequestExtendedServerInfo | 14024fac0 | BNXI prefix+LE16 local port; full native client appends identity/build fields |
| HandleBNXIMessage | 140244230 | Accepts >=6 bytes; emits BNXR versionfd and server/module/NWSync/build metadata |
| HandleBNXRMessage | 140244ad0 | Admits versionfd; imports server rules, module and advertisement |

Raw REA procedure evidence is saved as `rea-network-*.json` in
`backups/animations`. Original-code pseudocode/assembly were inspected; the
query codec is independently validated against the **running original server**,
not an emulated replacement server. No native emulation oracle is claimed here.

`src/server_discovery.js` builds discovery and minimal accepted info queries,
decodes fixed rule fields/names and retains the remaining advertisement bytes.
The six-byte info request is suitable for unauthenticated inspection; it does
not reproduce the full native client's identity-bearing query. Names use the
project's Western NWN byte decoder and native leading-NUL assignment semantics.
Unknown packet types/versions and truncated fixed fields/names throw precise
errors. Advertisement decoding/negotiation is explicitly still open.

`backups/animations/local-server-query-v1.json` captures both accepted requests
and original responses. They confirm server name, port5121, modulePrelude,
levels1..40, players0/2, localvault, PVP1, oneparty1, ELC1, ILR0, no password.

Validation: `local-server-query-tests-v1.txt`:3 focused tests PASS, including
every truncated fixed/name prefix of the actual responses, invalid sections,
unknown version/type, and CP1252/NUL strings. `local-server-build-v1.txt`:build
PASS; existing bundle-size warning. PowerShell launcher syntax PASS. No full
suite run. Probe errors/timeouts are saved in their output report.

## Reproduction

```powershell
./scripts/local-multiplayer-server.ps1 -Action Start
./scripts/local-multiplayer-server.ps1 -Action Status
node scripts/probe-local-multiplayer-server.mjs
# Only when explicitly finished with this test server:
./scripts/local-multiplayer-server.ps1 -Action Stop
```

Process inspection/start can require the tool's elevated Windows execution
context. Start validates the original server digest, rejects an occupied UDP
port/duplicate profile, and runs hidden. Stop targets only the matching
executable and quoted test-profile argument. No game binaries are changed.

## Next connection owners and limits

StartConnectToSession140254ed0 was inspected. Remote connections begin with
`hydro_kx_xx_1` and a36-byte `BNK1` key-exchange packet, before the BNCS/BNCR and
BNVS/BNVR login exchange. The other branch uses the `_SINGLEPLAYER` sentinel
and direct in-process state; this is not evidence that remote multiplayer can
skip key exchange just because the destination is127.0.0.1.
HandleBNCS14023f640 and HandleBNCR14023edf0 analyses are saved, but their complete
validation, identity rules and error/lifecycle paths are not yet ported.

Remaining: cryptographic handshake and session identity/key handling, reliable
transport, resource negotiation, character admission, server-owned object
creation/destruction and movement updates. The replacement UI is not connected
to this query codec or the native server yet. Its existing ModuleSession still
runs local AI/scripts/combat; a multiplayer session must consume server authority.

Verified checkpoint `backups/local-multiplayer-query-20261017-v1.zip`:
11585 files/178346199 bytes; every archived length/SHA256 verified. The archive
writer session26350 completed with exit0. This seal note and the clarification
of the `_SINGLEPLAYER` branch were added after sealing.
