# Spell impact, visual lifecycle and resistance — 2026-10-14

Target: NWN:EE89.8193.37-17. Original win32/nwmain.exe SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
The original install remains read-only. No binary/assets were copied into source.

## Verified implementation

- Visual apply140434fc0:298 original cases compare classification, source override,
  constant transforms, plot/destructibility, recipient range, narrowing and consumed
  versus retained results. Message records are internal delivery, not network packets.
- Add/remove looping14048da00/140498960:234 original cases compare duplicate retention,
  WORD/BYTE fields, capacity16/doubling, reverse last-match removal and record shifts.
  Transform map allocation/copy/equality are captured boundaries; script-generated
  constant scope0 is represented. Timed external controller import is unimplemented.
- Script log ordinal74 executes original Math140314240 and original CRT double SSE
  log140c927f0 for6018 comparisons, including subnormal positive FLOATs and the native
  zero result for nonpositive/NaN. Original FMA/CRT exceptional infinity ownership is
  not validated; infinity remains explicit in the adapter.
- ResistSpell14053bb30, GetSpellResistance140408dd0, SpellAbsorption140494890 and
  SpellImmunity140494650 compare967 isolated cases. VM/data/lookup/RNG/message and
  removal owners are captured boundaries. Absorption/immunity execute independently
  from wrapper cases. Active rules, signed BYTE wrapping, exact override1, AoE SELF,
  penetration priority, UserType1/3, consumption before feedback and duplicate client
  deliveries are preserved. UserType outside1/3 returns the native-1 after no immunity;
  it must not be silently converted to zero. Live binding uses canonical registry,
  current effects, existing caster/class/feat/RNG/feedback owners.
- Faction equality wrapper140524020 uses the existing native GetFactionOfObject
  guard/fields14055fb00 and signed INT identity, not a friendliness/reputation test.

## Authored integration evidence

Installed Prelude Magic Missile107 `NW_S0_MagMiss` directly receives impact8, then
its deferred situations execute with unrelated actor AI disabled. Probe-v6 completes:
target HP17→-11, no engine-call errors, visual delivery records and death feedback.
The target's authored spell reaction runs. Speech presentation and corpse cleanup
warnings remain recorded. Probe-v5 only drained immediately due events; its HP17→17
was not proof of no spell damage. Heal79 reaches application and visual delivery;
its lifecycle omissions remain recorded. These are explicitly impact probes, not
full cast admission/resource/conjure/release/projectile rendering acceptance.

## Further continuation and identity correction

Native link recursion/application188 cases, defense constructors/cache/icon
handlers498 cases, item-property queries360 cases, location wrapper/visual403
cases and shared Reflex/floating/distance411 cases compare. Live linked
resistance+visual expiration removes one64-bit group across all children/icons.
Resistance setters still explicitly report the unowned synchronous full
RecomputeCombatInformation1404171e0 tail; these tests capture that boundary.

Bless6 impact now completes without engine-call errors. Fireball58 impact and
deferred situations complete HP17→-17, preserving Reflex/Evasion handling and
location visual delivery. Fireball's area scan selects a placeable with missing
installed plc_w02 PWK; both resource/session failures remain recorded. No native
engine call remains in that probe. The first loosely named bless/fireball-v1
probe files actually contain Barkskin3/Doom46; their explicit script/ID fields
are authoritative. They are not Bless/Fireball acceptance evidence.

Knockdown had an existing incorrect constructor ID46, the actual internal
Disarm type. Original constructor134 produces20; registered apply/removal for
20 are42e980/437770. Binding/dispatch now use20, and the sorted linked state23
follows it. Default GetEffectType returns0 for this native newly exposed type;
all-types returns98, matching the active installed NSS constant. Failed tests
expecting Disarm34 are corrected rather than preserving an incorrect API value.

Original InitializeCommands54de30 now captures all1187 command owners; original
ExecuteCommand50d770 forwards raw IDs unchanged. InitializeEffects425c30 captures
99 apply/removal pairs. Future owner captures can check this mapping directly.
Earlier control-constructor-v1 captures for Petrify583/CutsceneGhost757 were
sent to the wrong generic owner; exclude them. Corrected v2 asserts actual
command-table entries and covers12 zero-argument constructors, including
Dominated's actual kind7/magical subtype. Application remains separate.

Haste/Slow visible balance and hidden controller behavior compare303 original
cases, including active HASTE_* overrides and distinct controller IDs. These
coordinators remain PURE/UNBOUND until movement28/29, Slow attack59 and attribute
update owners are connected. Haste1/Sleep8 constructors are live, but their
unsupported application paths continue to stop and report; no inert effect is
retained as a substitute. The unverified location-effect candidate50f310 was
unrelated; actual wrapper510710/area35bdf0/visual364670 support the claims above.

## Shared control continuation (1257)

Target remains EE89.8193.37-17, SHA2563b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a.
Movement increase42f320/decrease42f110, attack-count42ee20/removal437820
and movement-factor setter3a3670 compare399 original instruction cases.
Increase mutates the same INT cell before FLOAT multiplication. Speed removal
excludes all equal IDs; attack-count removal excludes the pointer. The setter
uses active penalty/default/Monk caps and raw last Monk level; field308 is
separate from native Haste760. Canonical hasted/slowed accessors share760/764.
Constructor37ac06/37ac0d zero those fields through QWORD75c/764 writes.

Visible Haste/Slow and hidden controllers are now live. Internal application
preserves duration3/4 rather than passing through the public script duration
normalizer. Controller copies retain ID, hide exposure and suppress non-icon
visibility. Cancellation and temporary expiry purge every controller child;
tests capture the still separate full-stat-refresh boundary rather than assert
it is implemented. Installed Haste78 impact completes without engine errors;
the existing generic AC icon/feedback diagnostic remains recorded.

Enchantment8 apply431730/removal438470, internal state9 apply432500/removal
438630 compare356 cases. Highest numeric state wins; IDs of parent and internal
controller differ. Application creates duration4 controller, while removal's
replacement is duration2 (initial4 assumption was caught by the oracle).
State8 removal restores another source before erasing the parent. Sleep,
paralysis, stun, confusion, fear, daze and charm now have live control children;
AddAssociate/possession and RemoveDomination remain explicit unsupported owners.
Existing native perception clear/update owners are reused on NPC removal.
SetLastHostile49b070 was verified independently: this is NOT orientation lock.

GetIsImmune5271d0, RecomputeAmbientAnimationState39db40 and effect-floaty
broadcast439ae0 compare261 cases. Native object-array SUCCESS is0 and connected
client field38 is required; initial captures with incorrect fixture boundaries
were rejected and retained. Correct capture-v4 is the accepted oracle. Floaty
message4d95a0 writes object32 and STRREF32; no native packet encoding or overhead
renderer is claimed. ObjectToString536fd0 uses raw DWORD %x (no padding/prefix).
Public control enums are verified in script-type-v3, including kind21's all-
types-only92. Original binary and Ghidra remain untouched.

Authored Sleep165 probe-v2 stops at ObjectToString; v3 executes a successful
save; v4-seed1 stops at GetIsImmune; corrected v5-seed1 receives native Sleep
state9, masks-257/-351, loop visual records and icon19. v4-seed2 saves. Both
completed branches retain speech presentation diagnostics. Probe seeds are
local fixture repeatability, not native startup/draw-order parity. Live state
test proves Sleep removal restores an underlying paralysis controller, then
clears masks/icons and returns idle when its final source is removed.

1257/1257 tests and build pass (existing bundle size advisory). Audit-v5 finds
840 rows/618 impact scripts/596 loaded/22 missing and196 unbound commands.
Binding presence does not assert all branches. Selected next owners: area
effects31/lifecycle and ability modifiers36/37, then full cast dispatch/render.

## Remaining work

### Ability and inventory continuation (1262)

Ability constructors517630/517510, apply427140/426db0, six stat getters
406930/3fd3e0/3fa0f0/402d10/40b5e0/3fa050, category4 of393340 and attribute
update3a7030 compare1932 cases in ability-effect-v2 (capture-v4 accepted).
Constructor selectors outside0..5 become0; amounts remain raw until admission.
Decreases mutate their magnitude to current score-3 before plot/positive gates.
Fifty slots per sign preserve native magnitude-1 free sentinel, independent
item/spell keys and signed INT sum/cap. Current score narrows bonus/gain/race
to signed BYTE before minimum3/unsigned-byte return. Public enums are38/39,
not an inferred old enum. Attribute refresh runs after insertion/removal,
maintains caches/dirty cells, preserves injury through CON maximum changes and
delivers dying/death/panel transitions through existing owners. Its separate
score/modifier/HP/encumbrance/event providers are captured in the native oracle;
this is not a full original-process interaction test. Initial oracle storage
overlap/stack-offset errors were corrected; failed captures are retained.

Live character calculation combines item and active ability sources under
native caps; cast ability admission now subtracts the total effect bonus.
Offline equipment source keys exist only in transient stat projections, while
live effects resolve canonical item creators through the shared registry.
No game objects receive synthetic preview keys or foreign saved IDs.

Strength's selected encumbrance dependency reached previously unsupported
property32. Repository CalculateContentsWeight465310 compares653 cases:
first active then passive owner property, fixed active IPRP cost table15,
per-child FLOAT subtraction/CVTT and two nested reads in the reduction branch.
Missing item nodes record a warning and continue as native does. Cost tables
load through existing resolver precedence/caching and failed loads remain
recorded. No reduced-container multiplier is inferred from property metadata.

Magical/Supernatural/Extraordinary wrappers544eb0 are live.640 additional
native subtype cases preserve packed duration/unrelated flags and update
linked metadata only for type40; original linked cases remain independently
accepted. AreaEffect constructor517830 and registered31 lifecycle427410 /
435eb0 have only assembly research so far; their lower object owners4f59d0 /
4f91f0 /4f7e70 /4f6720 are pending implementation/validation.

Installed Bull's Strength9, Cat's Grace13, Endurance49, Eagle's Splendor354,
Owl's Wisdom355, Fox's Cunning356 and Haste78 pass direct impact/removal probe
assertions. All before/after ability/HP/cache/control snapshots and canonical
identity restore; Endurance changes HP77→92→77. The first Strength probe's
bag-weight failure is retained; corrected v2 succeeds without engine errors.
Haste retains the generic combat-stat icon/feedback diagnostic. These are
isolated fixture seeds, direct impacts and removal, not full cast or visuals.

1262/1262 tests/build pass; existing bundle size advisory persists. All39 BICs
rechecked through spell-book import/use workers: sole prior PaleMaster HP102
vs114 error remains an explicit failing acceptance gate. Audit-v6:840 rows,
618 scripts,596 loaded,22 missing,191 unbound commands. Full ecosystem work
continues with persistent AoE ownership, casting dispatch and presentation.

Full ecosystem is unfinished. Actions15/18/request/UI are not live bound. Resistance
full synchronous stat refresh, floating feedback rendering,
many buff/debuff/dispel/area/summon handlers, saved effect import, VFX playback,
counterspells and interrupts still require their owners. Missing22 ImpactScript
resources remain audited. Native miss location, AoE spell context and full network
encoding/presentation are not replaced by guesses. Prior PaleMaster saved HP
import mismatch and existing campaign/combat readiness gates remain open.

Validation at this working continuation:1251/1251 tests and build pass. Build retains the
existing bundle size advisory. Failed capture attempts remain retained; only
completed observations and passing comparison captures above support claims.

## Persistent spell objects —1266 continuation,2026-10-14

Target remains NWN:EE89.8193.37-17, original win32 nwmain.exe SHA256
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a.
Original binary and Ghidra are unchanged. Failed captures are retained.

Evidence: generic EffectAreaOfEffect517830, object constructor4f59d0,
SetCreator4f91f0, LoadAreaEffect4f7e70, SetShape4f9310, SetDuration4f92d0,
AddToArea4f6720, InAreaOfEffect4f78f0, line crossing4f7b90,
UpdateSubAreas4f94c0, SetAnchor4f93f0, AIUpdate4f5de0,
RemoveFromSubAreas4f8c40, RemoveFromArea4f8bb0/destructor4f5b30,
EventHandler4f6b30, GetFirst/Next525fc0 and GetAoECreator51e290.
Registered creature31 apply427410/remove435eb0 and area35bdf0 creation
preserve distinct CGameEffect uint64 identity, VFX row ID and canonical
world-object uint32 ID. No spell names/campaign tags select runtime behavior.

1067 isolated original-instruction comparisons pass:173 value/metadata/shape/
heartbeat cases,716 spatial/cursor/anchor/shape/duration/event helper cases,
178 area/attached creation coordinator cases. Allocation, VM/string operations,
registry/casts, lower metadata/load/DC/clock providers, mutable list owners,
event delivery and area spatial insertion remain explicit captured boundaries
as recorded in the harness headers. Not original-process/world parity.
Captured successful observations: native-area-effect-observations.json,
native-area-effect-overlap-observations-v3.json and
native-area-effect-creation-observations.json. Comparison tests execute these
recorded fixtures. Earlier failed captures are excluded as acceptance evidence.

Circular/rectangular FLOAT geometry and sweep quirks remain native, including
the moving-circle point+old-center projection and boundary-only/asymmetric
line tests. Membership518 and following508 contain canonical AoE IDs; queries
store an area spatial WORD cursor308 on the AoE, not a copied target list.
Enter12/exit13 queue script event10. Removal runs exit synchronously before
area lists change. Heartbeats use the time remainder and suppress the first
pulse. Attached effects inherit their descriptor's lifetime; location effects
own their remaining millisecond counter. Original virtual+100 resolves to
49abc0, which writes DWORD+d8: earlier preliminary notes calling it animation
were incorrect. Production stores nativeFieldD8; no animation is inferred.

Live shared constructors/API now include EffectAreaOfEffect, GetAreaOfEffectCreator,
GetFirst/NextInPersistentObject (AoE branch), and raw-INT movement-speed effect
constructors51a920/51a830. Public GetEffectType31=20 is from the existing native
mapping oracle. Creation snapshots or reuses class/meta/DC/feat/spontaneous
context. Script callbacks/default tag/shape/radius come from the active physical
VFX_PERSISTENT row, with nonempty explicit callback overrides preserved.

Runtime integration tests create/delete/move anchored effects, check canonical
registry/spatial/AI/subarea identity and cursor behavior, and replace a physical
table row to change tag/radius without spell code. Installed Cloudkill23 and
Grease66 impact/enter/heartbeat/exit scripts complete through18s and explicit
deletion without engine errors; traced callbacks run at0/12000/18000. The first
speed-constructor failures are retained, corrected v2 succeeds. These controlled
self-target probes do not establish harmful-target saves/damage or cast resources,
conjuration/release, VFX/audio, full NPC AI, campaign or network parity.

1266/1266 tests pass and production build passes (existing bundle advisory).
Impact audit-v7:840 rows,618 scripts,596 loaded,22 missing,186 unbound commands.
Additional persistent callback audit:47 rows,75 unique scripts,68 loaded,
7 missing,9 unbound commands. Static binding presence never means full branch
support. Darkness/Silence still report unimplemented invisibility/silence;
Entangle references installed callback nw_s0_entanglea absent from both loaded
KEY maps. Record resource/engine failures rather than substituting spell code.

Open: trigger/encounter persistent enumeration, base destructor effect/owned-AoE
cleanup, non-AoE script-event branches and generic world destruction, preview
WASD subarea updates, complete native base HP/dead queries for noncreatures,
AoE/VFX presentation, saved active effects and remaining spell handlers. Full
cast request/action/release/UI remains unbound; original base-game playthrough
and sole prior PaleMaster HP102/114 import mismatch remain acceptance gates.

## Silence, invisibility and concealment —1271 continuation

Same original target/SHA256 as above. No original binary or Ghidra changes.
EffectComplex5180b0 ordinal252 produces Silence internal46/subtype8; the
native effect table assigns432f10/4387f0. Earlier informal notes calling46
Disarm were incorrect. GetScriptEffectType46=34 is unchanged and native.
Silence creates same-ID AI-state23/-9 (copy flag0), icon67/23 (copy flag1),
then writes cache75c=1. Immunity11 sends feedback145 to source/target before
rejecting; plot and loading/dead-duration gates remain native. Removal clears
75c even with another silence present; it does not manufacture a source count.
Linked AI masks/icons still remove by ordinary uint64 effect identity.
110 original-instruction cases compare, with copy/apply/immunity/feedback
captured separately. Live overlap tests verify the resulting cache/masks.

Invisibility constructor51a3b0 accepts script kinds1/2/4; invalid kinds return
an untouched invalid effect. Apply42e490 adds the canonical creature ID to the
module330 unique list and makes icon45/46 only for normal/improved invisibility.
Remove4372d0 retains the ID while another47 or sanctuary63 with a different
uint64 ID remains. The existing observer-specific GetInvisible/defensive owners
read those live effects; no universal invisible boolean replaces them.
Module array-list allocation capacity remains an adapter limitation.

Concealment constructor518a70 accepts percentages1..100 and maps selector1
→native ranged2, selector2→melee3, all other selectors→all0. Apply4280b0
admits noncreatures too, repeats percentage/dead-loading gates and copies
icon108. Native remove436280 simply returns1. Public type76=72 comes from
the existing original GetScriptEffectType oracle; an unverified temporary
mapping was corrected before acceptance. Existing ResolveDefensiveEffects
3e5630 reads live76 directly. Runtime tests verify ranged-only concealment
against that owner, removal and icon cleanup.

242 original invisibility/concealment cases compare (includes original72
invisibility cases; do not double-count them), covering VM enum/defaults,
copy flags, native branch decisions, source identity and linked payloads.
Capture limits exclude lower VM allocation, module unique-list operations,
copy, child application and feedback implementations. Static174af0 inspection
verifies duplicate suppression. The native module list is shared with existing
observer visibility, not a spell-local cached target list.

Installed self-target Silence163 impact/enter/heartbeat/exit completes through
18s and explicit deletion without engine errors. Invisibility90 and Improved
Invisibility88 authored impacts and explicit removal restore ability/HP/control,
icons, silence/vision and module invisible-ID snapshots. Improved invisibility
contains47 plus76; the previous missing EffectConcealment failure is retained.
Darkness36 now reaches its separate unimplemented EffectDarkness dependency.
No script is reimplemented under a spell name or special campaign condition.
These probes do not exercise cast requests/resources/release, full NPC AI,
visual presentation, native-process/world parity or campaign completion.

1271/1271 tests and build pass; existing bundle advisory persists.
Impact audit-v9:184 unbound commands,22 missing scripts. Persistent callback
scan-v3:7 unbound commands/7 missing callback resources. Static bound presence
is not branch completeness. Next researched owners: Darkness74
42a590/436590, blindness73 427bb0/435fe0, miss chance75 42efa0/4378c0,
vision state69/89. Those handlers remain unbound and diagnosed. Base effect/
owned-AoE destruction, ordinary DestroyObject, full casting actions/UI/VFX,
PaleMaster HP102/114 and base-campaign acceptance remain open.
