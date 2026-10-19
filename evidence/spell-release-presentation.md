# Spell release messages and projectile dispatch

Target: NWN:EE89.8193.37-17 x64 nwmain.exe SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original binary/install/Ghidra project remain read-only. Warm isolated REA65686
provided dossiers; independent Unicorn captures execute original instructions.
No spell-specific runtime substitutions or module exceptions were introduced.

## Native owners

SpellCastAndImpact14049c4b0..14049ca5b:

- Ordinary non-instant creature release constructs message objects[0]=caster,
  objects[1]=item and integers[0]=physical spell ID. Target creature lookup is
  performed even forINVALID. If the target's master is the caster, and the
  item is base49/104, message objects[0] becomes that target ID. Broadcast owner
  and event8 caller/recipient/caster remain the original caster. Call49c629
  invokes BroadcastSpellData48f550. Existing countered/once guards are unchanged.
- With animationD8==10, native origin becomes position+orientation*.4, then
  Z+=.6, using f32 arithmetic. Other animations keep the raw position.
- HasProjectile19c must equal1. A creature target uses its release-time position.
  Other targets use stored native cast point208, not the passed impact Vector.
  For a creature caster and item target, equipped membership or recursive
  repository membership suppresses the projectile. Calls49c7ad/49c7d3 use the
  existing native inventory/repository owners. No arbitrary ownerId shortcut.
- Appearance is6 for zero pathBYTE,7 otherwise. Flags carry the spell ID; result0,
  deflection/path the narrowed BYTE, duration the caster DWORD220. Existing
  BroadcastSafeProjectile48f270 routes actual local recipients. The impact event
  still uses the passed Vector. GetArea49c89e/49c8ab determines areaID orINVALID;
  a stale raw actor areaID does not become a valid event area.

BroadcastSpellData14048f550..14048f8b4:

- Resolve the caster area through ObjectArray/AsArea. A creature caster with
  nonzero GetIsDM402f80 suppresses broadcast. GetArea is then a separate lookup.
- Before every physical area entry, reset payload INTs1,2,3 to0. Resolve its
  creature; require an existing visibility node with seen bit1, an actual client,
  and inclusive f32 XYZ distance<=30m. No extra spellcraft/RNG draw at release.
- For creature casters without an item, INT1 is exact Contains==1 from the
  identified-observer list808. This is the earlier cast-start decision.
- For a present item, a DM creature possessor aborts the whole broadcast. INT1
  becomes1 for direct caster possession, an item container possessed by caster,
  or a creature possessor whose master is caster. INT3 stores the item's base
  type. A missing item still sends the reset payload. INT2 remains0 at release;
  existing BroadcastSpellCast sends1 during cast start.
- SendServerToPlayerCCMessage4cf090 is called at48f86d with message type8.
  Runtime retains a native-shaped internal body; native wire encoding and client
  receiver presentation are separate, unfinished owners.

Constructor evidence uncovered while probing installed casts:

- Creature ctor37a3a2 clears EBX.37a449/37a450 clear inline list808..817.
  Runtime now initializes the identification list independently of cast start.
- Ctor37a608 setsR12D=1 and37a53c clearsESI.37abb1..37abcc calls
  AddToVisibleList3d0db0(self,seen1,heard1,state0,retained0) at37abc7. Runtime
  previously created an empty list, so isolated casters received no release
  message. Newly constructed canonical creatures now get the native self node.
  Existing explicitly supplied test/import visibility storage is preserved.

Read-only dossiers: `rea-spell-release-presentation-owner.json`,
`rea-broadcast-spell-data-body.json`. Constructor disassembly/field references:
`spell-identified-list-ctor-v1.txt`, `spell-identified-list-field-v1.txt`.

## Implementation and validation

`spell_release_presentation.js` supplies the shared data/message/projectile
owners to ordinary, feat, innate and item cast execution through SpellRuntime.
Active spell metadata and installed scripts remain authoritative. Canonical
uint32 object IDs and uint64 effect identities are not replaced or allocated.
Full client DM/transport import is still separate; local DM lookup uses actual
local client identity and the native nonzero-associate guard.

Final `inspect-native-spell-release-presentation.py` capturev4 executes3922 cases:
2192 complete BroadcastSpellData,1728 ordinary SpellCastAndImpact and2 bounded
constructor blocks. Registry/casts, DM, node/client/identified queries, message
storage, inventory, Vector addition, transport/projectile broadcast and scheduler
are captured lower boundaries. Original HasProjectile/owner/position/message/
distance/iteration/constructor instructions execute. These are not full native
client or renderer runs. Independent tests caught the initial oracle intercepting
the broadcaster entry; capturev3 executes that body, v4 also captures constructor
blocks. Earlier runs are retained and not cited as passing semantic evidence.

`spell-release-presentation-native.test.js` compares calls, messages, f32 points,
ownership and post-state against original captures, plus canonical construction.
Existing ordinary/countered impact, sanctuary, generic removal and casting tests
pass. Full1808 tests/build pass.

Installed probe final `installed-spell-release-v2.json` chooses the first real
ready projectile spell from the installed wizard: active row37/NW_S0_Daze in this
installation. Through the actual player queue it consumes one prepared use,
delivers one release message and one safe projectile, and runs the original impact
script once with unchanged canonical object allocation. Native AI/startup isolated;
message callback captures internal delivery, not native rendered projectile proof.
The initial probe found no self-visibility record; corrected construction, not
a bypass of release visibility, fixes it. The failed probe retains pre-existing
missing plc_w02 diagnostics. Final cast-window diagnostics are empty.

Installed item casting (three uses/stack consumption/destruction), druid WildShape
and barbarian Rage feat casting pass after the shared changes. Sanctuary prepared
casting and invisible henchman dismissal also pass; its old release-broadcast
warning is gone in the headless integration callback.

Final built-client generic casting UI regression passes spellbook, radial self,
slots, hotbar/F2, animation/cancel and Counterspell. Sanctuary self-wheel/class/
level/used-slot/effect-icon regression passes; current screenshot was inspected.
Both logs retain Chromium GPU teardown warnings after assertions. The screenshot
still has dark/occluded world geometry and a creature-death notification. No
issue-free graphics, full AI or campaign acceptance is claimed.

## Remaining client work

Server broadcast/projectile routing is connected. Native cast/release CC message
consumption, safe-projectile receiver/model/motion/attachments and wire encoding
remain unfinished. Main now records specific `spell.client-message-unimplemented`
and `visual.projectile-receiver-unimplemented` with canonical source/target/item,
spell/flag, endpoints and duration, instead of only a generic message-type warning.
These warnings deliberately remain in rendered sessions. Current Sanctuary UI
capture shows both cast-start flag1 and release flag0 with identified1.

The exported REA Projectile search has six server symbols and no named client
receiver. That search is not evidence the receiver does not exist; locate the
stripped client consumer from message dispatch/data references next. Continue
remaining effects/calls, full combat, then campaign. Auditv47 remains65 unbound
commands /22 missing resources. The persistent goal is not complete.
