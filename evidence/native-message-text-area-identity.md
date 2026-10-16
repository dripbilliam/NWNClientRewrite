# Native message text, canonical IDs and area identity

Target NWN:EE `89.8193.37-17`; unchanged original
`../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Ghidra names/callers, complete instruction bodies and isolated Unicorn executions
of the unchanged PE. No original asset/binary copies, Ghidra edits, injection or
actual network sends. Full spell/combat/campaign acceptance remains unfinished.

## Shared message owners

`src/native_message.js` now adds WriteCExoString1402dab50..1402daca5,
WriteCResRef1402dad90..1402dae3d, WriteOBJECTIDServer1404763e0..140476436,
ReadCExoString1402d97d0..1402d98cf, ReadCResRef1402d9960..1402d99ef and
ReadOBJECTIDServer140476130..14047615c to the scalar codec. Complete growth,
type tags, length/cursor behavior, error branches and consumed string state
are compared, not just successful text round trips.

WriteCExoString emits type14 then the INT length type8. Natural length32 is
raw little-endian; reduced widths use signed sign/magnitude. It copies stored
byte length, including embedded zeros, then frees/clears the owning temporary.
The replacement clears its explicit temporary's bytes/length/capacity; the
writeStringBytes convenience supplies that temporary without mutating the
caller's byte array. There is no implicit UTF8 conversion in these byte APIs.

ReadCExoString consumes the same two types. Truncated lengths/data advance
the original cursors and yield an empty owning string. The native string copy
constructor14003d8c0..14003d9ab normalizes a leading NUL to empty, retaining
later embedded NUL bytes and the supplied length otherwise. The replacement
preserves this distinction and the resulting length/capacity. Unsupported
allocations/unknown physical input bytes diagnose rather than invent contents.

WriteCResRef emits13 and copies the requested raw fixed-width bytes; read
clamps to16 and uses CResRef assignment140190d30..140190dcd, which preserves
case and zero-pads the17-byte result. When a short unterminated read leaves
native stack bytes uncopied, fixtures explicitly capture known physical tails.
Production cannot infer these bytes: `unknownResRefStackByte` is recorded and
the read throws. Natural16-byte references and terminated short reads require
no tail. No automatic lowercase or padding is added to the raw writer.

WriteOBJECTIDServer writes raw4 bytes with the external bit0x80000000 set,
except OBJECT_INVALID0x7f000000 remains unchanged. These constants are read
at140dc2a50/140dc2a68. ReadOBJECTIDServer clears bit31, including its original
truncation behavior. Registry IDs remain canonical; the namespace bit belongs
at the wire boundary. These are the named **server** helpers; implementation
of a distinct actual client receiver is not inferred from a symmetric test.

## Localized writer and language selection

`src/native_message_text.js` implements the complete decoded
WriteCExoLocStringServer140476160..1404763dd. It checks the server first;
the client-only case warns and writes no data. Its language candidates are
player language,0,module language, in insertion order with duplicates removed.
GetPlayerLanguage wrapper14055b8d0 forwards to140560e20..140560e4f, which scans
transport clients and takes the first matching PLAYER_ID48/language4c, else0.
GetModuleLanguage14055b770 forwards to140560bc0..140560bc3, a constant-zero
owner in this target build. The shared helpers retain those exact rules.

For each language, GetString140169b60 tries the raw BYTE gender then logical
!gender. Language0 deliberately ignores gender. Keys retain unsigned32 math.
Native linked-list order is preserved; first matching key wins. If no candidate
matches, GetStringByIndex(0) selects the first stored entry. A matched entry,
even empty, takes precedence over StrRef. Only no entries plus StrRef!=-1 emits
reference BOOL1, gender1bit, DWORD StrRef; otherwise BOOL0 plus inline string.
Pre-reservation differs between selected entries and the completely empty
no-reference case; tests compare exact capacities as well as bytes.

The oracle executes original AppendUnique140475bc0, GetString140169b60 tail
14016a3b0, GetStringByIndex140169af0/14016a440, linked traversal140169110 and
CString copies. Allocation/free/realloc/copy/log/cookie are captured lower
boundaries. Cookie stubs preserve RAX, and reader return pointers are asserted.

`localizedMessageValue` converts the existing Western GFF representation back
to bytes with the shared CP1252 encoder. That codec round-trips all256 bytes,
including controls/extended bytes/NUL; unrepresentable new Unicode is diagnosed.
Native GFF import then applies the leading-NUL string rule, signed key split,
language0 gender normalization and replacement of duplicates in their original
list position. This was checked against bounded ReadFieldCExoLocString loop
1401a1040..1401a10c2, real SetString1401696e0/140169ee0 and AddTail140169030.
No sorting or raw duplicate preservation is invented. This does not establish
support for every possible international codepage or all malformed GFF cases.

## Live area state and bounded identity prefix

LoadAreaHeader14035ffe0..14036002a reads localized Name and assigns area188;
ctor14035a068 initializes it with StrRef=-1, verified ctor140169560..1401695a2.
Area ctor14035a470..14035a47e clears custom name358/length360. Normal
ModuleSession area loading now retains nativeName188 and this custom-name
state instead of keeping only the flattened display label. Valid typed ARE
names and the missing-name default are covered; malformed incompatible GFF
types remain explicit input errors.

`src/area_message_pack.js` implements the **bounded prefix**1403632ea..
14036339b of PackAreaIntoMessage140363200..140364661: canonical area ID,
raw ResRef16, custom-name BOOL, then either the custom byte string or the
localized-name server owner with gender0. Both custom branches, leading NUL,
large values and missing-reference fallbacks are compared. This is not the
full area packer; no replacement PC ready handshake is connected by this patch.

The remaining original packer includes module-entry coordinates, lighting/
weather/time/tiles, waypoint map notes, player-local map pins, sound objects,
placeable lights and static placeables. Named lower owners verified in Ghidra:
virtual+d8 yields sound objects (PackIntoMessage1404f5120), and placeable
1404b3e40 is GetLightIsOn. These must not be mislabeled as door packing.
The complete packer and header/ctor bodies are saved for the next work.

## Validation

`inspect-native-message-text.py` produces **1,802 original cases**:

- 1,108 writers: byte strings, ResRefs, canonical IDs, localized fallback and
  128 bounded original area-identity prefixes. Exact payload, capacities,
  counters, flags, owning temporary cleanup and diagnostics match source.
- 606 readers: original writer packets, truncation and known stack tails,
  plus10 replacement-produced installed-area identity prefixes.
- 88 bounded original GFF import loops with real insertion/copy helpers:
  English gender normalization, signed key corners, leading-NUL strings,
  duplicate replacement and append/fallback order.

`probe-live-message-text.mjs` loads all5 real Prelude areas through normal
ModuleSession initialization. It writes their canonical IDs, resource refs and
retained localized names with fixture PLAYER_ID42/language0/modes0,1. The
original readers independently consume all10 replacement outputs and match
every field/cursor/diagnostic. Packets are incomplete prefixes, never sent.
Startup/general AI are isolated for this data probe.

Final native report: native-message-text-v7.txt /observations.json; installed
report: live-message-text-v2.txt /live-message-text.json. Failed v1 excluded a
native empty/null GetWriteMessage incorrectly and is retained; v2 fixed that.
v3 added prefixes, v4 installed cross-reader cases, v5 preserves cookie RAX
and verifies actual owning return pointers. v6 adds actual GFF import loops and
corrects adapter normalization/replacement; v7 reruns current installed output.
Initial focused test case-count
assertions were corrected to actual fixture counts before comparisons passed.

Full regression **1,412 pass,0 fail**, message-text-all-tests-v3.txt. Build
passes, message-text-build-v2.txt. Rendered message-text-transfer-ui-v2.txt
passes real radial summon, Follow/Stand, out/back with canonical summon574/
master565, and radial dismissal. Zero browser errors. DoSinglePlayerAutoSave
still fails and remains recorded; it is not silenced or claimed implemented.
Latest live-associate-transfer-ui.json/png are inspected/backed up; scene is dark.
Original SHA256 unchanged. Verified backup report:
backups/animations/message-text-checkpoint.txt.

Full area serialization/receiver/ready transport, persistence/autosave, remaining
spell/combat owners and continuous campaign completion remain open. These
finite codec/prefix cases establish those boundaries, not the full objective.
