# Initial area map notes — 2026-10-16

Target: NWN:EE89.8193.37-17 x64, unchanged `nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original installation remains read-only. No live injection or Ghidra edits.

## Verified reader section

`area_map_pin_reader.js` ports the bounded section1407dd55c..1407dd7ee inside
CNWCArea::LoadArea1407dba70..1407dea0d. Both pin loops are complete; the full
area loader, following profiling/sound sections and final whole-area error
checks are not ported by this increment. Original code appends while reading.
It does not use the standalone Created-message handler's pre/post guards.

The first signed INT count selects waypoint notes. For each, construct a pin,
read raw client OBJECT_ID, read three quantized FLOATs(scale1/bits32), set its
position, read enabled BOOL, then localized text, set type18c=0 and append.
The second signed INT count selects player notes. For each, construct, read an
INT reference, read a plain CExoString, read/set three FLOAT coordinates, set
enabled170=1/type18c=1 and append. Negative counts skip that loop. Player
references are local indices, not server object IDs, and can legitimately be0.

116 original bounded executions compare pin records, ordered constructor/position/
TLK calls, CString results, reader cursors, diagnostics and collection capacity.
Cases cover formats0/1, zero/one/two records in either section, embedded/reference/
empty text, TLK success/failure, external/invalid IDs, raw player references,
fractional/negative coordinates, enabled INT low bits and negative/zero counts.
The real writers/readers, localized/CString owners and append execute. Pin
construction/position and TLK are captured lower boundaries. XMM8=1 comes from
LoadArea1407dc1ca, whose resolved FLOAT constant is140d8109c. Observations:
`native-area-map-pin-observations.json`. JS's explicit count>1,000,000 rejection
is a diagnosed host limit, not an original-game count guard.

## Shared server section and runtime binding

`packAreaMapPins` extracts the existing contiguous server section from
`area_message_pack.js`; the complete packer now calls the same function used by
local initial-note delivery. It retains the original classification and repeated
live lookups, including sound IDs used by the following section. A waypoint
without a note does not fall through to sound classification. The existing439
complete native area-packer comparisons and installed-packet comparisons still
pass, including payload bytes, mutation cases and lower-call order.

Player-local enumeration still uses the controlled creature or its master8fc.
When NW_TOTAL_MAP_PINS is nonzero, indices0 THROUGH total are inspected. Nonempty
NW_MAP_PIN_NTRY_i and a matching NW_MAP_PIN_AREA_i are required; text and XYZ
locals are re-read during serialization. These are separate from waypoint notes.

`MapPinRuntime.loadArea` now feeds this native server section into the bounded
native client reader through the explicit local body route. It creates fresh
client pin state on area entry without allocating canonical server IDs. Loading
the UI's language data reloads note text with that base/custom GameText owner.
Full native transport and the complete Area packet/scene loader remain separate.
No PLAYER_ID or server object ID is invented for the in-process body route.

The local adapter checks exact body consumption, reports failures and leaves
initial state unavailable. Queued pin delivery returns0 after such a failure;
it does not turn successful CreateObject into an exception or invent an empty
initial map. A generation/area/character guard prevents stale loads and queued
updates from being attached to a later scene. A preview without a connected
local client skips this client-only work. Failure, stale-delivery and no-client
behavior have focused host-adapter tests; they are not extra branches claimed
for the original reader section. Pin diagnostics use the client owner plus
reference/type, so player-note index0 is never treated as canonical module0.

## Installed and rendered checks

The installed Prelude probe passes all five areas: m0q1a0 notes, m0q1b7,
m0q1c0, m0q1d2 and m0q1e1. It checks canonical spatial order, external wire
references, type0, enabled low bits, actual text and unchanged allocation cursor574.
RAM-only player locals then produce user references0 and2, both enabled/type1
with their exact text/coordinates. Index1 for another area and index3 beyond the
declared total are excluded. No original module or character files are changed.
Final report: `installed-initial-map-pins-v3.json`.

Parsed CreateObject243/SetMapPinEnabled still pass through the normal VM. Their
probe now expects rebuilt initial scenes on area entry, rather than the old null
scene placeholder (`area-map-pins-created-enabled-v3.json`). The transition unit
fixture now owns a real NativeAreaSpatialArray, matching the data required by the
new path; the product does not fabricate a missing230 field. The actual Gate
cast/impact/CreateObject/OnSpawn/cleanup regression passes again. Real rendered
radial Use, dynamic placeable picking and area revisit pass. Spellbook, hotbar,
radial casting, slot use, cast animation, cancellation and counterspell input
pass in the owned rendered client. All1,757 tests and build pass; relevant owned
processes were observed through terminal exit0. Casting's renderer report has
errors[]. Diff whitespace checking passes. Checkpoint target:
`initial-map-notes-1757-20261016-v1.zip`; verify `initial-map-notes-checkpoint-v1.txt`
for archive length/hash validation before treating this increment as sealed.

## Remaining map presentation and located owners

The visible map is STILL the old approximate walkmesh overview. Native tile
artwork, pin widgets, viewport/zoom/panning and user pin creation/editing remain
open and diagnosed. This increment does not claim a finished map panel, full
spellcasting, combat or campaign. Command bindings are unchanged by this pass;
the previous spell audit's83 unbound commands/22 unavailable scripts remain
open evidence, not proof of readiness.

Read-only research located the next native owners:

- ImageMap2D is read at1402c7580..1402c7615 in the SET reader1402c6890. The
  empty-string branch uses MIDE01_A09. ReadINI1402cc370 clears output on a missing
  section/key. The setter1402c60d0 tails to a17-byte ResRef copy at tile-data+21;
  getter1402c5e80 returns that17-byte value. These are static findings;
  map-image import/rendering is not yet implemented in the client.
- RTTI resolves the embedded map-surface vtable140e59108. Its containing
  constructor140891300 also sets the outer vtable140e59210. Setup140893360 binds
  CTL_MAP_ZOOMIN/ZOOMOUT/PINSRC/PANBAR and MapCenter.
- Refresh140893c70..140894717 caches three models per tile, uses the active
  map-image ResRef getter and tile orientation, and rebuilds enabled pin widgets.
  Pin presentation140893860..140893ab9 checks the cached tile state for EXACT1
  unless forced, with CVTT truncation and native FLOAT positioning/rounding.
  These full instruction bodies were read but have not been ported or executed
  as presentation oracles. Do not replace these rules with guessed fog or
  normalized canvas positions and call them parity.

Static captures use `map-panel-*`, `map-image-*`, `map-surface-*` and
`map-window-*` names in backups/animations. Failed exploratory reads and guessed
or interior-string references are not validation. Exact string/RTTI/constructor/
vtable provenance is retained in the successful captures. The inspection tool
now supports bounded --u64-table for verified pointer tables.
