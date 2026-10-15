# Native ranged combat checkpoint

Target: NWN:EE89.8193.37-17, read-only nwmain SHA256 `3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`. Complete chained unwind disassembly is primary evidence; truncated Ghidra allocator/free pseudocode is supplementary. The Ghidra project was not edited.

## Connected owners

`GetAmmunitionAvailable1403e3070..1403e3739` now queries actual registered right-hand/ammunition items, native unlimited property61, signed stacks, ordered repository candidates, warning feedback and the shared creature+744 cell. Exact bow/crossbow/sling/thrown base-ID dispatch is compiled native behavior, independent of custom2DA ranged flags. Its automatic replacement coordinator retains CanEquip/RemoveRepository/SetPossessor/Equip ordering; those live side-effect owners remain explicit missing dependencies.

`ResolveAmmunition1403e3b30..1403e3c5d` captures item IDs at release scheduling and queues item event16. `CNWSItem::EventHandler140467b87..140467c1d` captures possessor before stack mutation, decrements stacks above1, otherwise schedules event11 without zeroing/removing the item, subtracts one cached unit mass from equipped mass and invokes encumbrance. Canonical object identity survives ordinary consumption.

`ResolvePostRangedDamage1403e97a0..1403e9cb5` is separate from melee follow-ups. It retains signed health/level/ability narrowing, killing-blow gates, active MAX_RANGED_COUP_DE_GRACE float32 3D distance, Devastating Critical save/effects and ineffective-weapon warning. Cleave/Circle Kick/Crippling Strike/Quivering Palm are absent from this owner.

`ResolveRangedAnimations1403e9cc0..1403ea286` now connects native endpoint replacement,40/55 projectile speeds, float32 magnitude/division/truncation, WORD delays, defender action-length checks, reaction insertion/rescaling, shield random draw and miss-to-block conversion. Shield conversion negates the attacker's orientation, including signed zero. `CheckActionLengthAtTime140375470..1403754c9`, `AddReaction140374d10..140374d9f`, magnitude1402303d0..14023040c and SetOrientation14049b910..14049b925 are separately traced.

`ResolveRangedMiss1403ea490..1403eb50b` now connects the actual result gate4/8/9, signed missedBy, active RANGED_MISS_DISTANCE_MODIFIER/MIN_RANGED_DISTANCE, near/far draw order, lateral scaling, original atanf reduction/polynomial, existing native-traced trig/normalization, area boundary intersection, LOS obstruction and height owners. Near misses add target XYZ after setting candidate Z to target.Z+1. An outside-area candidate is clipped for LOS but successful output retains original XY and target.Z. These observed instruction sequences are preserved. Native trig CPU dispatch ambiguity and exceptional math remain explicit failures.

`ResolveRangedSpecialAttack1403eb510..1403ebaab` connects normal roll/damage/miss/animation before called-shot Concentration resistance and leg/arm effects. Active appearance physical rows populate haslegs/hasarms at+710/+70c through UpdateAppearanceDependantInfo1403a69f0..1403a6dc7. Missing unchecked native table scratch values remain diagnosed.

`ResolveSafeProjectile1403ebab0` freezes attack metadata without strings/lists, captures ammunition ID and queues self event21. Receiver14038e629..14038e94b resolves the captured item but current caller position, native first damage-property order, active damagetypes.DamageRangedProjectile and legacy failed-cell fallback. `BroadcastSafeProjectile14048f270..14048f544` queries current right-hand base BYTE and live area spatial uint32 IDs; actual clients within an inclusive3D range of either endpoint receive separate local records. Constructor default range45 is verified at14048bc91/DAT140dda4c8. These records are not NWN packets or rendered projectile effects.

`ComputeWeight140466660..140466902`, `GetWeight1404692e0..140469327` and `UpdateEncumbranceState1403db1e0..1403db49f` now retain active TenthLBS/armor/cost data, passive weight modifiers, signed stack multiplication, client/master eligibility, thresholds, shared caches and feedback ordering. Initial equipped mass is established lazily before the first consumption; complete native load/equipment mutation ownership is still open. Reduced container contents property32, additional unloaded cost tables and encumbrance movement-rate transitions remain explicit missing dependencies.

## Validation

963 tests and the production build pass. New focused cases cover ammunition, post-hit, projectile snapshot/delivery, future defender timing, near/far/blocked/outside misses, called shots, mass and consumption. Unit tests are instruction-derived regression checks, not independent original-engine observations. The atanf spot checks additionally compare float32 outputs with JavaScript Math.atan; that is a numerical cross-check, not a capture of the original CRT.

`scripts/smoke-ranged-strike.mjs` exercises active installed rules/area geometry through the live replacement ranged group and scheduler. It authors a bow/100 arrows on existing owned NPC fixture objects, disables their scripts, sets immortality and fixes replacement seed42. Three strikes produce hit/miss/hit, arrows100→97, HP20→14 and zero failing engine operations. Group count3 is supplied directly; this does not validate round creation, legal per-round counts or native encounter timing/RNG.

The existing independently captured45 combat observations, eight perception events and three deterministic death/XP observations still match. Installed fighter input still approaches/kills/awards1806XP with zero engine errors. None is an independent complete ranged-fight comparison.

Owned research and validation: `backups/animations/live-native-ammunition-owners-full-asm.txt`, `live-native-ranged-resolution-full-asm.txt`, `live-native-ranged-reaction-owners-full-asm.txt`, `live-native-ranged-miss-math-full-asm.txt`, `live-native-ranged-special-broadcast-encumbrance-full-asm.txt`, `live-native-ranged-limb-weight-object-asm.txt`, `live-native-called-shot-limb-cache-full-asm.txt`, `scheduler-baseitems-loader-asm.txt`, `live-native-get-item-weight-ghidra-asm.txt`, and `combat-native-ranged-*.txt`.

## Readiness limits

Combat is not ready. Event11 destruction/unequipping/owner changes and automatic ammunition replacement need full native equipment side effects. Called-shot type37/type29 application and broader melee special/status/on-hit/death attack owners are incomplete. Full faction/PVP/associate/history, corpse/encounter/trap, dirty information refresh, movement, native combat clip/UI/projectile presentation and independent complete native encounter/RNG/network comparison remain gates. Casting follows combat.
