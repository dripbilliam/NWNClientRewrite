# Native scalar message codec and send envelope

Target NWN:EE `89.8193.37-17`, unchanged read-only original
`../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Evidence: Ghidra names/callers, full instruction ranges and isolated Unicorn
executions. No binary/asset copies, Ghidra edits, process changes or real sends.
The full spell/combat/campaign goal remains active.

## Implemented owners

`src/native_message.js` supplies NativeMessageWriter, NativeMessageReader,
NativeServerMessage and SendServerToPlayerMessage. `nativeMessageProviders`
connects scalar/encoding/send owners to the decoded ClientArea coordinator;
area packing and transport remain separate required lower owners.

| Owner | Original address |
| --- | --- |
| CNWMessage ctor / CreateWriteMessage / GetWriteMessage | 1402d4830 /1402d54a0 /1402d5880 |
| Extend byte / bit buffers | 1402d5650 /1402d56b0 |
| WriteType / Unsigned / Signed / Bit | 1402db8f0 /1402db990 /1402db870 /1402daaa0 |
| WriteBOOL / BYTE / WORD / DWORD / INT / FLOAT | 1402da920 /1402da960 /1402dbcd0 /1402db150 /1402db5a0 /1402db240 |
| SetReadMessage / ExpectType | 1402da7b0 /1402d5560 |
| ReadUnsigned / Signed / Bits / Bit | 1402da210 /1402da1a0 /1402d9700 /1402d96b0 |
| ReadBOOL / BYTE / WORD / DWORD / DWORD64 / INT | 1402d9600 /1402d9630 /1402da450 /1402d9bc0 /1402d9b50 /1402d9ec0 |
| ReadFLOAT scale / range | 1402d9c30 /1402d9d40 |
| ReadOverflow / Underflow | 1402d9460 /1402d9520 |
| CNWSMessage ctor / SendServerToPlayerMessage | 140442e10 /1404dc490 |

Full assembly captures in backups/animations: native-message-writer-core-asm,
native-message-reader-core-asm, native-message-reader-core-asm-v2,
native-message-reader-wrappers-asm and native-server-message-send-asm.txt.
The first reader assembly request stopped at the non-unwind leaf; v2 uses its
verified reachable CFG and captures the remaining owners. Full send range is
1404dc490..1404dcb46: EAX is restored from EBX after free at1404dcb30, contrary
to a misleading truncated decompile. Tests retain this raw result and cleanup.

## Layout and error semantics

CreateWriteMessage starts byte storage at7, reserving3 envelope bytes and4
split-boundary bytes; it reserves3 bits in a separate residual stream. Natural
integers use little-endian raw byte storage. General unsigned widths consume
high-order DWORD/WORD/BYTE chunks then low residual bits MSB first. UINT64 is
raw little-endian64. Reduced signed values use sign/magnitude; INT32 is raw.
BOOL emits the input's low bit:2 encodes0. ReadBYTE clamps widths to8;
reduced ReadDWORD64 returns low32, matching the original wrappers.

App global field28==0 enables type tags; other modes omit them. Its semantic
meaning remains unmapped; the API requires explicit `formatMode28`. Tags are
1 residual,2 BOOL,3 BYTE,5 WORD,7 DWORD,8 INT,9 UINT64,11 FLOAT. ExpectType
consumes a byte, diagnoses mismatches, and continues without an invented latch.

GetWriteMessage stores byte-stream length at packet+3, appends residual data,
and encodes final bit count in the first3 reserved bits. Native heap storage
does not initialize the envelope or unused final padding. Defined-bit masks
distinguish serialized bytes from unknown storage. Fixtures inject known A5
heap bytes for exact allocation/copy comparisons; production does not claim
these are actual game heap contents. Growth/counters/reuse/repeated Get match.

SetReadMessage takes the packet **after its three-byte envelope**, subtracts3
from the split boundary, and preserves original old-state behavior on empty
or rejected setup. Truncation advances the original cursors and returns zero.
Overflow compares byte/fragment cursors; underflow also examines final bits
with native unsigned math. Negative signed zero returns INT64 minimum.

Residual readers permit cursor==declared size and may attempt one further
physical byte. Fixtures supply known physical tails separately from declared
lengths. An unavailable production physical byte records `unknownPhysicalByte`
and throws; arbitrary native heap contents/memory faults are not fabricated.
This guard is an explicit limit beyond known packet storage.

FLOAT scale1/width32 uses raw f32. Quantized writing multiplies in f32,
truncates to signed64, then takes low32; out-of-range products yield low32 zero.
Scale reads divide low32 unsigned in double before f32 conversion. Range reads
preserve the native f32 step/double multiply-add order. Finite negative/large
inputs and zero scales are compared. All NaN payload identities/nonfinite
combinations are not established.

## Send and installed integration

CNWSMessage ctor sets role68=1. SendServerToPlayerMessage resolves names and
logs before all payload gates. Nonnull data is stamped `[80,major,minor]`;
the server virtual+38 accessor supplies CNetLayer::SendMessageToPlayer140237b30,
with unchanged PLAYER_ID and flag0. Length0 allocates3, changes message+64
to0xffffffff, sends/frees that temporary buffer. Null nonempty data or failed
allocation returns0. The raw signed32 transport result survives free.
PLAYER_ID is never substituted with game OBJECT_ID. Profiling branches were
disabled in the oracle and are not implemented. No production transport attached.

`probe-live-client-area-message.mjs` now uses real scalar bytes/readback and
envelope across all5 installed Prelude areas in explicit fixture modes0/1.
It retains334 active loading-screen rows, per-context script selection, shared
RNG and fixture PLAYER_ID42 distinct from canonical object565. The original
reader independently decodes all10 replacement-produced headers and returns
the expected loading screen, XYZ, facing and BOOL without diagnostics.
PackAreaIntoMessage is captured and adds no bytes: these packets contain only
headers, are incomplete, and are never transmitted.

## Validation and limits

4,295 original executions match source:

- 1,614 writer cases: exact bytes/capacity/counters, growth/reuse/finalization,
  modes0/1/2, widths1..64 and mixed scalar sequences.
- 2,441 reader cases: decoded values/float bits, cursors/diagnostics, malformed
  setup/truncation/reuse, range reads and10 replacement-produced area headers.
- 240 complete sender cases: roles, null buffers, lengths0/1/2/3/16, allocation
  failure, logging/accessor/send/free order, narrowed headers and raw results.

Native JSON/scripts: native-message-writer/reader/send-observations.json and
scripts/inspect-native-message-writer/reader/send.py. Node native-message-*.test.js
also covers shared ClientArea integration and diagnosed physical limits.
Full regression **1,406 pass,0 fail**, message-codec-all-tests-v1.txt; build
passes, message-codec-build-v1.txt. Installed probe:
live-client-area-message-codec-v1.txt and live-client-area-message.json.
Original SHA256 unchanged. Verified backup report:
backups/animations/message-codec-checkpoint.txt.

Strings/ResRefs/localized strings/object-ID compression, full PackAreaIntoMessage,
client receiver/ready transport, native PC lifecycle, map fog/persistence,
save/autosave and campaign acceptance remain unfinished. The current scene/PC
adapter remains in use. Scalar/helper/header checks do not prove a full packet,
multiplayer parity, all spells/combat or campaign completion.
