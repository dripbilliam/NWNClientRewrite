# Scripted object creation — 2026-10-16

Target: NWN:EE89.8193.37-17 x64, original unmodified `nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original game assets remain read-only; no Ghidra database edits.

## Binding and ownership

NWScript CreateObject243 now binds the previously compared complete command
owner140513be0..14051470f to concrete template, placement, area, effect and
destruction providers in `world_creation_runtime.js`. Creature, item, waypoint,
placeable and store allocations use the canonical registry cursor. Their normal
loaders own nested objects; failure consumes and destroys the allocated ID.
The command does not directly run OnSpawn. Unsupported types and an invalid
location area return OBJECT_INVALID before allocation.

The installed-data VM probe executes parsed NCS ACTION243 through typed stack
arguments, rather than calling a command function directly. All five types
pass tag override, canonical/area/spatial membership and cleanup checks. It also
checks omitted optional arguments, appearance effects, five missing templates,
cursor consumption and invalid requests. Expected missing-template errors are
retained. Active resources select templates; product code has no fixture names.
Results: `installed-create-object-v2.json` and
`create-object-runtime-installed-v2.txt` in `backups/animations`.

## Orientation and geometry

Common orientation14049b910..14049b925 copies three FLOATs. The complete
placeable owner1404b7680..1404b7786 writes the new vector before area lookup,
uses FLOAT dot order Y+X then Z, and skips replacement when the native
0.9998999834060669 threshold is not greater than the dot. Equal, greater and
unordered comparisons therefore preserve collision polygons. Vectors are not
normalized. Mesh lookup, area replacement and point recomputation are explicit
lower boundaries. 288 original executions compare writes, calls and results;
`native-world-orientation-observations.json` retains them. The capture uses the
actual Windows callee-entry stack argument offsets, starting at RSP+28.

Runtime geometry now preserves an explicit raw native orientation during lazy
loading. An intentional native guard skip updates the signature without
silently replacing polygons; unrelated unannounced mutations still fail. An
installed placeable and actual SetFacing command exercise both guard paths.

## Authored spell and rendered interaction

The untouched Gate impact script63 executes deferred CreateObject for
NW_S_BALOR_EVIL. The stronger `probe-authored-gate-cast.mjs` reaches it through
parsed ActionCastSpellAtLocation234, ordinary cast actions/timing and the
native script cheat flag1. Impact occurs at2200ms; creation at5200ms. Canonical
creature574 owns inventory575..578 and area1 membership. Two heartbeat updates
run the authored `nw_c2_gatedbad` OnSpawn exactly once. Recursive destruction
removes creature and children without rewinding IDs. Spell resources remain
unchanged as required by that cheat flag. No error diagnostics occurred.
Result: `authored-gate-cast-v1.json`. This is not prepared-player Gate admission,
rendered Gate, natural expiry, full combat AI or campaign acceptance.

The rendered probe uses an in-memory Prelude fixture, leaving original files
unchanged. Actual mouse right-click Use runs NCS GetLocation/CreateObject243/
SetLocalObject/DestroyObject. A new canonical placeable model appears, the old
one disappears, the new model is radial-pickable and survives an area revisit.
`live-create-object-ui.json` and `.png` retain the result. Preview lighting and
camera changes are inspection only. Generic death feedback visible in the
screenshot has not been attributed or validated by this probe.

## Remaining gates

Map-pin delivery/UI and dynamic ground-item rendering remain explicitly
diagnosed gaps. The native command ignores the map-pin transport result, so
that missing delivery does not abort successful waypoint creation. Common
ground items now emit `scene.runtime-ground-item-unimplemented` once per ID.
Creature/item lower import boundaries documented elsewhere still apply.

Full tests pass:1,748 (`create-object-runtime-full-tests-v2.txt`); build passes
(`create-object-runtime-build-v2.txt`). Final rendered creationv2, body-bagv1,
summoningv3 and castingv3 regressions all pass, with owned processes observed
through terminal exit0. Casting covers spellbook, self radial, slot use, hotbar
targeting, cast animation, cancellation and world-radial counterspell input.
The final creation screenshot was visually inspected. Diff whitespace check
passes. Checkpoint: `create-object-runtime-1748-20261016-v1.zip`; its separate
`create-object-runtime-checkpoint-v1.txt` records archive length/hash verification.

Static spell audit now finds83 unbound
commands (previously84),22 unavailable impact scripts, and596 loaded scripts
out of618 distinct impact names across840 spell rows. CreateObject appears in
nine authored scripts; Gate has no statically unbound API. These counts do not
prove every runtime branch or spell works. Spellcasting, combat and campaign
completion remain active work.
