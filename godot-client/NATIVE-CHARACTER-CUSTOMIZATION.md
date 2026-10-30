# Native character customization — preservation groundwork

The Customize control is still disabled. This milestone implements and verifies
the existing-BIC editing layer and records the original flow; it does not claim
the editor, file-save lifecycle or complete character UI is usable.

## Original flow and source evidence

`backups/animations/rea-native-character-customization-v1.json` retains selected
REA facets (procedure identity, pseudocode, assembly, callees, names/strings and
provenance) from original `nwmain.exe` SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
The full p-code graph and raw provider responses are omitted from this extract.

`710130` constructs `CG_MAIN`, sets customization mode1, imports the selected
existing BIC through `7f7e20/802290`, and immediately opens `CG_PORTRAIT` through
`8e58c0`. This is not an unrestricted new first-level character draft.

| Surface / transition | Original evidence | Current acceptance |
| --- | --- | --- |
| Picker Customize | `710130`, return callback `70fec0`; selected local type0 enables it in the earlier picker evidence | Disabled pending complete native editor |
| Portrait | `8e58c0`, attachment `8edb00`: original GUI has five controls; a programmatic portrait chooser is added at `portraits` | Source/resource metadata only |
| Portrait selection | `8edb00` filters by received gender/race, remaps race4 to6; absent selection uses NWN logo and disables OK | Native behavior/visual acceptance open |
| Portrait result | Main callback `8e9be0`: mode1 result2 cancels; `0x8009` opens Appearance | Source only |
| Appearance | `8e25c0`, constructor `8dbab0`, attachment `8eb480`, callback `8e9ab0` | Source/resource metadata only |
| Appearance controls | Twelve programmatic arrow/color buttons and three palette selectors supplement the13 resource controls; model hooks `CharModel`/`CharModelTop` | Not implemented in this editor |
| Customization appearance restrictions | Mode1 preserves the loaded model, disables/removes Clothing controls; MODELTYPE `P` or invalid MODELTYPE disables appearance controls; phenotype rules come from active ruleset | Not accepted natively |
| Appearance result | `8e9ab0`: `0x8002` advances to `CG_CHAR_INFO`; other customization results cancel | Source only |
| Character information | Constructor `8dc1c0`, attachment `8ecc60`;15 resource controls plus programmatic voice choices, original edit Tab cycle and voice/package behavior | Native editor, random name, deity submenu and audio details still open |
| Final result/save | Mode1 `8e9be0` result `0x8007` reaches `8e3f90`, then `809220` edits existing LOCALVAULT/DMVAULT BIC and refreshes directory/picker | Native byte preparation verified; file/IPC lifecycle open |

The33 resource controls are not the complete action inventory. Programmatic
portrait lists, arrow/palette controls, voice rows, native edit/scroll widgets,
deity submenu, keyboard/focus/modal behaviors and role/source routes need their
own source and runtime acceptance. Existing resource-ledger rows remain unverified.

## Existing-BIC preservation

`character_customization_bic.gd` accepts only the fields written by original
`809220`:17 information/appearance fields plus19 extended body/head parts.
Those36 original write calls produce55 physical fields because each extended
part has a legacy BYTE plus an `x`-prefixed WORD. Original `1a3790` writes a
legacy byte of zero for values above255; it does not simply truncate the value.
The extended label is `("x"+label)[:16]`.

The source save routine's asymmetric `ArmorPart_RFoot` spelling is retained in
the field plan. Do not silently replace it with a presumed `BodyPart_RFoot`
without investigating actual original runtime behavior. `PortraitId` is not
among these write calls; portrait-ID normalization/selection still needs editor
and native-loader acceptance. Edited locstrings use the original English0 entry;
untouched translations and other payloads retain their original bytes.

`gff_root_patch.gd` copies physical GFF sections, replacing only edited root
records/data and appending missing fields. Existing struct/label IDs and all
untouched field records, blobs, lists and numeric bit patterns survive. When a
root field ID is also used by a nested struct, the edited root edge gets its own
field so an information edit cannot change an unrelated item/local value.
The native first-level creation writer is never used to regenerate a character.

The GFF reader has an explicit preservation-only duplicate-label mode used by
the byte patcher. Ordinary presentation callers remain strict. The patcher
preserves unrelated physical duplicates and refuses an ambiguous edited field.
This does not make duplicate-bearing characters selectable in the current UI.
Malformed-field behavior, noncanonical sections and every original disk/allocation
failure are not blanket parity claims.

This layer prepares bytes only. The eventual editor must supply the complete
original save draft, validate choices against active resources, capture exact
row/connection/file identity, handle alias precedence and installed-to-profile
copies, atomically save or refuse, refresh the real catalog, and reselect the
authoritative result. None of these is replaced by a successful byte test.

## Verification and next work

`inspect-native-customization-wordbyte.py` executes unchanged original `1a3790`
instructions in an isolated emulator, with GFF lookup/allocation/BYTE write,
snprintf and cookie helpers captured as boundaries. Its120 cases include80
successful existing/new-field cases and40 original allocation-failure cases.
The native encoding is compared against the80 successful cases; native allocator
failure equivalence is not claimed. No game process or user file is modified.

`native-customization-preservation-final-v2` passes190 headless native checks:
all36 source-derived save calls/55 widths, actual original compatibility policy,
all19 GFF field kinds, opaque NaN bits, nested/shared fields, duplicate isolation,
empty/single/multiple root encodings, validation and all39 installed BICs read-only.
`native-customization-gff-final-v2` passes25 existing writer/parser checks;
`native-customization-catalog-final-v2` passes61 existing local-metadata/chooser
checks. The earlier catalog-final-v1 run omitted its required fixture argument
and exited without a result; it is not accepted evidence.

Next work remains the source-backed native portrait/appearance/information
panels and auxiliary widgets, exact modal/cancel/back flow, active-resource
choices, native preview/audio, alias-aware atomic storage and catalog refresh,
graphical input/scale/original-client review, and owned original-server admission
of the saved copy. UI parity, Customize availability and the entire goal remain
unaccepted. No public gameplay connection was made for this milestone.
