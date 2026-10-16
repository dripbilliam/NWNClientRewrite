# ClientArea message and first-player activation

Subsequent codec work implements the scalar message and envelope boundaries
below; the installed area probe now uses real header bytes. Full packing and
transport remain unfinished. See [current codec evidence](native-message-scalar-codec.md).

Target NWN:EE89.8193.37-17; unchanged read-only original
`../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Ghidra, full instruction inspection and isolated Unicorn executions. No original
binary/assets or Ghidra edits. The full spell/combat/campaign goal remains active.

## Area ownership now connected

IncrementPlayersInArea14035f2c0..14035f461 and DecrementPlayersInArea14035ce70..
14035cf49 preserve the live spatial order and native first/last-player guards.
On first entry, level0 creatures, AoEs and triggers activate. Doors activate only
when GetScriptName(5)'s stored length is nonzero; it is the OnHeartbeat string,
**not trap data**. Placeables activate only when static5a0==0. Last-player exit
demotes only noncreatures at level1, deliberately retaining creature levels.
Counts retain signed32-bit wrap and stale canonical IDs are skipped.

`creature_area_lifecycle.js` supplies these shared owners to Add/RemoveObject
and the existing local PC scene adapter. The adapter's former creature-only
promotion and missing noncreature demotion are replaced by those owners. It
still owns PC scene changes; this is not native ClientArea protocol integration.

RTTI-derived trigger vtable140df7608+80 points to AsNWSTrigger1404ff920;
AoE vtable140df6858+a8 points to AsNWSAreaOfEffectObject1404f6b20. Door vtable
140de7288+1e0 uses GetScriptName140420880; index5 returns string358, populated
by OnHeartbeat at1404214e5. Native selected predicates14035bc80..14035bd23
and the complete count methods agree; repeated casts and unsigned string-length
tests are retained. The source does not infer eligibility from trap flags.

Placeable Load1404b4f07..1404b4f68 reads Useable/Static as BYTEasBOOL.
Missing Static uses !Useable; override5a4 exactly1 forces static0. Area
LoadPlaceables140361b4f clears that override before loading. Loaded placeables
now retain nativeUseable264/static5a0/override5a4. Broader placeable AI remains
unfinished; implementing this loader/predicate does not prove its heartbeat,
RunActions, empty-inventory cleanup or destructor is connected.

## Area sender and per-client selection

`client_area_message.js` implements decoded SendServerToPlayerArea_ClientArea
1404cd9d0..1404ce035. Module/server-mode/client guards precede optional
last-update-map cleanup; area null still permits that cleanup. The message
creation request is65536/client PLAYER_ID/1. Client/player IDs remain distinct
from canonical game object IDs. A missing explicit PLAYER_ID diagnoses missing
state rather than silently substituting an object ID.

Area LoadScreenID WORD350 supplies a default when the client's one-shot choice
is-1 or1. An out-of-table choice becomes0. For0, scan physical loadscreens
rows2..count-1 for case-insensitive tileset matches, count them, use the shared
native rand() modulo, then scan again. Failed string queries never count;
fallback random choice remains2..count-1. The original two-pass column spellings
TileSet/TILESET and fallback RNG consumption are preserved. Invalid tiny tables
diagnose the native division-by-zero state. No stock tileset/screen mapping is
hardcoded.

WriteINT(screen,32) precedes SetAreaTransitionBMP(-1), which occurs even if
later packing fails. Native XYZ FLOATs and atan2f(orientationY,orientationX)
follow with scale1/bits32, then the raw transition BOOL argument. Module entry
floats14/18/1c are converted with native CVTT semantics for PackAreaIntoMessage.
Packing must return exactly1; GetWriteMessage merely nonzero; send family4,
subtype1 returns its raw result. Payload encoding/area serialization/transport
remain explicit lower boundaries, not a claimed replacement packet format.

The formerly opaque module108 data is proven to hold authored entry coordinates:
LoadModule140480962..1404809e9 reads Mod_Entry_X/Y/Z into14/18/1c; the save
owner1404863e7..14048643c writes them back. LoadAreaHeader1403604d4..1403604fb
reads LoadScreenID WORD/default0. These decoded typed fields now load into the
live module/areas. Load2DArrays1402b4403..1402b44fa identifies rules118 as active
Loadscreens.2DA. GetCExoStringEntry1401a68f0..1401a69da returns0 for empty cells,
or missing row/column while copying the table default; physical first matching
column wins.

SetAreaTransitionBMP203/ExecuteCommand14053df30..14053dffa resolves the client
for the script context's object ID. Uncontrolled NPC contexts cannot change the local player's
selection. This replaces the previous session-global inert value. SetBMP
1404be490..1404be4fc changes user text only for index1. Last-update ClearAutoMap
1404c2ac0..1404c2af5 clears area178/buffer170, separate from creature maps6c8/6d8.
Local GUI state includes the verified constructor defaults for20/28/50/CC/a8;
it does not invent a PLAYER_ID or claim complete CNWSPlayer lifecycle/control
transfer. The script's engine.partial diagnostic still states that actual
ClientArea packing/loading-screen presentation is not connected.

## Validation

1,531 original observations across five hash-checked native fixtures:

- 201 predicate/static-import blocks, with original door string selector;
- 432 complete first/last-player methods, including stale IDs, live truncation,
  locked AI mutations and signed count wrap;
- 606 complete sender executions, with original atan2f, all selection paths and
  packing/payload/send failure gates;
- 36 SetBMP/last-sent-map state executions;
- 256 typed module/ARE input blocks, context-selected script calls and actual
  GetCExoStringEntry bodies with captured lower string memory/comparison.

These finite cases prove the compared owner boundaries, not their captured
lower helpers, packet bytes or a multiplayer/campaign completion gate.
Reports/observations are named native-first-client-activation,
native-area-player-count, native-client-area-message, native-client-area-state
and native-area-message-input. Initial bounded-input fixture failed because
its ARE frame pointer was uninitialized; v2 fixes the fixture. Failed reports
remain preserved.

Installed `probe-live-first-client-activation.mjs` loads176 placeables and uses
real library/training/library adapter changes. Door2 promotes1/demotes0; creature19
remains1 after final departure; canonical identities and player counts persist.
The installed room has no suitable authored door heartbeat, so that one script
name is an explicit in-memory fixture, never executed; game assets stay untouched.
Report:live-first-client-activation-v1.txt/json. General AI/startup are isolated.

`probe-live-client-area-message.mjs` exercises all five actual Prelude areas
against334 active loadscreens rows, real script-context selection and shared RNG.
Its transport PLAYER_ID42 is a declared fixture, distinct from object565. It
validates selected screens, reset and cleared client map state. At this checkpoint
message writing, packing and transport used a synthetic marker; no actual area
packet was transmitted. Report:live-client-area-message-v1.txt. The subsequent
codec checkpoint replaces that marker with real scalar header bytes; area packing
and transport remain captured boundaries.

Rendered `client-area-transfer-ui-v1.txt` passes installed radial casting,
Follow/Stand, local out/back transitions, unchanged summon576/master565 and
radial dismissal. Zero browser errors; DoSinglePlayerAutoSave fails once and
remains recorded in the report/runtime log. Latest live-associate-transfer-ui
JSON/PNG inspected; scene remains dark. The automap and installed associate
probes also pass. This is not engine-clean campaign acceptance.

1,398 tests/build pass:client-area-all-tests-v3.txt/client-area-build-v3.txt.
Verified backup:backups/client-area-1398-20261015.zip,
report backups/animations/client-area-checkpoint.txt.

## Still required

PackAreaIntoMessage140363200..140364661 is fully captured in
native-area-pack-asm.txt but unimplemented. Complete native bit/message writing,
the client area receiver/scene-ready signal and sender/ready integration are
needed before replacing the local PC adapter. Name searches ClientArea,
AreaMessage and HandleServerToPlayerArea locate only server-side owners;
locate the client receiver from actual message dispatch/xrefs instead of
inventing an ACK. Saved-player/client control transfer/LUO lifecycle and module
limbo also remain open. Persistence/autosave, map fog, full noncreature AI,
spell/combat/campaign acceptance remain unfinished.

Additional captured dependency:placeable AIUpdate1404b0890..1404b11c1, source
native-placeable-ai-transition-bmp-asm.txt and ghidra-native-placeable-ai-update.
It gates on heartbeat4/action head/effects/DieWhenEmpty504; runs effects and
actions after timing, then checks HasInventory4f8, repository length,508 and
LootCreature510. Empty cleanup schedules event11 and can clear creature
Lootable4e8/DeadSelectablef8. Constructor registers placeables at level0;
that registration/whole AI path and placeable destruction are still unconnected.
Keep this distinct from the implemented static import/activation predicate.
