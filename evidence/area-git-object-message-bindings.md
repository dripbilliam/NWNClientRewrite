# GIT and object state for complete area-pack bodies

Target: NWN:EE `89.8193.37-17`; original executable SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Static Ghidra/assembly and isolated executions of original instructions are
the reference. No original binary edits, Ghidra edits or actual network sends.

## Loaded state and evidence

Normal ModuleSession loading now binds GIT AreaProperties, ambient settings,
grass overrides, waypoint notes, sounds and placeable appearance/light state
to the decoded area packer. Canonical registry identities remain unchanged.

- LoadProperties140361dd0..140362252, LoadGrass140361330..14036171b,
  ambient constructor1403584a0..1403584f0 and loader140358610..140358746:
  88 cases and115 executions. Missing/current defaults, reloads, strings,
  wind and actual grass map allocation/rehash paths are covered. Grass uses
  native bucket/list order, including duplicate replacement and collisions.
  The successful final WindPitch read alone selects WindPower3. Moon/sun
  defaults are directions from140ddbb40/44/48, not color values.
- Waypoint note block14050a222..14050a2e8:216 cases/432 bounded blocks.
  HasMapNote308 controls inclusion; MapNoteEnabled30c controls its separate
  enabled flag. Unsuccessful/missing note reads preserve prior state.
- Sound selected constructor1404f3637..1404f36ad and load portion
  1404f4c3e..1404f50d8:64 cases/89 executions. Scalar defaults, positions,
  raw BYTE versus BOOL behavior, ResRef handling and append/growth are covered.
- Placeable constructor1404afd17..1404afd22, appearance block
  1404b4f7e..1404b4fa1 and light block1404b52ef..1404b53e1:
  288 cases/576 bounded blocks. Appearance is read as DWORD then narrowed to
  WORD. Light changes depend on LightColor lookup status, including the
  separate second lookup. This does not establish the full placeable loader.

These are1,212 original state/block executions. Full sound playback, every
dynamic creation path and all runtime setters are separate owners.

## Installed data and full original packer

`probe-live-area-pack.mjs` loads all five installed Prelude areas through
normal ModuleSession paths. Explicit fixture PLAYER_ID42 remains separate
from controlled object565. Language0, feature gates and format modes0/1 are
test inputs, not negotiated client capabilities.

All10 complete area-pack bodies succeed without journal failures. The areas
include204 spatial objects and144 tiles. `inspect-live-area-pack.py` then
executes the full unchanged original PackArea owner against snapshots of
those same loaded inputs. Every defined output bit and final writer counter,
capacity, cursor and flag matches. Unknown envelope/padding bits are masked
explicitly. Captured server/GFF/lookup boundaries remain fixtures.

Files: `live-area-pack-v6.txt`, `live-area-pack.json`,
`live-area-pack-cases.json`, `native-live-area-pack-v1.txt` and
`native-live-area-pack-observations.json` in backups/animations. The four
new state oracle reports are native-area-properties-v1,
native-waypoint-note-v1, native-sound-message-v1 and
native-placeable-message-v1, with corresponding observation JSON files.

## Validation and remaining work

1,421 tests pass; production build passes. Rendered smoke check
`git-area-transfer-ui-v1.txt` passes radial summoning, slot consumption,
Follow/Stand, transfer out/back with canonical summon575/master565 and
radial Unsummon. Screenshot inspected; scene remains dark and the known
DoSinglePlayerAutoSave omission is still recorded. No blanket gameplay claim.

The ten matches establish full area-pack bodies. The outer ClientArea flow,
client receiver, ready transport, production client identity/lifecycle,
autosave and continuous campaign acceptance remain unfinished. Spellcasting,
combat and the full campaign goal stay active.

Verified backup report: backups/animations/git-area-checkpoint.txt.
