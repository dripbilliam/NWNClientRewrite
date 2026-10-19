# Henchman ownership and module limits

Follow-up: [Sanctuary/invisibility lifecycle](sanctuary-effects.md) now connects
combat invisibility removal to linked effect cleanup and verifies invisible
henchman dismissal. The unsupported-removal note below describes this checkpoint.

Target: NWN:EE89.8193.37-17 x64, nwmain.exe SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original binary/install/Ghidra project remain read-only. REA analysis uses the
isolated project integration and warm session; no game patches or asset copies.

## Original evidence

The executed InitializeCommands table maps365/366/503 to
ExecuteCommandAssociateAccess140510b50..140510ceb. REA's combined owner explains
why searching for separate AddHenchman/RemoveHenchman exports finds none.
`rea-henchman-access-body.json` includes the original call-site assembly:

- StackPopObject286160 at510b7b and, only for argc2,510b99. Failure returns-639.
  The second local startsINVALID; omitted raw arguments do not becomeSELF here.
  Normal compiled calls generally materialize optional arguments.
- Add365 looks up master/target, rejects nonzero target PC DWORD89c, possessed
  familiar3d54d0 and stats DM402f80, then calls AddAssociate3d0410 type1 at510c2a.
- Remove366 requires target WORD908==1 and master DWORD8fc equal to the supplied
  owner. Calls SetActivity3a2650(1,0) at510c80, RemoveCombatInvisibility39e500 at
 510c88, then RemoveAssociate3d6e10 at510c94, in that order.
- RemoveSummonedAssociate503 compares GetAssociateId3d4d70(type4,nth1) before
  invoking RemoveAssociate. It does not directly destroy/unsummon the object.

`rea-associate-add-all-body.json` maps AddAssociate3d0410..3d0958. Type1 counts
physical entries whose current creature WORD908==1; duplicates count and stale
IDs do not. When a module exists, signed cap3fc<=count sends feedback49 with the
cap, before looking up the new target. Re-adding an existing target is subject
to this same gate. Self-ID returns before module lookup. Accepted targets use
the same movement-rate normalization/listen/type/master/unique-list/faction
tail already modeled for type4 summons. Type5/6 paths are separate and unchanged.

Module constructor478922 writes QWORD3fc=1 (adjacent400 becomes0).
LoadModuleStart480dc6..480def calls typed INT reader1a1770 at480de3 for
`Mod_MaxHenchmen`, default1, and stores the raw signed result. No loader clamp.
GetMaxHenchmen52b960..52b9a7 returns1 without a module; push failure returns-638.
SetMaxHenchmen5438b0..543945 popsINT (-639 failure), clamps1..100 and, if a module
exists, writes3fc. The native splitter has three code ranges; all are captured.
Read-only disassembly and field-reference captures are retained in
`henchman-module-cap-owners-v2.txt` and `henchman-module-cap-field-v1.txt`.

## Implementation and verification

`henchman.js` shares the native cap and script guards. `summon_associate.js`
implements type1 independently of the existing type4 replacement branch, with
a shared accepted-target tail. Module construction/import and five NWScript
bindings use canonical object storage through ObjectLifecycleRuntime.
Removal reuses the existing independently tested native RemoveAssociate owner.
No object IDs are allocated by these calls.

`inspect-native-henchmen.py` executes original instructions in isolated Unicorn:
648 wrapper,2401 type1-add,72 getter,72 setter,64 typed-import and1 bounded ctor
case =3258 captures. Lower VM transfers, resource/object/module lookup,
possession/DM, movement/listen/type/master, faction/list/message, activity and
invisibility are explicit captured boundaries. These are not3258 full-game runs.
Final capture: `henchmen-native-capture-v5.txt` and
`native-henchmen-observations.json`. Earlier failed harness-boundary/field-label
assertions are retained separately and are not validation successes.

`henchmen-native.test.js` compares native order/state/error contracts, plus
session guards and local client admission. Existing summon/removal captures
still pass after the shared-tail extraction. `probe-installed-henchmen.mjs`
passes against actual Prelude module/NPC imports through real NCS bytecode:
cap/get/set, add/query/re-add, foreign/omitted remove rejection, accepted removal
and original faction restoration. No new diagnostics or canonical ID allocation.

Full suite1799 tests/build pass. The built casting UI regression passes
spellbook, radial self cast, slots, F2 targeting/animations/cancel and Counterspell.
Its existing Chromium GPU teardown warning after assertions remains in the log;
this does not establish error-free GPU/audio execution. Auditv45:66 unbound
commands,22 missing resources (was70/22). Binding presence is not full branch
coverage or full spell/combat/campaign readiness.

## Explicit remaining limits

Native possessed-familiar3d54d0 tests type3 and server controlling-client lookup.
Stats DM402f80 only searches actual client objects when associate type==0; its
client DM result comes through4ba8c0 into application client-info. This local
client projects current canonical client identity/DM state; full remote client
info/transport import remains unimplemented. No PLAYER_ID is invented.

Removing a henchman with combat invisibility still reaches the existing explicit
unsupported removal provider. Type47/63 removal side effects are not silently
discarded. Activity1 clearing retains diagnostics for unmapped movement-rate
effect lifecycle. Character-sheet/inventory GUI lower limitations remain those
of the existing RemoveAssociate implementation. Native henchman AI/reprocessing,
charm/domination type5/6 admission, save/export, party UI/network replication,
full spell ecosystem and campaign completion are not established here.
