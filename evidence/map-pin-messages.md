# Map-pin messages and scripted enable state — 2026-10-16

Target: NWN:EE89.8193.37-17 x64, original unmodified `nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original game installation remains read-only; no live injection or Ghidra edits.

## Original owners and comparisons

`map_pin_messages.js` ports the complete Created sender1404dc2d0..1404dc3ec
and Enabled sender1404dc3f0..1404dc485. Created writes a server OBJECT_ID,
three quantized FLOATs(scale1/bits32), localized string(gender0) and BOOL.
CreateWriteMessage uses16/INVALID/1, so localized fallback queries INVALID,
not the recipient's transport ID. Enabled uses8/INVALID/1, ID and BOOL.
Both send major0x20; Created minor6, Enabled minor1. Recipient comes from
CNWSPlayer+48. Missing JS transport metadata is rejected, never replaced by
a canonical actor ID. Created disposes its by-value localized temporary after
payload failure or send return. Enabled has no localized temporary.

670 original executions compare complete body bytes, send parameters/results,
disposal and warnings across format modes0/1, five IDs, signed/nonboolean INTs,
fractional/large coordinates, embedded and referenced strings, language lists,
missing server, forced payload failure and send failures. Allocation startsA5;
uninitialized bytes are fixture memory, not a native zero-fill claim. The actual
scalar, object-ID, localized fallback/language, CString and message-finalization
owners run. Transport and localized temporary destruction are captured lowers.
The FLOAT constant1.0 was read at programmatically resolved140d8109c.

Client Created1407a3990..1407a3cac and Enabled1407a3cb0..1407a3e7b are complete
with profiling disabled. 148 original executions compare result, ordered calls,
pin state, collection capacity, reader cursors and diagnostics, including real
malformed declared sizes and forced checks. Scalar/string/client OBJECT_ID code
runs; TLK, scene/GUI access, pin construction/position and refresh are captured.
The actual append1407d8e40..1407d8ec9 and lookup1407daeb0..1407daeef execute.
Created appends without deduplication. Lookup skips nulls and returns the FIRST
matching reference188/type18c; duplicates of another type do not match.

Both handlers check **overflow first** and **underflow after parsing**. Created
rejects underflow before changing the scene. Enabled can change an existing pin
and refresh the GUI before returning0 for underflow. The first draft mislabeled
these two owners; the comparison caught it. Capturesv4 and tests use the verified
names from the independently compared scalar reader; the failed drafts are not
validation evidence. The dispatch1407a3810..1407a3982 selects minors1/4/6;
minor4 remains a supplied, currently unavailable reference-number owner.

The original virtual position target140766760 was resolved from the pin vtable
slot140e72928; its full scene/model update is not claimed by this comparison.
Constructor140983020 is a captured lower with its known string/flag defaults.
Client wire IDs retain bit31, unlike canonical server lookup IDs.

Native observations: `native-map-pin-message-observations.json`. Static provenance
is retained in `map-pin-client-owners-v1.txt`, `map-pin-client-id-enabled-v1.txt`,
`map-pin-verified-constants-v1.txt` and related bounded captures. The descriptor
references were resolved through the actual complete assertion records at
140e41e98 and140e41ff0, not interior substrings. Uninterpreted exploratory reads
and failed placeholder/address requests are not evidence for native behavior.

## NWScript command

`map_pin_script.js` ports SetMapPinEnabled140543780..1405438aa after successful
typed VM pops. A missing waypoint or HasMapNote308=0 does nothing. Otherwise
the raw INT is stored at30c, then every client with a game object receives the
Enabled message. There is NO same-area filter here. The sender's BOOL writes
the low bit: canonical2 remains2 while the client receives0. Send failures are
ignored by the command. All216 original executions pass, varying lookup,
HasMapNote, INT, client eligibility and send result. VM pop/type/stack failures
are explicit lower boundaries and are not proved by this command-body oracle.
Native observations: `native-map-pin-script-observations.json`.

SetMapPinEnabled is now bound in ModuleSession. The installed-data probe executes
both commands through parsed NCS/typed VM situations. CreateObject243 loads the
active nw_mapnote001 UTW and installed TLK, creates canonical waypoint574, and
delivers client reference2147484222 at[24,20,0] with its actual note text. No
extra canonical IDs are allocated for pins. Scripted enable0/2/3 validates raw
INT versus client BOOL, invalid targets do nothing, and a different-area target
still sends Enabled while its creation notification is withheld. Area changes
reset the local pin scene; destruction retains monotonic IDs. Probe:
`installed-map-pins-v1.json`, final run `map-pin-installed-probe-v3.txt`.

## Local delivery and remaining gates

`MapPinRuntime` connects CreateObject's waypoint notification to the native body
writer/client reader through an explicit in-process route. It does not claim
actual transport: local panel objects have no PLAYER_ID and no ID is invented.
Full native send coordinators remain independently compared, ready for a real
transport binding. The local reader marks absent transport metadata INVALID;
it does not use the controlled actor's ID. Local compression format1 is host
configuration. Known transport language entries are used if present; otherwise
native module/embedded fallback is recorded as a local language-context limit.
GameUI supplies its loaded base/custom GameText for referenced note strings;
missing strings remain individually diagnosed. This does not prove all native
gender/locale TLK ownership. Scene lifetime is tied to local area and character.

The client state is delivered, but map-panel presentation, initial area-pack map
notes, MapPinAdded, reference-number responses, user-created/edited pins, full
client scene/model ownership and actual network transport remain open. Missing
map presentation remains a durable diagnostic. Ground-item rendering also
remains open. No campaign or full spellcasting completion is claimed.

All1,753 tests and the final build pass. Installed five-type creation regression
passes again (`installed-create-object-v3.json`). Static spell audit remains83
unbound commands and22 missing scripts; SetMapPinEnabled is not present in that
impact-script scan, so binding it does not lower the count. Static binding
presence is not branch/casting/campaign acceptance.

Final authored Gate cast, rendered right-click creation/area revisit and rendered
spellbook/hotbar/radial/counterspell/cancellation regressions pass. Owned Electron
processes were observed through terminal exit0. The casting report has no
renderer errors; its process stderr emits `GPU state invalid after
WaitForGetOffsetInRange` after the PASS lines. That message is retained in
`map-pin-casting-ui-v1.txt`, not treated as proof of graphics-driver health.
The final casting screenshot was visually inspected. Diff whitespace check
passes. Checkpoint target: `map-pin-messages-1753-20261016-v1.zip`; verify
`map-pin-checkpoint-v1.txt` before treating it as sealed.
