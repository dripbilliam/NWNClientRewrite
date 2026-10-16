# Spell radial casting and defensive casting, October 15 2026

Current innate/type44 and parent-targeting continuation:
[client ability input](spell-like-client-input.md). The innate subtree is wired;
native class/feat ability submenus and remaining spell owners are still open.

Current inventory/equipment continuation: [prepared item targeting and Light
ownership](inventory-spell-targeting.md). This extends the world/self paths
below; the full spell ecosystem and campaign remain unfinished.

Target NWN:EE89.8193.37-17, unchanged installed nwmain.exe SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original install and Ghidra database remain unchanged. Captures are derived
observations under backups/animations; no game binaries/assets were copied.

## Original owners and replacement

- Self Cast creator1409904b0 and placeable creator1409b1db0 construct
  CClientSpellMenu1409a10e0 with target ID and native position. Ground factory
  14084def0 retains clicked position. Selection1409a4540 unpacks spell WORD,
  class index3 bits, domain level4 bits, metamagic6 bits and conversion bit,
  then140804d00 invokes client message1407bf4e0. That message includes both
  target and position when present; position magnitude threshold is native
  FLOAT0.00001 at140d82154. Our local decoded boundary preserves these fields;
  this does not implement NWN network serialization.
- Class menu1409a38e0, metamagic1409a24b0 and levels1409a2370 establish native
  compass slots. With fewer than4 classes, normal class entries use5-index
  and metamagic entries7/0/1. Four or more classes use grouped Cast4/Metamagic0.
  Metamagic feat gates and mask/slot pairs are observed engine constants.
  Levels0–6 occupy slots0–6; slot7 combines7–9. Overflow keeps7 leaves and
  continuation slot7. Active class flags, spell levels and known/memorized
  pools supply choices; no stock spell list is embedded.
- Traversal1409a2b10 uses memorized pools for memorizing classes, known pools
  for restricted nonmemorizing classes and physical spell rows otherwise.
  It collapses duplicate IDs, retains the first encountered metamagic/domain
  context, shows spent entries disabled, and admits conversion from a spent
  convertible leaf when a non-domain source slot is ready. Domain level is
  effective slot level minus active metamagic cost. SubRadSpell children come
  from active SPELLS rows and retain parent resource context.
- Target admission1409a4910 intersects TargetType and menu filter, treating
  self1 separately from other creatures2, ground4, items8, doors16,
  placeables32 and triggers64. Both parent and child entries use this check.
- Spellcasting-options creator1409a37a0 exposes Counterspell0 and Defensive
  Casting1. Defensive callback1409a4700 calls1408055c0 with mode10; packet
  creator1407c02e0 emits input subtype10. Server140453807..140453897 checks
  commandability before ToggleMode1403a52b0. Mode10 toggles combat mode9;
  enable uses force0 (may wait for round end), disable force1. The existing
  SetCombatMode/SetActivity owners update defensive casting6ee and activity
  0x40000. ToggleMode sends each valid associate script event11/integer20010.
  Creature receiver14038f88d stores188 and calls RunEventScript11 without a
  dead-state veto. The replacement uses canonical IDs and deferred AI events.

## Validation and limits

`inspect-native-spell-radial.py` executes unchanged target/selection owners:
1,600 target-mask/filter/type cases and1,536 packed selection cases.
`inspect-native-mode-toggle.py` executes948 toggle cases and96 decoded input
cases, capturing lower activity/mode/event boundaries. Tests compare the
replacement traces against those observations. Pool tests cover live changes,
multiclass indices, domain/metamagic context, children and conversion gates.
The complete suite passes1,342 tests; production build passes.

`smoke-live-casting-ui.cjs` uses an isolated Electron profile and installed
Prelude/wizard resources. Right-button self wheel toggles defensive casting
on/off, then real spellbook Light and a second immediate radial self cast
consume both actual slots and play animations. Drag to F2, F2 targeting and
Escape/right-click cancellation remain verified. Renderer error list is empty.
Reports: live-casting-ui-radial-v2.txt, live-casting-ui.json/png. GPU teardown
may emit a Chromium GPU-state line after the smoke has completed successfully.

Full tree construction is mapped statically rather than independently emulated.
Authoritative server spell gain/use queries feed this local client view; a
separate replicated-client cache is not claimed. DM/override/epic selection,
counterspell resolution, exact count overlays/configuration/hover behavior and
client replication remain open. Counterspell/epic options remain diagnosed
requests. Detect/stealth activity activation still raises its existing missing
owner diagnostic. Spellbook, hotbar and radial share cast submission/resource
owners; this is not completion of the full spell ecosystem or campaign.
