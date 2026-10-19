# Reliable frames and first server application data — 2026-10-17

The replacement probe now exchanges encrypted M frames with the unmodified
local server, acknowledges real server data, assembles native message records,
decodes a module-clock update, sends an application request and receives its
module-resource reply, and disconnects cleanly. Immediate back-to-back
authenticated reconnects succeed. Character selection/admission, replicated
gameplay and original-client concurrency remain open; the goal remains ACTIVE.

## Target and evidence

Same read-only installed client89.8193.37-17, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`,
and original server SHA256
`98951511ae7d06a251355f12d4f3e4b96269a2414fa3058e641afd70098690f6`.
Owned server PID12956, Prelude, UDP127.0.0.1:5121. User authorized captures and
read-only runtime inspection; original processes/binaries remain unmodified.

- Constructor1402381c0 creates256 reflected CRC32 entries with polynomial
  edb88320. FrameSend14023d1e0 starts CRC at0, with no final xor, over bytes3
  onward, storing low16 bits BE at1..2. Assembly14023da68 confirms the zero
  register seed, avoiding decompiler variable-reuse ambiguity.
- M header: sequenceBE16 at3, cumulative acknowledgementBE16 at5 (expected
  receive sequence minus1), kind bits4..5 ofbyte7:0 data,1 ACK,2 NAK.
  Compression capability bit6 and priority bit3 are distinct from per-message
  compressed bit2. Control frames zero12 bytes. Data headers preserve other bits.
- FrameNumberBetween14023c5a0 uses a cyclic inclusive-start/exclusive-end
  interval. Initialize140245990 starts send/receive sequence0 and16 slots;
  outgoing resend3500ms, ACK/keepalive2000ms, initial NAK permission1.
- FrameReceive14023c5d0 queues each in-window sequence once, sends at most one
  NAK until ordered delivery resumes, drains contiguous buffered data across
  65535->0, independently queues high/low delivery, cumulatively retires only
  acknowledgements inside the outstanding interval, and resends ACK+1 for NAK.
  Out-of-window/stale/future ACK handling is covered by original-code cases.
- UnpacketizeFullMessages1402566d0 uses separate priority queues. CountBE16 at8
  equals1 for packed records; lengthsBE16 at10 (extended high bytes12/13 ifbit7)
  delimit records. Count>1 concatenates the first full header and each subsequent
  payload after12 bytes. Incomplete groups remain queued. UncompressMessage
  140255c80 strips12 bytes for uncompressed application data. Compressed bit2
  selects zlib; bit0 selects window-owned persistent inflate, with LE32 output
  size at12 and maximum20MiB. Compression remains an explicit unimplemented
  probe boundary, recorded if encountered.
- DisconnectFromSession140239f60 calls SendBNDMMessage1402505b0, which emits
  exactly `BNDM`, then clears native crypto state. HandleBNDM140240750 finds
  the peer, releases player/window state and invokes application disconnect.
  The existing lower packet predicate intentionally permits raw BNDM. The probe
  waits for UDP send completion and resets/closes its private crypto helper.
- Original module-clock sender1404dcb50 emits game prefixP/major3/minor3 and
  mask-dependent time-of-day, transitionDWORD, hour/day/month BYTEs, yearDWORD.
  Existing independently verified CNWMessage byte/bit reader decodes the fields;
  this imports server changes without starting local calendar/AI simulation.

## Native oracles and implementation

`inspect-native-network-frames.py` executes unchanged constructor CRC generation,
FrameSend, FrameNumberBetween, FrameReceive, UnpacketizeFullMessages and BNDM
writer. Allocation/storage/delivery enqueue/timer/send/cleanup are documented
captured boundaries. It records6 actual sends,343 interval cases,11 receive
scenarios (including multiple ordered steps),5 message-assembly scenarios and
the disconnect packet. Native outgoing small/fragmented packetization is also
executed for6 payload lengths3/947/948/949/1896/1897; all headers/boundary splits
match the new generic packetizer. It does not prove full storage ownership,
compression, queue scheduling or timer orchestration. Initial oracle attempts
identified timer/cleanup boundaries and corrected captured inactive peer IDs
and per-case buffer initialization; finalv9 succeeds.

`inspect-native-network-module-time.py` executes the original clock coordinator
and scalar writers for96 mask/time-of-day combinations, including high unsigned
year and transition values. Only the final send boundary is captured; envelope
assignment has separate original-code coverage in the existing send oracle.

New `network_frames.js`, `network_window.js`, `network_messages.js`, and
`network_game_messages.js` implement those boundaries. Input ownership is copied;
corrupt/truncated/unsupported frames are diagnosed before window mutation.
Oversized/truncated packed records and orphan continuation frames are diagnosed
instead of reproducing unsafe native reads. The probe serializes receive/poll
crypto operations and records unsupported application messages explicitly.

Known differences/open work: outgoing frames currently enter the window
immediately rather than passing through native500ms FauxNagle coalescing;
adaptive16->smaller window sizing, native timer wrap behavior, connection expiry,
loss/retry login scheduling, compression and packed-message coalescing remain
open. Generic outgoing uncompressed948-byte fragmentation is verified; broad
outgoing gameplay-message codecs remain open. The fixed initial receive16-slot
behavior and core ACK/NAK rules are verified, not a complete reliable-transport
claim. Production UI/app-wide connection ownership is still unbound.

## Real-server validation

- `local-network-transport-v1.json`: authenticated login, encrypted keepalive
  both ways, one real27-byte data frame and outgoing cumulative ACK0.
  Application assembly was not bound yet and was recorded as unsupported.
- v2: a rapid retry was rejected with native error9 while v1 remained active.
  The server subsequently logged timeout/leave; no restart/bypass was used.
- v3: fresh login/keepalives pass; no data during its7-second observation.
- v4:20-second exchange received10 frames, including a real22-byte data frame,
  acknowledged it, captured only authorized post-login application data, then
  sent BNDM. Server log at22:35:00 independently confirms immediate player leave
  and0 players; it no longer waits for the60-second timeout. Captured record
  decodes to module-time mask2/hour14 through the final assembler/reader test.
- v5: the assembled-message-enabled probe ran10 seconds with5 received frames,
  no application data during that interval, no diagnostics and clean BNDM leave
  confirmed at22:38:12. No absent-data result is treated as a decoded-message run.
- v6/v7: two immediately consecutive login/logout attempts both accepted, no
  diagnostics/error9; server logs show both joins and leaves at22:39:38. Each
  sends BNDM and zeros its helper state; no timeout wait between attempts.

- v8: first outgoing application frame was acknowledged, but the application
  request had no response. Inspection of458b90 proved requests require lowercase
  p; uppercase P is server-to-client. No acceptance claim was inferred from its
  transport ACK alone.
- v9: corrected lowercase-p/major1/minor0 empty server-status request is ACKed
  and returns native P/major1/minor3 module-resource message,28 application bytes.
  It is recorded as `network.game-message-unhandled` pending schema import;
  no module/resource names are fabricated or automatically accepted. Clean BNDM
  teardown still succeeds. This probes the verified status handler, without
  claiming the complete original client's starting sequence.

`network-transport-tests-v4.txt`:29 focused tests PASS, including prior network
auth/discovery and new frame/interval/receive/assembly/clock/disconnect cases.
Additional256 checksum vectors use the actual native-constructed table as their
reference. `network-transport-client-build-v2.txt`:build PASS, existing chunk-size
warning. No full suite run. Server remained responsive and original code read-only.
The dedicated license is passed only in a private input pipe/in-memory owner;
auth bodies and full keys are absent from reports/source/config/argv.
Fresh source/capture audit:1960 files checked,0 full-key occurrences.

## Next admission boundary

Read native client initial application request and production connection state
before sending guessed messages. Server dispatch140458b90 routes major1 to
HandlePlayerToServerServerStatusMessage14045d140, major2 to login140457850,
major3 to module140459760. Saved login handler reads resource references for
subtypes2/14/17, BIC byte blobs for1/4/19, subtype15 checks NeedCharacter versus
existing player state, subtype11 confirms LoadCharacterFinish. These are server
branches, not proof of the original client's starting sequence. Character-query
sender4dbf50 and module/status/admission owners are saved for the next pass.
Status response sender4df850 in server mode2 writes an empty CExoString then
CNWSModule::PackModuleResourcesIntoMessage483040. That owner writes NWSync
advertisement, strings at native module offsets88/450 and conditional hak resrefs
from148/count150. Its pseudocode is saved/read; NWSync encoding and semantic
field names still need verification before adding a generic manifest decoder.

Verified checkpoint `backups/multiplayer-reliable-frames-20261017-v1.zip`:
11784 files/188246656 bytes, every archived length/SHA256 verified. Writer97192
completed exit0. All16 required new source/evidence/report entries present;
executable/object/module, private server profile and credential-file exclusions
PASS. This seal note was added after verification. Goal remains ACTIVE.
