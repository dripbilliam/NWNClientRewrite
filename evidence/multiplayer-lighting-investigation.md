# Multiplayer lighting investigation — 2026-10-18

Tile main-light application is now implemented and live-verified; remaining
lighting owners are open. Previous goal turn **PROGRESS**: completed ground-item
render/pickup milestone and mapped the native missing tile-light path. This goal
turn executes that path in isolation and applies it to the replacement renderer.
Use the same read-only target/hash recorded in multiplayer-ground-items.md.
REA session99283 remains available; all dossiers below are in backups/animations.

## Observations

Decoded original server area in renderer v28: flags1; DayNightCycle fieldd8=0,
IsNight fielddc=1; MoonAmbient98=0x292929, MoonDiffuse9c=0, SunAmbientb8=0,
SunDiffusebc=0. TimeOfDay2/hour3/dawn6/dusk18. The shared preview currently picks
moon in this particular room because only moon has energy. Its general policy
of choosing whichever period has nonzero colors is not a verified native policy.
Do not claim that changing the hour or choosing sun will fix this interior.

First transmitted tile: ID41/orientation3, MainLight1=28, MainLight2=0,
source-light bytes1/1. Both actual reports identify area m0q1a, tileset tic01,
whose tile41 is tic01_e01_01. Its authored ml1 is black/radius14/multiplier1;
ml2 is RGB1/255/radius5/multiplier1. The preceding investigation inspected a
similar tni01 model by assumption; that was the wrong tileset for this report.
The implementation always resolves the transmitted SET/model. No model or
test-module names enter production selection. NetworkScene previously created
authored lights without applying the transmitted tile palette/source-flame setup.

## Native path and original execution

* ProcessTilePart1400cb890 compares model-name + ml1/ml2/sl1/sl2 with _stricmp;
  model names are copied up to60 bytes before suffixing. ml slots capture
  virtual AsPartLight pointers, sl slots capture source anchor parts.
  Dossier rea-network-light-tile-part.json.
* Client tile update1407e6040 calls GetMainLightColor at1407e619c, then84f9a0;
  GetSourceLightColor at1407e61c8, then84ff80. Initial area receiver76d910 also
  calls both apply functions (previous retained callee list). Update dusk/dawn
  function7e90b0 interpolates colors, fog, tile animations and shadow settings;
  this is more involved than selecting the current hour.
* Main apply14084f9a0 uses g_pRules+130 -> table+1b8, GetFLOATEntry RED/GREEN/
  BLUE for each BYTE palette row, then scene virtual+38 with tile position and
  both vectors. It also stores the palette bytes at tile28/29. Native table
  initialization1402b5327 references string140dc65f0='LightColor'; constructor
  call1402b5362 then store to array+1b8 at1402b536c and Load2DArray1402b5378.
  **TileColor is a different table at+1b0**, initialized1402b5e13..5e64; do not
  substitute it. Last addresses verified by read-only PE/Capstone disassembly,
  not an executed loader oracle. Dossier rea-network-light-tile-main-apply.json.
* Scene::SetTileLights1400d3e60 resolves BSP tile data; when a main-light pointer
  exists and RGB differs, writes color68/6c/70, fields78=1/88=1/90=4,
  shadow-radius7c=12 or8 and radius74=10 or5, then UpdateStaticLightingde630.
  Unchanged colors do not rewrite those properties. Preserve that distinction.
  Native PartLight field semantics should be verified before changing JS fields.
* Source apply14084ff80 removes existing flame objects, creates fx_flame01 for
  nonzero source bytes, plays the numeric-byte animation and attaches them via
  scene virtual+40; source anchor placement remains to trace. Native constants
  here are intrinsic engine behavior, not test-module special cases.
* Scene::SpawnTile1400d41a0 (22217 characters) constructs/collapses the tile tree,
  calls ProcessStaticPartscb520/ProcessTilePart, builds BSP data. TileData ctor
 88130 starts all four main/source pointers null. Do not fabricate extra lights
  on tiles lacking the native matching model nodes.

## Color conversion evidence

ControlLightsFade14007ddb0 invokes GetColorSpaceFromSRGB before area ambient/
diffuse setters (e.g. area-ambient wrapper call14007e57a). SetLightGL140080c10
also uses that helper. GetColorSpaceFromSRGB vector overload1400beb90 queries
global shader parameter0 and raises RGB to2.2 only when nonzero; otherwise it
copies RGB unchanged. This does not justify blindly removing Three's sRGB
conversion. Original configured renderer mode and final output still need
comparison. Names are overloaded: use addresses, not the ambiguous short name.
Dossiers rea-network-light-control-fade, native-set, color-space-v2.

GLRender area settersb67e0/b6840 merely cache vectors. Scene::SetAmbientd3310
belongs to another ambient path with GUI callers; it is not proof of world-area
selection. Several initial name/query searches failed and were corrected; those
error reports are not evidence that a subsystem is absent.

`inspect-native-tile-lights.py` now executes40 complete original ProcessTilePart
cases and320 complete main-apply -> Scene::SetTileLights cases. Model-name case/
60-byte truncation, absent/failed light casts, BYTE palette indices, six named
FLOAT lookups, equal/different colors, both absent/present light slots and flag/
radius changes are covered. String primitives, allocation/free, 2DA getters,
AsPartLight, BSP lookup and static invalidation are explicit captured lower
boundaries. GPU rendering, per-object light selection and source flames do not
execute in this oracle. Fixture native-tile-light-observations.json records
the loader's separately verified static LightColor identity as disassembly;
the loader itself is not emulated. Log network-tile-light-oracle-v2.txt.

PartLight::InternalCreateInstance91980 copies node shadow108 -> part78,
affectdynamic104 ->88, isdynamic100 ->8c, ambientonlyfc ->84. The native palette
write replaces already-resolved part RGB; the JS adapter consumes the authored
multiplier in its equality check and stores multiplier1 on a changed override.

## Implementation and live validation

`src/tile_lighting.js` reads active LightColor RED/GREEN/BLUE values, matches only
native ml1/ml2 nodes, preserves unchanged properties and updates per-instance
colors, radii, shadow/affectdynamic/priority fields. Cached model definitions
and other instances remain unchanged. Animation reset retains the new instance
baseline; later animated channels may replace it. NetworkScene loads the active
table and applies each tile's replicated indices before attaching area lighting.
This adds no local gameplay decisions or canonical object mutations.

Real hidden Electron/unchanged vanilla-server run v29 joined04:35:24 and logged
out04:35:37, remaining playing throughout. Nine tiles/eighteen matching lights;
fourteen changed and four equal-color main lights retained native radius14.
First main palette28 resolves RGB1/.75/.3, radius10/shadowradius12/priority4.
Other rows retain values greater than1 (e.g.1.3/1.92/1.82); no ad hoc clamping.
No failed objects,57 diagnostic records,0 errors. Native scene-source flames
are now explicitly diagnosed once per area (nine affected tiles), alongside
existing renderer limits. Existing bitmap warnings remain. All test peers
logged out; original server PID48532 unchanged. No native injection/patches.

Report local-network-renderer-v29.json and diagnostics; image
local-network-lighting-v29.png was inspected. The actual room, PC, floor, beds
and walls are now clearly lit. This confirms the missing palette path materially
caused the dark capture. It does not establish final photometric/shadow parity,
native roof cutaway, every area or every display setting.

190 focused rendering/network tests PASS (network-tile-light-tests-v3.txt).
Final light/model-focused checks PASS (network-tile-light-tests-v4.txt) after
ordering shadow configuration after its radius update. Build PASS v2, with the
existing large-chunk warning. No complete campaign/multiplayer acceptance claim.
Credential audit3207 source/note/network-evidence files:0 full private-key hits,
4 synthetic fixture keys counted separately (network-tile-light-credential-audit-v1.txt).

## Remaining lighting owners

Source effects, native light selection/static caching,
day/night update packets, material gamma and exact shadow passes remain open.
Current source-flame diagnostic should remain until native sl1/sl2 attachments
and numeric fx_flame01 animations are implemented and verified. Held equipment,
containers and the full combat/casting/concurrent-original-client goal also
remain open; this milestone does not complete multiplayer compatibility.

Post-seal checkpoint multiplayer-tile-lighting-20261018-v1.zip:12403files/
210281177bytes. Writer57465 terminal0 consumed; every archived length/SHA256
verified.23 selected required entries present, forbidden assets/private profile
configuration absent. Seal notes added after archive creation.
