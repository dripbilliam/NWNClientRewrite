# Native multiplayer ground items — 2026-10-18

Goal **ACTIVE / PROGRESS**. Ground items now render and use the normal canvas
pick/default-action path. An unchanged vanilla server confirmed drop and pickup
with the same object ID. Held equipment, lighting and full multiplayer gameplay
remain open.

## Original-code evidence

Read-only x64 NWN89.8193.37-17, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Owned vanilla server SHA256
`98951511ae7d06a251355f12d4f3e4b96269a2414fa3058e641afd70098690f6`.
REA session99283 reused. No native process/project changes or copied assets.

Native CNWBaseItem model/icon naming29dd90/29dc80 uses hidden output RDX,
part R8B, signed model SHORT R9W and optional variant CHAR at stack28. Naming
uses ItemClass, three-digit signed formatting, B/M/T for model type2, optional
GenderSpecific variant otherwise, and sixteen-byte CResRef truncation. Base-item
loader29e5b4..29e60b establishes the GenderSpecific field at84.

Full CreateItem140769130..14076b65d calls those helpers with variant0 for ground
models. Types0/1 load one component; type2 probes three and loads selectors255,
254,253. Each missing resource uses active baseitems DefaultModel. A present
resource whose body load fails does not take that fallback. Type1 native cloak
base ID80 uses gi_cloak01. Type3 reads parts_chest ACBonus for torso part7,
rounds half upward, and selects the native ground armor model at thresholds2,
4,6 without the resource fallback branch. Palette row ordering follows the
native six material channels. Normal types play default; armor does not.

`scripts/inspect-native-network-item-model.py` executes252 original model/icon
name cases and512 complete original CreateItem cases. Original branching,
naming, probes, rounding, selectors and default-animation decisions execute.
Object/icon construction, formatting, 2DA getters, model loading/playback,
transforms and effects are explicit lower boundaries. Resource availability
and load failure are synthetic inputs; this does not validate GPU materials
or all item poses. Fixture: native-network-item-model-observations.json;
oracle log: network-item-model-oracle-v2.txt. REA dossiers/views are prefixed
rea-network-item-model-construction and rea-network-baseitem-model-resref.

GLRender::ResetRenderStates1400b6050..1400b6498 enables GL_CULL_FACE and sets
GL_CCW at1400b6209. `inspect-native-render-reset.py` executes the complete
reset and captures23 GPU calls with imported/dynamic OpenGL, memset and
MaxLights14007f640 as lower boundaries. Native model basis conversion
(x,z,-y) preserves winding. Shared model materials now use FrontSide and the
mesh builder preserves that setting. This establishes reset/default culling,
not every later pass/material override. Static culling candidate addresses
include false positives; they are research leads, not verified call sites.

## Client changes and server authority

`src/item_model.js` reads active baseitems/parts_chest rules and computes native
ground resource plans. NetworkScene probes availability separately from model
loading, builds every selected component, applies replicated pose and removes
the render binding on pickup. Changed appearance can recover from a previous
failed model; corrupt present models remain diagnosed instead of falling back.
No module, server, spell or test-item name checks occur in production.

Type6 default click and shared radial pickup send the existing guarded native
major12/minor5 request. The server owns reachability, action execution and item
state. Rendering never creates replacement item IDs or performs local pickup.
Item effects/transforms and held equipment remain explicitly diagnosed.

## Real renderer / unchanged server verification

Hidden owned Electron run v28 joined04:09:13 and logged out04:09:36 local.
The unchanged wizard dropped item2147484312 (0x80000298), closed inventory,
then clicked its projected position through CDP Input mouse events on the
replacement application's own game canvas. This branch calls no pickup IPC
directly. Normal production pointer picking/default dispatch sent the request.
Native major12 confirmed drop=true and pickup=true for that same ID.

All three installed components WSwDg_b_012/WSwDg_m_032/WSwDg_t_042 rendered;
after pickup the ground binding disappeared and the same ID returned to the
backpack. Final three equipped/five backpack items, empty pending set, no
failed scene objects.59 diagnostics,0 errors/invalid/incomplete/model-failure
records. Six existing fxpa_cloud02 emitter-bitmap warnings remain, unrelated
to these weapon models. Peers closed; server PID48532 was not restarted.

Reports: local-network-renderer-v28.json and its diagnostics. Inspected images:
local-network-ground-v28.png and local-network-ground-inventory-v28.png.
The room is still visibly too dim; these captures do **not** establish correct
lighting or complete roof/camera behavior. No desktop focus/physical mouse
claim. A replay test also picks the actual dropped model in the full starting
room, without removing surrounding geometry.

186 rendering/network tests PASS (network-ground-item-tests-v7.txt); build PASS
(network-ground-item-build-v4.txt, existing chunk-size warning). Nine focused
ground/material cases also PASS, including recovery and corrupt-present-model
behavior. Full combat/casting/effects/audio, held equipment, container/alternate
ownership, original item icons/activation and concurrent original-client play
remain required. This milestone does not complete multiplayer compatibility.

Post-seal checkpoint: backups/multiplayer-ground-items-20261018-v1.zip,
12342 files /207453666 bytes. Writer80567 exited0 and verified every entry
length/SHA256;26 selected required entries present, forbidden assets/private
configuration absent. Credential audit3157 files:0 private-key hits,4 synthetic
fixture keys. These seal notes were added after archive creation.
