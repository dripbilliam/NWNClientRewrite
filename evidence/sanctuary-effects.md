# Sanctuary and combat invisibility lifecycle

Target: NWN:EE89.8193.37-17 x64 nwmain.exe, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original install/binary/Ghidra project remain read-only. Warm isolated REA session
provides dossiers; original instructions execute separately in isolated Unicorn.

This implements the engine's reusable EffectSanctuary contract, not a replacement
Sanctuary spell script. Runtime spell selection, DC/duration/metamagic and authored
effects continue to come from active data and installed NWScript. The explicit
`NW_S0_Sanctuary` lookup is in integration tests only. Effect/icon enum constants
are native engine behavior shared by every caller of this effect.

## Original owners and behavior

- ExecuteCommandEffectSanctuary14051b1c0..14051b30e pops DC, then an optional
  flag when argc>1 (default1). Pop failure-639; push failure-638. DC<=0 still
  allocates an invalid base effect. Positive DC produces type63, subtype8 and
  INTs[0,1,4,5]=[8,28,DC,flag]. DC/flag remain raw signed INTs. Installed active
  nwscript declares only the DC argument; the active VM signature is preserved.
  The model/oracle also cover the binary's optional flag. Constructor SetCreator
  is a captured lower here; existing effect-creator implementation supplies it.
- OnApplySanctuary140431120..14043135c rejects loading onto dead targets except
  duration3/4. A creature with an area traverses the live physical area list,
  excludes itself and touches existing observer visibility nodes only. It does
  not gate this initial pass on hostility/vision. GetInteger calls at4311cf/de
  read DC/flag. Initial save431266 is Will3, BYTE-narrowed DC, category0, subject
  ID, feedback1, feat0, attackFeedback0. A successful BYTE result sets bit8 and
  clears4; failure/no-save pacifies then sets4/clears8. Module invisible list
  receives a unique subject ID. A real clearing copy constructor creates icon67,
  icon52 with saves or107 without, and applies it with the original loading flag.
- OnRemoveSanctuary140437ff0..140438245 returns1 without creature/area. For all
  physical area entries, state8 clears bits12 immediately; state4 records observer
  IDs. From the native cached effect indexDA2, types47/63 with a different uint64
  source ID keep the module invisible list; another63 also retains blocked nodes.
  Otherwise module membership is removed and recorded observer nodes are removed
  after traversal. Same-ID linked records do not preserve this state.
- Targeted PacifyCreature140399b50..140399c26 looks up the observer and tests
  target cells728,724,73c,740,190 against the subject ID, in that order. A match
  clears timer704, sets744=100 and6fc=1; if a round exists it calls
  RemoveAllActions378d60/ClearAllAttacks3754d0 and invalidates724. It clears700,
  forces last-hostile190 toINVALID only if it matched, then calls
  ClearHostileActionsVersus387bf0(observer,subject). Runtime uses the already
  verified matching SetCombatState(0) body and existing hostile-action cleanup.
  The separate no-argument area-wide PacifyCreature overload is not implemented
  by this increment.
- RemoveCombatInvisibilityEffects14039e500..14039e5a1 starts at stats WORDDA2,
  removes type47 only for INT0==1 and all type63, and stops beyond type63. Call
  39e573 invokes RemoveEffectById498280, not single-record erasure. It re-reads
  DA2 afterward. Runtime now connects this owner to the existing native-tested
  linked-ID removal lifecycle, including attached icons/visuals/caster targets.
- CNWSObject constructor14048ba87 initializes last-hostile DWORD190=INVALID.
  Installed probing exposed a missing runtime default; canonical world objects
  now initialize that same cell. Existing authored/live writes remain preserved.

Dossiers: `rea-sanctuary-{construct,apply,remove}-body.json`,
`rea-pacify-id-body.json`, `rea-combat-invisibility-removal-body.json`.
Constructor field proof is in `live-combat-getters-object-ctor-asm.txt`.

## Verification and limits

`inspect-native-sanctuary.py`, final capturev2, records1545 original-instruction
cases:384 constructor,832 apply,168 remove,128 targeted pacify,33 combat removal.
The complete native clearing-copy constructor runs743 times. VM/base allocation,
registry/area/node lookup, saving throws, pacify during apply, round/hostile clears,
linked-ID erasure and child application are captured lower boundaries. These are
not full native-game/AI/renderer executions. The first oracle run stopped at an
unmodeled realloc thunk; finalv2 uses the verified4380f6 ->c4f038 target.

`sanctuary-native.test.js` compares guards/order/state/payload/error contracts and
checks live linked icon cleanup and stacked sources. Existing generic removal,
invisibility, combat and henchman tests still pass; malformed effect records
remain diagnosed, not silently discarded. Full1805 tests/build pass.

`probe-installed-sanctuary.mjs` final report `installed-sanctuary-v2.json` passes:
real NCS constructor/application; canonical observer pacification and linked
cleanup; installed cleric prepared-player cast; original Sanctuary script154
selected from active data; actual slot consumption/release; final effect/icon/node
cleanup; invisible henchman dismissal and no object-ID allocation. The initial
no-save observer fixture authors payload INT5=0 after invoking the installed
one-argument constructor; it does not override the active script ABI. Ordinary
cast uses the unchanged default save flag and actual saving-throw engine. Startup
and unrelated AI are isolated. One existing warning remains:
`spell.impact-broadcast-unimplemented` (native release presentation broadcast).

Rendered `smoke-live-casting-ui.cjs --sanctuary` passes actual right-button self
wheel/class/level selection, canonical automatic target, queue/release, installed
impact, icon pool and physical used slot. `live-sanctuary-ui.png` was inspected.
Native AI is enabled there; no new error-severity failures occurred. Existing
trap/frame/AI/lifecycle/animation/material/lighting/audio/presentation warnings
are retained in `live-sanctuary-ui.json`. The world remains dark/occluded in this
fixture and a creature-death notification appears; this is not issue-free campaign
acceptance or complete visual/audio parity. Final generic casting regression also
passes spellbook, hotbar/F2, radial, animations/cancel and Counterspell. Its log
retains an existing Chromium GPU teardown warning after assertions passed.

Auditv46:65 unbound commands /22 missing resources. Full spells/combat/campaign,
remote transport/client snapshots, full save engine/AI and native release
presentation remain incomplete. No goal completion is claimed.
