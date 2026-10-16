# Summoning lifecycle — October15,2026

October16 correction: event24 and native heartbeat now share
`nativeSpawnState548`. The old event adapter wrote a separate JS property and
could repeat OnSpawn. Updated original-event comparison, combined heartbeat
regression and installed Summon Creature VII lifecycle pass. See
[creation audit and exact validation limits](create-object-lifecycle.md).

Target NWN:EE89.8193.37-17; original installed nwmain.exe SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original executable, assets and Ghidra project remain unchanged. Sources below
are shared engine coordinators, not spell-specific effects or campaign tags.

## Live summon ownership

`src/summon_effect.js` contains constructor83, OnApply/OnRemoveSummonCreature,
and delayed creature event24. `src/summon_associate.js` contains native type4
AddAssociate and UnsummonMyself. They are now connected to EffectRuntime,
the VM and delayed creature events through ObjectLifecycleRuntime. The installed
wizard's ready Summon Creature VII runs its authored impact/spawn scripts,
spends its actual memorized slot and creates an inventory-owning canonical
creature with area membership, master ID and associate type4. This establishes
the tested summon path; the full spell ecosystem remains unfinished.

- ExecuteCommandEffectSummonCreature14051bf80..14051c281 allocates internal
  effect6/subtype8. Args1..4 populate string0/INT0/FLOAT3/INT1. Argc5 ignores
  its fifth argument: only argc>=6 reads both unsummon visual and existing
  creature ID. Defaults are visual-1, delay0, appear0, unsummon99, invalid ID.
  Empty-string adoption of a PC emits type0/subtype8 before creator tagging.
  Otherwise creator tagging precedes strings/objects0,2/INT0..3/FLOAT3 writes;
  INT2=1 marks a custom unsummon definition. All raw values remain intact.
- Base effect defaults were checked separately at140423529..140423547:
  all four object IDs are invalid, not zero. The captured constructor fixture
  now initializes those verified defaults. Full constructor assembly must be
  used: Ghidra falsely ends at FUN140c10370, as in other EH-wrapped owners.
- OnApplySummonCreature140433d70..140434427 skips only loading==1. Adoption
  resolves object2 and requires invalid master, optionally plays visual at its
  existing location, writes object1 and calls AddAssociate4. Missing/busy target
  returns consumed1. New-template application constructs first, fills area0
  and FLOAT0..2 from the recipient only when area0 is invalid, then resolves
  the area and loads the truncated/lowercase16-byte resource reference. Missing
  area destroys the allocation and returns0; failed template load warns,
  destroys it and returns1. Successful safe-location range20 replaces the
  point only on return1, then computes height. Delay is clamped to0 unless
  FLOAT3>0. Visual uses type30/subtype0 and the summoner's orientation.
  Event24 is scheduled with caller AND recipient equal to the effect recipient;
  payload contains spawn point, allocated canonical ID and appear argument.
  Only then object1 is stored and feedback154 is sent. Effect returns0/retained.
- OnRemoveSummonCreature140438ca0 resolves object1 and invokes UnsummonMyself
  if present; always returns1. It imposes no master/type/area gate.
- Event24 at14038fb0f..14038fc54 resolves the allocated ID and the recipient's
  area **at delivery**, asks for that area again, AddToArea(...,0,1), writes548=1,
  invokes spawn script8, then adds associate4. A nonzero appear argument creates
  type81 with the summoner as creator and applies it to the new creature.
  The second area lookup and spawn-script-before-association order are retained.
- AddAssociate1403d0410 type4 exits for self, queries module, scans physical
  associate IDs for the first type4, resolves that ID again and unsummons it
  before resolving the new target. Movement categories2/3/4/7 reset to0;
  listen patterns, type, master precede unique list append and two faction
  lookups/AddMember0. Other associate categories need their distinct owners.
- UnsummonMyself1403daee0..1403db1df obtains message transport and clears
  actions. If in an area, it finds the first master's effect6 whose object1
  matches this creature. INT2==1 selects INT3; a negative value suppresses
  visual, otherwise the default visual is99. It handles open character-sheet
  observers, resolves the master again for feedback155, and schedules self
  event11 at zero delay. It does **not** remove associate IDs immediately.

The area-point effect6 branch in location_effect.js was already present but
incorrectly labeled beam; its semantics are summon-to-location. Comment and
diagnostic field naming are corrected. Beams have a separate internal type32.

## Verification

Unchanged original instruction bodies execute in a read-only PE mapping. Each
fixture records its captured lower allocation/query/VM/geometry/script/event/
transport boundaries. These comparisons prove coordinator state and ordering,
not full behavior of those lower owners or original-process gameplay.

| Oracle script | Original observations |
| --- | ---: |
| inspect-native-summon-constructor.py |1742|
| inspect-native-summon-lifecycle.py |162 apply +6 remove|
| inspect-native-summon-event.py |41|
| inspect-native-summon-associate.py |641|
| inspect-native-unsummon.py |448|

Total3040. Includes argument grouping, PC rejection, raw values, bad resources,
area/visibility boundaries, delayed script/association ordering, duplicate and
stale IDs, custom negative unsummon visual, missing masters/clients and observer
gates. Native return values preserve RAX across captured security-cookie checks;
early incorrect boundary captures/reports are retained, final artifacts replace
their observations. Focused report:summon-lifecycle-focused-v7.txt. All1352 tests
and production build pass:summon-foundation-{full-tests,build}-v1.txt.

Current source constructor tests omit failed VM pop paths because our public
JS adapter receives already-decoded arguments. Native fixtures retain those
failure observations. Live verification is described below.

## Ownership connections and live verification

New original instruction comparisons cover area removal (96 object,320
creature), nonclient area insertion (72 object,97 creature), RemoveAssociate
(352), creature/item/repository/equipment destruction (513/8/4/4), base-object
destruction (80), and float seconds-to-world-date conversion (55).
The corresponding native-*-observations.json files and inspect-native-*.py
scripts record lower captured boundaries and exact inputs. These are bounded
coordinator comparisons, not independent original-process gameplay acceptance.

Native owners: area RemoveObject140364cc0, creature RemoveFromArea14039e6b0,
area AddObject14035ba90, creature AddToArea140380470, RemoveAssociate1403d6e10,
creature destructor14037b440, item destructor1404631c0, repository140463120,
equipment140462880 and base object14048bf10. Seconds leaves140597010/140597140
use repeated float subtraction, not modulo. Target build/hash is above.

Creature destruction removes the associate, area/spatial/perception, AI/tag and
canonical registry owners in the original order. Repository children and18
equipment slots are separately resolved and destroyed. Base destruction deletes
the registry entry before reverse effect-memory disposal and forced action
disposal; it does not invoke gameplay OnRemoveEffect for stored effects.
Stale IDs and duplicate tags retain the original list semantics. C++ heap frees
are represented by local ownership disposal, not a JS memory-layout claim.

probe-live-summoning.mjs / live-summoning-v2.txt and live-summoning.json verify:
real spell181 and authored NW_S0_Summon/NW_S_FIREHUGE; slot1→0; replacement with
old inventory destruction; native strict expiry equality; explicit removal;
expiry before delayed spawn without resurrection; existing-NPC adoption without
allocating a replacement ID; PC adoption rejection; delayed DestroyObject.
probe-live-destruction.mjs verifies owned item/area/AI/tag/registry cleanup and
unchanged next-ID allocation. Startup/general AI are disabled in these isolated
fixtures. Resource failures and unavailable VFX remain diagnosed.

Rendering now detaches removed/moved NPC views, unbinds animation ownership and
disposes only private animation geometry. Canonical registry allocation remains
separate from view removal. Isolated Electron smoke-live-summoning-ui.cjs uses
real ground right-click input, the Wizard levels7–9 menu and Summon Creature VII;
the installed slot becomes spent and a model/animation view binds a canonical
type4 associate with the player's master ID. JSON/PNG and v3 report are saved.
Mask44 correctly disables this spell on self. Camera projection is checked inside
the viewport. Subsequent v5 renderer smoke also selects the actual summoned
model and uses its native Associate actions/Unsummon command; the view disappears
after deferred destruction, with0 renderer errors. The live engine v3 probe
checks dismissal ownership loss/recheck and retained master effect. See
[Associate commands](associate-command.md). All1,366 tests and production build
pass at this later checkpoint.

Remaining ownership limits: PC/DM ClientArea handshake and automap, active barter
or dialog destruction, retained-area trap observers, dead-NPC body-bag transfer,
and noncreature DestroyObject event11 receivers. Familiar/animal companion,
possession and other associate command/application owners remain unfinished.
Unsupported branches continue to report diagnostics rather than silently
deleting ownership or simulating unavailable systems.

## Prior research trail

Read-only captures in backups/animations:
native-summon-{create-destroy,associate,event,base-effect}-asm.txt;
ghidra-summon-{creature-remove-area,creature-destructor,appear-apply,appear-queue}.txt.
Original destructor pseudocode incorrectly returns after individual frees;
capture complete assembly, its base destructor and owned-object lifetimes.
Creature destruction must handle inventory/effects, master/list membership,
AI, tags/registry, area/subarea/spatial and perception ownership. Do not simply
unregister the object or discard stale arrays. Existing corpse event11 coordinator
in corpse_lifecycle.js already has3456 original comparisons; supply actual
area-removal/destructor owners before connecting it.

Appear81 is now wired separately, including animation63/95, queue52, group
interruptibility, fixed2000ms timing and common cancellation cleanup.142 native
cases and a live installed-character effect/action probe pass; see
[Appear effect](appear-effect.md). The NPC summon path now supplies the shared
area/associate/destruction owners, within the limits above.
Active NWScript constants: EFFECT_TYPE_SUMMON_CREATURE100, APPEAR91, unsummon
visual99. Verify native GetEffectType visibility before adding public mappings.
Bindings, spawned script errors, dynamic rendering, resources and removal/expiry
must be exercised using installed summon scripts and actual low-level characters.
