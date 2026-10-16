# Complete decoded area packer and live metadata bindings

Continuation: GIT/object bindings now supply all five installed Prelude
area-pack bodies in both tested formats. See
[current evidence and limits](area-git-object-message-bindings.md).
The missing ambient state described below is the historical probe result.

Target NWN:EE `89.8193.37-17`, unchanged original
`../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Ghidra names/callers, complete instruction ranges and isolated original-code
executions. No binary/asset copies, Ghidra edits, process injection or actual
network sends. The full spell/combat/campaign goal remains active.

## Decoded serializers

`src/area_message_pack.js` now contains the complete decoded
PackAreaIntoMessage140363200..140364661, including its return/cleanup paths,
with explicit lower server/lookup/expansion/script-local/2DA providers. The
ambient packer140358750..14035881d and sound-object packer1404f5120..1404f53a8
use the already verified scalar, text, ResRef and server OBJECT_ID owners.
Placeable GetLightIsOn1404b3e40..1404b3f13 is also decoded: successful
placeables.2DA LightColor lookup gates raw light-on field594; the table value
itself is not an on/off flag.

The area owner writes identity/name, entry INT XYZ, flags, lighting/fog,
sun/moon direction vectors gated by client feature0x23, day/night/PVP/rest,
shadow opacity/fog clip, EnvAudio and ambient state, then module time and
dawn/dusk. Wind vectors require feature0xe and WindPower3. Weather override
255 selects current type/on; another override forces on1. It then writes
dimensions, tileset, versioned grass/tile-border fields and actual tile data.
No feature support is inferred from a game object ID or hardcoded for Prelude.

CNWSModule::GetTime14047de20..14047de63 supplies fields3c0/3c4/3c8/3cc/3d4/
3d0 in the original byte/DWORD order. The module accessor is called again
for dawn/dusk, preserving the native lookup order. Area calendar/weather and
spatial fields read live shared state instead of copied protocol snapshots.

Each tile writes ID14/orientation24/height18, then a WORD mask. Source-light
bits2/3 are always set even for zero values. Main-light bytes are28/29;
source light2a/2b; replacement texture2c; animation bytes2d/2e/2f. Replacement
texture is not tile height. Real getter leaves and writer bytes execute in the
oracle. The signed live width*height bound is re-read at each iteration.

Object sections retain the original repeated/live passes:

- First classify spatial IDs into enabled waypoint notes (virtual+b8, field308)
  and sound objects (virtual+d8). Snapshot only those selected IDs. Serialize
  the original count even if a later canonical lookup/cast fails.
- Waypoint notes write ID, position, BOOL30c and localized string310. An
  eligible waypoint does not subsequently fall through to sound selection.
- Player-local map pins use the controlled creature or its master8fc. For
  nonzero NW_TOTAL_MAP_PINS, scan **0 through total inclusively**, requiring
  nonempty NW_MAP_PIN_NTRY_i and the matching area object ID. Re-read selected
  strings/positions while serializing; do not flatten these into waypoint notes.
- Sound count is narrowed to WORD, with that many selected IDs passed through
  complete sound packing, including WORD-counted fixed-width sound ResRefs.
- Count placeable lights and nonzero Static5a0 in one live spatial pass, then
  re-query lights in another pass. Static records are serialized only for
  Static exactly1, retaining the native nonzero-count/exact1-write distinction.
- Counts wrap to WORD where the original does. Two trailing zero WORDs remain.

The source diagnoses unavailable native fields/physical data. Map-pin counts
above1,000,000 are explicitly unsupported, rather than entering a potentially
unbounded malformed enumeration. Those guards are not claimed native behavior.
Temporary native allocation/free/reallocation boundaries are captured in the
oracle; JS releases its equivalent temporary arrays through normal ownership.

## Loaded area/tile state

`area_message_metadata.js` implements actual CArea constructor defaults
140296a40..140296b51 and scalar LoadAreaHeader1403600df..140360525, with
typed field fallback/narrowing. Shadow opacity starts50, fog clip45; sun/moon
direction and wind vectors start0. These vector fields are **not RGB colors**.
The Header BOOL and BYTE distinction is preserved: SunShadows2 becomes1,
while NoRest2 remains2. The native indoor flag clears the DWORD at E1,
covering rain/snow/lightning/wind bytes E1..E4, plus ChanceFog218. All those
clears now survive normal ModuleSession loading.

Tile metadata retains the relevant LoadTileSetInfo inputs. Source lights and
replacement texture load BYTE default1 then subtract1/narrow, while main
lights default0. Animations use actual BYTEasBOOL conversion. ID/orientation/
height setters1402c58a0/1402c58c0/1402c58d0 and relevant color/animation setters
are executed in the input fixture. This is protocol metadata; rendering/resource
load owners are not declared complete by comparing these scalar blocks.

`AreaMessageRuntime` binds the decoded packer to a normal session: canonical
registry lookup/casts, live spatial IDs, module calendar, script locals, active
placeables.2DA and imported area/tile fields. Transport clients/languages and
expansion state remain explicit inputs. Missing ambient, waypoint/sound and
placeable metadata are errors recorded through session.report, not substituted
with empty packets. The current local PC scene adapter is still in use.

## Original-code comparisons

**591 original cases** match source:

- 439 complete area packer executions, with original ambient/sound serializers,
  scalar/text/ID writers, tile/time getters and placeable-light owner. Compare
  full payload, capacities/counters/flags, return, diagnostics and lower-call
  order. Cases cover modes0/1/2, independent/negative expansion results, every
  tile mask combination, mixed objects, stale lookups, live list removal/reorder,
  master map pins, custom/localized names, growth and65536-byte creation.
- 97 actual constructor/scalar-header blocks, including current-value defaults,
  signed/narrowed inputs, BOOL conversion and all indoor weather clears.
- 55 tile loader/setter blocks, including missing/default inputs, zero-based
  source/replacement values and animation narrowing.

Full packer lower boundaries captured: server accessors, expansion checks,
canonical lookup/virtual casts, PVP, script-local getters/string formatting and
2DA query. Their captured outputs are not independent proof of those owners.
The input fixture captures typed GFF getters; malformed GFF parsing is not
established. Native numeric/text/ambient/sound serialization bodies execute.
Read-only scripts: inspect-native-area-pack.py and
inspect-native-area-message-fields.py. JSON/report names: native-area-pack
(final-v2) and native-area-message-fields(v1). Early mask run-v1 had duplicated
status scenarios; v2 supplies the intended failed lookups and more mixed cases.

## Installed and rendered evidence

`probe-live-area-pack.mjs` loads all5 Prelude areas normally, checks their
tile metadata counts and invokes the actual session packer. Its explicit
PLAYER_ID42/language0/mode1/feature-support/entry-INT fixtures are not native
protocol negotiation. Each area stops at the same missing ambient328 binding;
all5 errors are present in the diagnostic journal. Partial bytes are recorded
as incomplete and **never transmitted**. This is observed incomplete runtime
integration, not a successful complete-area test. Report:live-area-pack-v1.txt/
live-area-pack.json. Startup/general AI are isolated for this data probe.

Full regression **1,416 pass,0 fail**:area-pack-all-tests-v1.txt. Build passes:
area-pack-build-v1.txt. Rendered area-pack-transfer-ui-v1.txt passes existing
radial summon, Follow/Stand, out/back with canonical summon574/master565 and
radial dismissal. Zero browser errors; DoSinglePlayerAutoSave still fails and
remains logged. Latest live-associate-transfer-ui.json/png inspected; scene
remains dark. These checks do not exercise a completed native ready handshake.
Original SHA256 unchanged. Verified checkpoint report:
backups/animations/area-pack-checkpoint.txt.

## Next binding work and remaining limits

Original LoadGIT140360f40 calls LoadProperties140361dd0..140362252 for the
AreaProperties struct. Its current-value color/fog/SkyBox/EnvAudio overrides,
DisplayName, wind and sun/moon direction fields are not yet imported by the
new header-only metadata owner. Presence/success of the final WindPitch read
sets WindPower3. Direction defaults come from binary constants, not color
conversion. It then calls grass loader140361330 and ambient loader140358610.
Full original bodies are saved as native-area-properties-load-asm.txt,
native-ambient-grass-load-asm.txt and native-area-git-ambient-owners-asm.txt.

Ambient ctor1403584a0..1403584f0 sets BOOL8=1, INTc=5000,10=2,14=3,18=0,
1c=1,20=1,24=1,28=2, volume bytes2c/2d=0 and area ID30. Its loader reads
MusicDelay/Day/Night/Battle, AmbientSndDay/Night, AmbientSndDayVol/NitVol with
current-value defaults; volumes use INT reads then narrow. Grass import must
also preserve the actual native keyed-container iteration/duplicate rules.

Those GIT properties, ambient/object metadata and their runtime mutation owners
must be bound before claiming complete installed packets. Client expansion/
PLAYER_ID negotiation, the actual receiver/ready flow, native PC lifecycle,
save/autosave and continuous campaign acceptance remain unfinished. Codec/
routine comparisons do not establish all spells, combat or campaign completion.
