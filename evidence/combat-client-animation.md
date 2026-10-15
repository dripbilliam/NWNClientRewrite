# Native client combat animation continuation

Target89.8193.37-17, nwmain SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original binary, campaign and Ghidra remain unedited. Research uses bounded
assembly and synthetic Unicorn execution, never injection into the game.

## Connected behavior

The renderer now binds creature animation state by canonical object ID, receives
local attack deliveries, samples swing and delayed reaction clips, returns to
ready/idle and holds death poses. Skeleton/skin deformation uses the existing
ModelAnimator. Presentation state and RNG are separate from authoritative
action storage and rolls. Combat roll/damage deliveries reach the game log.
Unavailable clips, bindings and unsupported speeds are still diagnosed.
Diagnostic preview clips may override an idle model; combat cues resume gameplay.

DamageRuntime now commits the verified native death body/animation choice
before clearing the death WORD. Existing body3/4 remains untouched. Creator
means the original creature source, before self-kill substitutes LastDamager
for XP. Body3 requests8, body4 requests6; SetAnimation retains its MODELTYPE
remapping. The unimplemented associate/corpse/encounter owners remain recorded.

## Native evidence and validation

- Animation-base virtual+58 at140961540..140963e86 maps WORD state IDs to
  model clip names. State9 falls back to pause: attacks require the separate
  combat selector. Context BYTEdd changes weapon class; BYTEde selects
  assembled/simple body naming; BYTEe0 participates in attack-side naming.
  Constructor140960b40 zeroes context cells, special walk and movement override.
- `inspect-native-animation-names.py` executes30672 lookups across72 contexts,
  states0..425, both body branches, weapon classes0..11 and side0..2. Allocator,
  string copy/free and final empty override lookup are substituted. Walk helper
  executes with special-walk0. Generated metadata405 names/21 distinct rows is
  in `native_animation_names.js`; no models, textures or original code are copied.
- Override lookup140964530 uses physical first case-insensitive match and
  copies the replacement once. LoadAnimationOverrides1404969c0 reads
  AnimationReplace/AnimationReplaceList, OldAnimation/NewAnimation, retaining
  16-byte resrefs in34-byte records. Non-ASCII locale behavior is unsupported.
- CNWCCreature RTTI descriptor1412cb070 yields vtable140e474e8. Virtual+150
  dispatches1407fc7d0, which handles timed attack/reaction presentation.
  Animation length helper1407630b0 calls animation-base virtual+48.
- Native melee range classifier140800780 subtracts target HITDIST from3D
  distance and compares PrefAttackDist±.25. Weapon range scales by appearance
  weaponscale only for P/F and successful reads. Weapon attack types map to
  actual slots via140800c30; zero is client INVALID, not a new server RNG draw.
- Normal-range selector14080ffd0 alternates client BYTE170, initialized0 by
  constructor1407fb56a, and context BYTEe0. Weapon %AnimSlashL/%AnimSlashR use
  BYTE thresholds and inclusive CRT draw%100 comparison. Monk class5 changes
  unarmed choices and draw counts. Too-close140810c20 uses targetheight L;
  too-far14080f7b0 uses205. Ranged dispatcher14080f5e0 selects200 separately.
- `inspect-native-client-combat-animation.py` compares2592 complete native
  selector executions against the replacement: IDs, reactions, side storage and
  RNG counts. Native normalize140230920 and cross14022fba0 execute; sqrtf is
  substituted with rounded IEEE sqrt. Synthetic class/item/target/height query
  helpers are explicitly substituted. This is not a complete client packet or
  encounter oracle. Results are in native-client-combat-animation-observations.json.
- Death observation60 executes only the verified animation phase
  14042aedc..14042aff2. Its float dot is promoted to DOUBLE for comparison with
  .707. Both selectors and body3/4 preservation match. This does not validate
  the complete death/associate/corpse owner.

## Remaining validation and owners

The renderer's assembled-body context choice uses active MODELTYPE P/F and the
existing assembly pipeline. The native constructor/update owner establishing
BYTEde has not been completely traced; retain this adapter limitation.
Weapon-class140811190 is ported and tested by cases but has not received a
machine-code differential oracle. Full original client queue interruption,
blending, MDL events, network packet conversion and client/server CRT thread
interleaving remain open. Local bridge timing scales clips by native attack
duration words; it does not claim complete original queue parity. Ranged
projectile visuals and travel-dependent parry timing need their own renderer.
Special walk/movement overrides and nonpositive script speeds remain unsupported.

The authored Electron radial attack test passed with strike and directional
reaction clips and a held corpse pose, using canonical player565/target475 and
unchanged fighter/goblin statistics.14 rendered actors reported no missing
clips. Its camera screenshots are partly occluded; this is integration evidence,
not a full visual or original encounter parity check.

Client SetBaseAnimation140764300..140765470 body-state choices now match72
native executions (category helper and80-byte action constructor also execute).
AsCreature is substituted with null to isolate generic transitions; PlayAnimation
is captured and the queue starts empty. Standing-to-dead6 selects219 then221;
dead8 selects220 then222. Type5 PlayAnimation fixes the initial fall to1000ms
and its linked transition to another1000ms. Knockdown recovery selects223/224;
corpse recovery adds225/226. The renderer uses this subset for live changes;
initial loaded body poses are held directly. Full queue timing remains open.

All1059 tests and the production build pass. The follow-up radial UI check now
passes after rotating around authored occluders and probing current projected
body coordinates. `combat-fall-prelude-d-ui.txt` records219 kdfnt,221 kdfntdie
and6 deadfnt on target475, each transition1000ms before the33ms held corpse.
Attack/fall screenshots were inspected: fighter and goblin are visible, though
a wall still partly occludes their bodies.14 actors have no clip failures. The
test retains authored enemy AI/stats and uses test-only preview sun/camera aids. Talent
selection, creation/acquisition, ActionUseSkill and the remaining combat effect
owners still prevent a fully functioning authored enemy combat cycle.
