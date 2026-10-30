# Original binary base movement rates

2026-10-25. Read-only inspection requested after the local4m/s test was described
too broadly as full speed. No client restart, gameplay change or public
connection was made for this inspection.

Target: NWN:EE89.8193.37-17 x64 `nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Fresh REA/Ghidra12.1.4 ephemeral immutable analysis; original executable,
installation, process and existing Ghidra project remain unchanged.

## Binary observations

`CNWSCreatureStats::SetMovementRate`1404160a0 reads the selected physical
CreatureSpeed row, writes category to stats+e20, reads WALKRATE at call140416358
into stats+e28 and RUNRATE at call1404163d0 into stats+e24. Category7 resolves
appearance.MOVERATE against CreatureSpeed.2DAName case-insensitively; its zero
table row values are not used directly as the default creature's speed.
Evidence: `ev_cf37f5483e0d942fd3a165ee404e3811edfa32edb069a2842f3e6c1aedc3dee8`.

`CNWSCreature::GetRunRate`140393080 loads stats+e24 at140393090, calls
GetMovementRateFactor140391fe0 at140393098, multiplies the cached base by1000
at14039309d and then multiplies by the factor at1403930a5. Constant/p-code
0x447a0000 is float1000. The instruction order, rather than reassociated
decompiler multiplication, is authoritative. There is no global4m/s clamp in
this getter. Evidence: `ev_e2e7cc3c56f4897471a033d1ff90b6f090207eddb7852167f6e0f965f94f02b0`.

GetMovementRateFactor140391fe0 reads stored factor+8e8; it also handles a
collision override, barbarian feat194, usable monk feat207/class5 and configurable
factor caps. No buffs therefore does not necessarily mean no intrinsic class
speed bonus. The ordinary unmodified factor is1. The default1.5 bonus cap is a
multiplier cap, not the base run rate. Evidence:
`ev_107da80e2c80e8da3ca78640141e7e9665a737b0e16f467e5544184cae6fe35d`.

Derived dossiers (addresses, pseudocode and original instruction observations,
not executable bytes): `reports/native-base-speed-binary-v1.json`.
Prior mapping/oracle context: `../evidence/combat-native-approach.md` and
`../backups/animations/live-native-movement-rates-height-asm.txt`.

## Original installed rule values

Read in place through the native catalog from the original KEY/BIF stores;
no module/HAK/Workshop/NWSync/override layer was added. These are stock values,
not a measurement of an Arelith character's current movement rate.

| Category | Walk | Run |
|---|---:|---:|
|0 PC_Movement / PLAYER |2m/s |4m/s |
|1 Immobile |0 |0 |
|2 Very_Slow |0.75m/s |1.5m/s |
|3 Slow |1.25m/s |2.5m/s |
|4 Normal / NORM |1.75m/s |3.5m/s |
|5 Fast |2.25m/s |4.5m/s |
|6 Very_Fast |2.75m/s |5.5m/s |
|7 Default |Resolved through appearance.MOVERATE |Resolved through appearance.MOVERATE |
|8 DM_Fast |5.5m/s |11m/s |

The seven standard playable appearance rows name NORM for category7 resolution;
that does not override a PC explicitly assigned category0. The selected movement
category matters independently of appearance. The fastest stock non-DM category
is5.5m/s; the highest stock base table category including DM is11m/s. Ordinary
unmodified PC running remains4m/s, not a universal maximum. Active server rule
overrides, selected categories and intrinsic abilities can change the result.

Receipt: `reports/native-base-speed-inspection-v1.json` and its debugger proof;
native read-only inspector `tools/inspect-native-base-speed.gd`.
CreatureSpeed resource SHA256:
`6f9ba6ecfb2e814c1b5fadf6c9717abb9560bdb6a7e2994001c023b2d19a9cef`.
Appearance resource SHA256:
`815c0b3bce0895e9f17d4b92cb02a6d34366267b5a4b9081dece0f4eee7d7a1a`.
The report stores only derived rate/category facts and hashes, not original
resource files. Normal-heap CDB4traps; successful read, unchanged sources,
no engine/lifetime error. No GPU benchmark or public gameplay test was run.
