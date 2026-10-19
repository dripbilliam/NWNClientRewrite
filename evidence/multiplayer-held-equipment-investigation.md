# Held equipment investigation — 2026-10-18

Held weapon/shield rendering is now connected and live-verified. Previous goal
turn **PROGRESS**: native tile lighting completed and weapon attachment path
identified. This turn implements common weapon/shield attachment, retaining
diagnostics for the remaining equipment owners. Full goal remains ACTIVE.
Same read-only x64 target/build/hash as multiplayer-ground-items.md.
REA99283 reused. No original process/project edits. Dossiers below prefixed
rea-network-held- in backups/animations, added after tile-lighting checkpoint.

## Native evidence

* Original model-name helper29dd90 has only native ground/item constructor769130
  and CopyItemAndModify5128f0 as direct call sites. CreateItem769130 callers are
  player appearance77fe10, inventory79db00 and world creation79fe30. Reuse the
  verified item model planning rather than inventing a weapon naming scheme.
  Retained construction evidence caller view is item-construction-callers.
* Player appearance77fe10 reads/creates the canonical item, calls83ef40 to assign
  its creature owner, calls80a460 with creature/slot/itemID, then811190 and
  80e9d0(0,0,creature). Dossier appearance-read. Original slot setter80a460
  stores right16 at creature318, left32 at31c; other equipment slots map through
  308..34c. Weapon-class refresh811190 is already covered by the existing
  clientWeaponAnimationClass port; do not duplicate gameplay rules here.
* Function80e9d0 has native log name **SwitchWeaponEvent** and is the useful next
  complete oracle target (9121-character pseudocode). It obtains both items
  from canonical IDs and appearance table WEAPONSCALE via GetFLOATEntry. Missing
  appearance or unsuccessful read uses1. Item+2b0 nonzero suppresses that model.
  Item ownership/visual reference fields differ:83ef40 changes+25c and this
  function changes+260; don't conflate them or assign new item IDs.
* Native item model is obtained through object virtual140(selectorff); its
  priority is2 for controlled PC,4 for another creature. Animation base accessor
  7630a0 returns creature+78. Its virtual+200 (c8) receives itemID, CExoString
  anchor, right/left selector, and FLOAT appearance weapon scale.
* Right item base8 or11 routes to anchor **lhand**, selector0, and clears right
  selector1. Other right items route **rhand**, selector1. Left item base14,
  56 or57 routes **lforearm**, selector0; other left items route **lhand**,0.
  Missing items clear attachment with OBJECT_INVALID/empty anchor/scale1.
  These are native intrinsic base-ID branches, not module-specific item checks.
* Derived animation-base virtualc8 mapping was followed through constructors,
  virtual base adjustments and function thunks. Base CNWCAnimBase c8=968640 is
  a no-op. Wield vtable140e74fe8 c8->99d32c->99d340; HeadWield140e75280
  c8->99e1e4->99e1f0->99d340. Parts' **adjusted base** vtable140e755e8
  c8->9a10c8->99e1f0. Its primary vtable140e755d8 has another layout: its c8
  removes body parts and must not be confused with the animation-base slot.
  Parts constructor99e344..99e36e explicitly establishes both tables.
* Wield99d340 uses item model virtual98(parent model,anchor,flags0), then
  virtual1b0(weaponScale,scaleType0). Gob::AttachToObject8c540 copies anchor
  position/orientation; it does not inherit anchor scale. Gob::ScaleObject94860
  stores the explicit scale and calls CalculateFinalScale. No extra invented
  rotation/translation is added. Existing visualLocalPoseServices supplies the
  already-verified scene adapter for that P/Q attachment, independent of bone
  scale, updated after model animation each frame.

## Validation and implementation

`inspect-native-held-equipment.py` executes220 complete original SwitchWeaponEvent
cases: empty/both hands, bow/shield branches, hidden or unavailable models,
local/remote light priority, appearance pointer/getter failures and scale0/.5/2.
Canonical object/control/model/appearance lookups, virtual attachment/priority
and animation refresh are explicit lower boundaries. Native owner writes and
branching execute. CHAR selector is low R9B, enum low EDX; the oracle initially
captured dirty high bits and was corrected before comparison. Fixture
native-held-equipment-observations.json, final oracle log v4. Vtable metadata
is static evidence, not emulated derived attachment coverage. Bone transforms,
GPU and complete Wield mode/torch behavior are not claimed by this oracle.

`network_equipment_models.js` reproduces those presentation commands; it never
changes canonical inventory, equipment, item IDs or rules/action state.
NetworkScene shares the verified item component/resource fallback loader for
ground and held models, using active resources/2DAs. Held model roots are render
bindings owned by the creature's lifetime; equipment proxies remain nonspatial.
Animated attachment copies P/Q after animation without inheriting bone scale.
Selection resolves to the owning creature. Removal/disposal drops attachment
references and model instances. Independent item-model failures stay diagnosed
without making the creature disappear.

The actual hidden Electron/unchanged Prelude server tests use unchanged installed
BICs. Names/selection indices appear only in QA inputs, never production rules.
All peers logged out; original server PID48532 remained running.

| Run | Real behavior | Native results / presentation |
|---|---|---|
| v30 wizard | UI drag dagger16, move/run/walk, toggle off; drag crossbow16, toggle off | Four successful major12 results, identical IDs; all three components per weapon, rhand; final player held=[] |
| v31 fighter | Shield32 toggle off, drag same item back, run/walk | Both successful results; same shield ID on lforearm, sword's three parts on rhand |
| v32 ranger | Run/walk with initial longbow | Three bow components on lhand/selector0, no right attachment |

v30 joined04:59:43/logout05:00:17,67diagnostics/0errors; v31 joined05:02:37/
logout05:02:59,58/0; v32 joined05:03:43/logout05:03:58,63/0. No model or
attachment failures. Snapshots capture equipment following movement and animated
hand motion. No local combat or pathfinding execution. UI gestures are generated
inside the owned test app, with no desktop focus/physical-pointer claim.

Inspected images: local-network-held-dagger-v30.png (distant view),
local-network-held-crossbow-v30.png (inventory covers world; not visual proof of
crossbow grip), local-network-held-shield-v31.png and local-network-held-bow-v32.png
(clear zoomed sword/shield/bow views). Snapshot and server results establish the
crossbow model path, not that obscured image. QA camera zoom uses the normal
wheel handler and affects only presentation.

193 rendering/network tests PASS (network-held-equipment-tests-v6.txt), including
original routing comparison, installed model replay/lifetime/movement and all
three live reports. Build PASS v2, existing chunk warning. Harness syntax PASS.
Credential audit3256 source/note/network-evidence files:0 full private-key hits,
4 synthetic fixture keys (network-held-equipment-credential-audit-v1.txt).

## Remaining equipment and gameplay owners

Wield99d340 additionally handles torch equip/unequip playback and a mode flag
that suppresses certain weapon models; the constructor starts that flag0.
Those runtime mode transitions and model hiding updates remain to port.
The visible NPC torch is explicitly diagnosed; drawing/sheathing is not claimed
complete. Model-type gating for non-wield creature bodies needs full comparison.
Helmet/cloak/robe presentation and native per-part dye/effects are separate
equipment owners; do not suppress their current diagnostics prematurely.
Footstep/audio, tile flames, final shadow/material parity, containers and native
combat/casting coordination/effects/UI remain open. Next priority is multiplayer
combat/casting presentation; completing this milestone does not complete the
full concurrent-original-client multiplayer goal.

Post-seal checkpoint multiplayer-held-equipment-20261018-v1.zip:12470files/
215253771bytes. Writer50576 terminal0 consumed; every archived entry length and
SHA256 verified.29 selected required entries present, forbidden native/game
assets and private configuration absent. Seal notes added after archive creation.
