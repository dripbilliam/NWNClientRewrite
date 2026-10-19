# Native casting voice fields — 2026-10-16

Casting chants now follow the original race and Gender fields, using installed
spell metadata. No spell-specific exception or sound-name table was added.
Progress toward the active spellcasting/combat/campaign goal; not completion.

Read-only target: NWN:EE89.8193.37-17 x64 `nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original game files and Ghidra project remain unchanged. Previous verified
checkpoint: `backups/client-cast-fields-1860-20261016-v1.zip`,9654 files,
118459882 bytes. Verified checkpoint: `backups/cast-voice-1863-20261016-v2.zip`,
9696 files,120681019 bytes. Attempt v1 failed verification because the active
REA stderr log changed. The checkpoint writer now hashes and archives the same
byte snapshot, and v2 verified every entry's length and SHA256.

## Original field chain

Creature Load14039772d supplies creature+a60 to ReadStatsFromGff at39775c.
Stats ctor1403ee3d7 initializes A4=0. ReadStatsFromGff14040fb64..40fb9b reads
BYTE Gender with current A4 as fallback, then clamps it to4. Copies41203d/412045
store A4 in appearanceInfo17 (server creature a77). Phenotype is a different
field:412048/412050 copy stats DEE to appearanceInfo16 (server a76).

WriteGameObjUpdate_UpdateAppearance1404ea6c0 writes phenotype under flag2 at
4ea81c, Gender under flag4 at4ea838. Client dispatcher14079bce0 case P calls
1407b25c0; type5 dispatches14077fe10. Its appearance branches780543..78055d and
78055d..780579 store phenotype D1 and Gender D0 respectively. Successful body
creation140973de0 copies these cells at9744d0..974508 into live appearance.
The appearance ctor140973840 initializes D0=255,D1=0; a failed model does not
install new Gender. Files named server-appearance-gender-load-asm-v1.txt and
older973160/766960 dossiers must not be taken as Gender import evidence:
44e7f0 is a message handler/phenotype write; the latter pair concerns transforms.

Cast driver1408018d0 reads signed SHORT race50, eligible exactly0..6.
Live appearance D0 exactly1 selects ConjSoundFemale; every other value selects
ConjSoundMale. Suppression374 skips both chant and authored ConjSoundVFX.
Sound position uses handconjure pose when available, otherwise source position.

## Implementation and validation

`importCreatureGender` handles decoded GFF BYTE input and current fallback.
`clientCastVoiceFields` projects live canonical race/Gender into separate client
state; it does not mutate authored data or object IDs. The visual bridge installs
Gender only when its model provider succeeds, retaining prior appearance state
otherwise. Unavailable fields retain a diagnostic; generic conjure effects can
continue independently. Main/projectile presentation now supplies the provider.

`scripts/inspect-native-cast-voice.py` executes the original import/copy/writer/
reader/model-success-copy/race-store/driver instructions. GFF cells, scalar wire
encoding, model/pose, spell lookup, strings and audio output are captured lower
boundaries. `native-cast-voice-observations.json` has5126 cases covering all256
raw Gender bytes, race0/6/7/FFFF/8000, model success/failure, sound suppression and
six missing-Gender/current fallback cases. Three tests compare imported state,
wire ordering, final fields and exact sound selection/position with the port.

All1863 tests and build pass. Installed UI passes ordinary male casting,
owned-memory female Gender1 casting, Silent casting and the existing spellbook/
radial/hotbar/counterspell regression. The untouched wizard uses race1/Gender0,
Daze37 selects installed `vs_chant_ench_lm`; owned Gender1 selects
`vs_chant_ench_lf`. Both retain `sco_mehanmind01`. Silent requests neither.
Actual conjure/cast/fade/callback cleanup, projectile and CC8 text remain checked.
Renderer errors and selected voice/audio failures are empty. Some Electron runs
emit a GPU command-buffer error after PASS/app exit; full GPU stability is not
established. The dark/occluded scene remains a separate presentation issue.

## Remaining limits

This is local field projection with the existing model availability gate, not
complete native appearance creation, raw update packets, dirty flags, replication,
scene scheduling, culling, voice mixer or audio hardware parity. Malformed GFF
type conversion is not proved by the decoded BYTE oracle. NWScript GetGender
defaults were not changed without command-wrapper evidence. Remaining projectile
target/impact/linked paths, effects/engine gaps, combat and campaign remain open.
