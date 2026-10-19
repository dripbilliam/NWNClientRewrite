# Shared live creature immortality

Target: NWN:EE89.8193.37-17 x64, original `nwmain.exe` SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
The original executable and Ghidra project remain unchanged.

REA dossiers for GetImmortal `140525f40..525fb6` and SetImmortal
`140541fa0..542001` identify the same creature INT `+8b8`. Independent
disassembly agrees. Getter lookup failure returns0; setter lookup failure
does nothing. Setter stores the raw INT, including2/-1/256. Getter returns
that raw value. Object/int pop failure returns-639; getter push failure-638.
Constructor `14037b226` initializes0.

The outer LoadCreature dossier did not establish the importer. Exact native
`IsImmortal` string references instead lead to ReadStatsFromGff `14040f7f0`:
both bounded owners `14040ff21..47` and `1404100da..100` call `1401a0f60`,
which calls typed BYTE reader `1401a0ee0` and converts its result to Boolean.
Missing/wrong-type fields default0. Thus serialized BYTE2 imports1, while
script SetImmortal(2) remains2. The save owner `1403a0a60` has separate PC/
possession guards and BYTE export; save/export parity is not implemented here.
A full REA ReadStats dossier exceeded its response budget; that failed request
is retained and is not evidence of a successful full-loader analysis.

`creature_immortality.js` owns the canonical INT; the `immortal` semantic accessor
aliases it. BIC/UTC load imports the typed field once. GetImmortal708 and
SetImmortal are bound; damage and strike providers now read the same canonical
field already consumed by enchantment immunity. Editing the authored GFF
snapshot does not change live state. Native consumers retain their existing
distinct comparisons (`==1` versus `!=0`); no Boolean collapse on script writes.

`inspect-native-creature-immortality.py` executes **368 original-code cases**:
complete script wrappers plus both bounded import blocks and complete Boolean/
BYTE readers. VM transfers, creature lookup and GFF descriptor/label lookup are
captured boundaries. It does not execute the whole stats loader/GFF parser or
damage engine. The matching tests also check shared enchantment state, aliases,
invalid types/IDs and no ID allocation. Final installed NCS probe passes across
**62 Prelude creatures** and raw integer script writes. First targeted test run
had two test-harness defects (out-of-range authored writer input and missing
fixture variable); final v2 is34/34 PASS, with no change to the native oracle.

**1,768 full tests PASS; build PASS; installed probe PASS.** Auditv39 now has
**76 unbound commands /22 missing resources**. GetImmortal removes dependencies
in Banishment and Infestation of Maggots; neither complete spell nor campaign
readiness is established. Full casting/combat/campaign work remains open.
