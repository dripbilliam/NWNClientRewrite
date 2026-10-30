# Pregenerated-character preference — partial parity

The subsequent [native local catalog follow-up](NATIVE-LOCAL-CHARACTER-CATALOG.md)
decodes metadata for the installed and replacement-vault sources and uses active
Pregen-table membership. It supersedes that metadata gap below for those sources;
general original/workshop discovery and full local mutation remain unfinished.

The native chooser now restores and saves its Show Pregenerated Characters
checkbox. Missing preferences default off; explicit false survives reopening.
Loading happens before the first native row rebuild, and saving happens when
the chooser is destroyed, matching the original panel's lifecycle.

## Original evidence and implementation

Root `backups/animations/rea-native-character-pregen-persistence-v1.json`
retains original constructor `140708660`, destructor `14070a6b0`, configuration
string references and the two decoded callback instructions. Original binary
SHA256 is `3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.

The constructor reads `game.character-generation.show-pregenerated` with a false
default into its field at `0x1c80`. The checkbox callback at `14070ffc0` writes
that field and jumps to the list rebuild `140714a70`. The destructor passes its
nonzero boolean to `CExoConfig::Set<bool>` with persistence enabled.

`systems/native_data/character_lobby_preferences.gd` owns the replacement's
boolean configuration. The normal native session opens
`user://native-character-lobby.cfg`; the original game's profile is untouched.
The native chooser restores the value before building and saves it exactly once
on close. Recreating a chooser with the same owner also retains memory state.
The file is loaded again before saving to preserve unrelated current settings.
Invalid types/read failures preserve the existing file and expose a failure;
an unavailable destination cannot report a successful save. This preference
contains no account or CD-key data.

Isolated native fixtures leave persistence unconfigured unless their test
explicitly supplies an owned file. The normal local/menu harness passes its
own per-run `.lobby.cfg` path, so tests cannot change normal user preferences.
Native session shutdown records preference status after closing the chooser.
Rendering, checkbox state, persistence and filtering stay native Godot; the
existing host merely supplies a test file path.

The existing filter/selection lifecycle is preserved: a changed filter rebuilds
visible rows and requests the first one without Play. A stale held checkbox
cannot change the replacement connection's state. Missing local metadata still
disables the checkbox without erasing its saved value.

## Verification and rollback

| Accepted run | Checks | Scope |
| --- | ---: | --- |
| `native-pregen-preferences-graphical-v2` |26| Actual checkbox input; true/false on-disk round trips through fresh native owners; save-on-close, unrelated settings, stale-held guard, invalid/unavailable destinations and restored original-artwork capture |
| `native-pregen-chooser-graphical-v2` |31| Existing source frame, pointer/double-click, filter, first selection, acknowledgments and New/Cancel regression |
| `native-pregen-edit-graphical-v1` |94| Original hidden-edit observations and real focused-key ownership regression |
| `native-pregen-local-v1` |207| Seven admission, eighteen real two-participant roster, twelve exact native BIC record-input and170 authoritative UI/gameplay action checks |

Total:358 scoped checks. Native debugger traps were armed, source hashes stayed
unchanged and accepted runs reported no exception or engine/lifetime error.
All automated connections were to the owned original server at
`127.0.0.1:5125`. The local receipt records one successful native preference
write, with false on disk and no failure. Both temporary preview files and the
owned server/participant were cleaned up. Graphical runs used a secondary
monitor without OS focus or mouse capture; original clients were preserved.

The restored checked-state screenshot
`reports/native-pregen-preferences-graphical-v2.restored.png` was reviewed: the
original checkbox shows checked and both supplied rows are visible. This is a
functional/artwork capture, not complete original-client visual acceptance.
The chooser still has visible stacked outlines above its page tabs that need
source-state investigation; exact artwork/state/scale comparison remains open.

`tools/audit-native-character-pregenerated.mjs` verifies current source pins,
original evidence, preference file outcomes, scoped receipts and the verified
rollback archive `backups/native-character-pregenerated-v1.zip`. Earlier
headless/graphical preference runs are retained; their duplicate counts are not
added to this milestone.

## Remaining work

The native local catalog still lacks the complete metadata needed to classify
every installed or saved BIC. Those entries cannot yet reliably expose this
filter in normal local-vault play. Native metadata acquisition, names/classes/
portraits, original sort/source distinctions and permitted Delete/Customize are
next; persistence does not complete those controls. Original filtering uses a
character-record field at `0x48`; its producer must be traced before assuming
all installed files or arbitrary BICs share a classification.

Full rejection/rebuild/record modes, sound, tab-state artwork, role/scale and
direct original-client visual/gesture comparisons remain open. The separate
retained startup heap exception and headless Player List artwork failure remain
unresolved. Complete chooser/UI/stability parity is unaccepted; the
[full UI goal](NATIVE-UI-PARITY-GOAL.md) stays active before general game porting.
