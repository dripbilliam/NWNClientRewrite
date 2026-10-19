# On-hit spell requests and generic unlock actions

The preceding permanent-effect turn made concrete progress and sealed a verified
1975-test backup. This increment continues the full ACTIVE single-player goal;
spells, combat and base-campaign acceptance remain incomplete.

Read-only target: NWN:EE89.8193.37-17 x64,
`../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
No original installation or Ghidra project modifications. Native dossiers,
captured observations, failures and verification logs are retained under
`backups/animations/`.

## Five remaining on-hit spell owners

| Original method | Inclusive range | Active spell row / native caster level |
| --- | --- | --- |
| ApplyOnHitDispelMagic(item) | `1403df7b0..1403df8fe` | 41 /10 |
| ApplyOnHitLesserDispel | `1403e0b80..1403e0cce` | 94 /5 |
| ApplyOnHitGreaterDispel | `1403e0500..1403e064e` | 67 /15 |
| ApplyOnHitMordysDisjunction | `1403e0e60..1403e0fae` | 122 /20 |
| ApplyOnHitKnock | `1403e0a00..1403e0b7e` | 93 /1 |

These constants are literal native engine references, not a new spell-effects
database. `applyEngineOnHitSpell` looks up the active spell and impact script,
constructs the original attack-owned CNWSSpellScriptData and appends offensive
list+c0. The existing strike signal schedules event19 to the original caster;
the receiver installs/restores item context and runs the installed NCS script.
The DispelMagic property overload continues to create51[10], independently of
the item-ID overload. No individual script effect is fabricated in JS.

Knock first checks raw target typeBYTE9/10, then door and placeable casts, then
nonzero lock states. The original area lookup runs once for null or twice for
a present area. Payload keeps canonical caster/target/item/area IDs, native XYZ
float32 point, featFFFF, script and exact caster-level override.

`inspect-native-onhit-engine-spells.py`: all five COMPLETE owners and the Knock
payload constructor run original instructions. **376 cases PASS**, covering
missing spells/allocation, null area, BYTE attack index, signed/full-width IDs,
target kinds, both casts and raw lock INTs. Lower spell/script copy, allocation,
area, cast, attack and append helpers are captured. This independently verifies
request construction and gates, not effect scripts or an entire attack round.

## Native door lock storage

`door_lock_fields.js` binds OpenLockDC BYTE+41f, Locked INT+424 and KeyRequired
INT+450. Constructor stores at14041d8e6/8ec/8c6 initialize zero. Original
LoadDoor segments140420b97..bbf,140420c11..c3a and1404220c1..0e9 read typed BYTE
fields, preserve the previous LOW BYTE on failed reads and normalize BOOLs.
ReadFieldBYTEasBOOL1401a0f60..0f7f executes its original conversion in the oracle.
Load-time integration reads actual GFF type metadata; it no longer projects raw
door Locked values without the native BOOL reader. The live difficulty is now
available to native on-hit Knock admission, replacing an unsupported branch.

`inspect-native-door-lock-fields.py`: **1501 cases PASS**, using original
constructor store fragments and three load/read/store fragments; typed BYTE
reader admission is captured. Tests serialize/parse real GFF fields, including
wrong types, absent fields, non-boolean bytes and fallback-byte narrowing.
This is not a claim that the full door constructor/resource loader is ported.

## Spell notifications on world objects

Installed Knock sends spell notifications to nearby doors/placeables. Previously
the event10 receiver rejected those as unsupported noncreature perception.
The new world notification owner follows door14041fbe6..14041fc73 and
placeable1404b37dc..1404b3883: preserve raw caster ID, store spell/harmful fields,
ANY nonzero harmful flag invokes hostile history and optional creature
broadcast/excitement/invisibility removal, then always RunEventScript8/9.
Unlike the creature owner, there is no AoE-caster rewrite, dead gate,
initiative or faction/reputation mutation. **96 original-branch cases PASS**.
Getter/helper/callback boundaries are captured; full EventHandler dispatch and
payload destruction are separate owners.

REA's complete EventHandler response exceeded transport budget. Original
analysis remained retained; bounded inspect_analysis_view projections recovered
all38227/34654 pseudocode code units and1572/1424 assembly entries, without
restarting the live research session. Both the resource-constraint evidence and
complete text/assembly projections are saved (`rea-*-spell-event-*`).

## ActionUnlockObject and self-unlock execution

Knock's installed script uses a normal `AssignCommand`/`ActionUnlockObject`
sequence. The missing engine binding is now connected to the generic action
queue; there is no Knock-specific direct lock change.

- VM ExecuteCommandActionLockActions14050e340..14050e3f9, ordinal483, resolves
  the world-object caller and calls AddUnlockObjectAction with invalid tool/0.
  The shared native function's ordinal484 lock path is NOT claimed implemented.
- AddUnlockObjectAction14048ddf0..14048df62 rejects only commandability==0,
  appends action38 with canonical target/tool IDs and raw property INT, preserves
  group increment/wrap and twelve native parameter slots. No premature target,
  area or death checks.
- Noncreature AIActionUnlockObject gameplay branch1404a878a..1404a970a:
  exact dead/dying==1 rejection; item/object/world lookup; locked/key-required
  gates; self-ID unlock; successful ScriptEvent29; key-required ScriptEvent34;
  native completed2/failed3 results. Door/placeable locks both use live cells.
- Event34: door stores caller in raw4b4 and invokes OnFailToOpen/script14;
  placeable has no native case34 and consumes it. Event29 uses the existing
  unlock event receiver. Missing creature range/skill/tool/timing/animation and
  cancellation owners remain explicitly diagnosed, not silently completed.

`inspect-native-unlock-action.py`: **266 cases PASS**. Complete Add owner and
all noncreature gameplay branches run original instructions. The disabled
profiler setup/epilogue is excluded; original gates, field writes, group wrapping
and event generation remain intact. Cast, lookup, health, allocation, event
constructor/list append/scheduling are captured lower boundaries. Cases include
same/different canonical target, missing/nonworld target, raw lock/key INTs,
nonstandard dead flags, parameter sign extension and groupFFFF wrapping.

## Installed acceptance and regressions

`installed-onhit-engine-spells-v7.json`: **PASS5 families**. Active property
chance/DC admission produces each exact payload, actual melee signal schedules
event19, all four installed dispel scripts remove at least one existing shared
buff ID, and caster override/context restores. Installed Knock unlocks a live
nonplot door, preserves a plot-protected door, and rejects a key-required door
through event34 plus authored `nw_od_feedback1`. Protected fixtures must have
actually received spell93. All prior canonical references AND allocation cursor
remain unchanged. No original module/item/template resources change.

Fixture scope is explicit: startup/general AI disabled; controlled live lock,
plot/key/difficulty values and explicit chance seeds; unrelated signal hit/damage
events are captured, while real spell events/situations/actions/scripts execute.
This is not whole strike/door combat/campaign acceptance. Initial failures exposed
the missing world receiver and engine binding; earlier fixture expectations also
wrongly asked a plot door to unlock and assumed an unrealistically small search
radius contained two extra nonplot doors. Corrected the fixtures to exercise
actual native protection. Tests never added campaign-specific production cases.

Dispel fixtures retain speech presentation warnings; the final Knock fixture
retains one one-liner overhead/token presentation warning. No gameplay errors in
the accepted run. Load diagnostics remain retained per session. UI shutdown GPU
text is retained in its log; all casting assertions pass before exit0.

- **1979/1979 full tests PASS**, build PASS (existing bundle warning).
- Casting UI PASS: spellbook, self radial, slots, F2 targeting, animations,
  cancellation and22 counterspell/radial checks.
- Installed permanent on-hit regressionv7 PASS9; common duration/control-frame
  regressionv7 PASS13.
- Active ecosystem auditv54:840 spell rows,596 loaded impact scripts,
  **53 unbound commands and22 load failures**. Exit1 intentionally preserves
  unresolved script loads. Bound ActionUnlockObject is confirmed; binding
  presence is not proof of every creature/action branch.

Next: native death/corpse/body-bag cleanup and remaining spell/combat owners,
including creature unlock/cancellation, generic effect admission/import and the
active audit gaps. Full campaign playthrough remains uncompleted. Goal ACTIVE;
single-player first. No user pause or completion claim.

Verified checkpoint `backups/on-hit-engine-spells-1979-20261017-v1.zip` contains
10829files/150742752bytes. Every archived length/SHA256 matched source;
`on-hit-engine-spells-checkpoint-v1.txt` terminal0. This verification note was
added after sealing; no validation or backup writer remains pending.
