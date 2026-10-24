# Server portal handoff

Target: immutable NWN:EE89.8193.37-17 x64 `nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.

## Observation and native evidence

The replacement runtime log starting2026-10-21T09:38:59.552Z records an
unhandled42/1,44-byte message at09:41:07.783Z (04:41Winnipeg). No corresponding
disconnect/timeout is recorded. The log retains envelope metadata, not its
destination/password/body; the actual requested endpoint cannot be recovered
from that log.

Read-only native analysis identifies master receiver1407a41a0 case42 ->
1407aa550 ->1407aa6a0. The latter identifies itself in its warning string as
HandleServerToPlayerPortalActivatePortal. It reads three CExoStrings and BOOL,
calling portal controller1408422d0 at1407aa905. The controller splits host/port
(default5121), stores password, waypoint and seamless state, and starts address
translation. Native AIUpdate is140841b70 (the initial request used an interior
address140841ca0). It enumerates the destination, then140842910 requests a
character via1407ba520: **outgoing43/1**, not42/2.

Server handler140444c70 chooses character download reply1404d23a0 or
1404d21d0. Despite the latter's exported name containing `Fail`, it calls
SaveServerCharacter1404bd740 at1404d2222, then sends43/3 containing the saved
reference and account-vault BOOL. Reply43/2 contains localized names and the
packed BIC. Client14077b270 stores either reply through1406ac7c0 ->1406df390.
Getter1406ab920 returns downloaded **size**, not a disconnect/error reason.
AIUpdate state4 initiates DisconnectFromSession after a download is ready.
Waiting for an unsolicited BNDP would stall. The subsequent login callback
140842c60 uses server reference source2/17 or uploads the local blob;
1407c2130 verifies the reference/source packet. Controller140843aa0 gives an
empty seamless waypoint the native `*PAUL_WAS_HERE*` sentinel. The existing
2/12 waypoint request /2/13 response then conveys that tag to the destination.

REA captures: `backups/animations/rea-portal-*.json`. No original process was
modified, and no public server was joined or controlled for this patch.

## Replacement implementation

`network_portal.js` validates/decodes42/1 and43/2/3. Only the main-process
transfer owner receives portal passwords/BICs. It prepares a fresh installed
session, requests the old character, disconnects after its authoritative reply,
then lets the IPC owner start the destination session. The identity forks its
key/community identity privately and uses the portal password for the new
challenge. No old-server public-key pin is reused for a different endpoint.

The destination has a new peer, crypto state, resource resolver, rules, world,
NUI state and renderer session ID. Cached content remains reusable by hash;
active resource state is not carried across servers. A fresh session ID rejects
old requests and asynchronous renderer work even when object IDs collide.
Server-vault references bypass the character picker; local BICs upload through
the existing native character path. Waypoint handling stays server driven.
Cancellation, preparation failure, missing download, transport failure and a
15-second handoff deadline dispose the prepared destination and diagnose failure.

## Validation and limits

`scripts/inspect-native-network-portal.py` executes the original42/1 sender and
parser unchanged for16 combinations, verifies the original43/1 request, and
executes the original43/3 sender/receiver for4 terminated reference/vault cases.
SaveServerCharacter and actual transport are captured lower boundaries; this
does not perform real server saves. A full16-character reference exposed an
unterminated native stack-tail issue in this synthetic sender fixture; it is
excluded from that oracle. The replacement validates up to16 encoded bytes.
Artifacts: `native-network-portal-v1.json`, successful run-v4; earlier runs-v2/v3
retain the failed full-width-reference assertions rather than hiding them.

`test/network-portal.test.js` checks those native cases, truncation, malformed
fields, download-before-disconnect, duplicate commands, password isolation,
resource/world/NUI replacement, server-reference admission, local BIC zeroing,
waypoint response, cancellation, timeout and frontend queue ownership.
`test/network-ipc.test.js` also checks ID rotation and late/cancelled handoffs.
The focused portal/session/IPC/runtime/identity/area/targeting set passes93/93
(`network-portal-focused-v2.txt`). Its initial sandboxed run-v1 was92/93 because
the installed Prelude assets were unreadable; the read-only permitted rerun
passes. Production build passes (`network-portal-build-v1.txt`), bundle
`index-DDeHs4J-.js` / `index-8ID_vg9F.css`. The running client was not restarted.
This is offline/native-code validation, not a live Arelith transfer result.
Native relay/NAT rendezvous and the original nonseamless confirmation dialog
are not reproduced here; reachable IPv4/DNS destinations use the existing
direct connection flow. A live Arelith handoff remains to be checked after
restarting the replacement client.
