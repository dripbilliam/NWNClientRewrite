# NWN-48 weather clip snapshot reuse

`WeatherWorld.advance()` previously called the pure `WeatherState.snapshot()` once for each of six original weather models whenever intensity changed. It now reuses the clip fraction while the intensity is unchanged. If a model callback changes intensity during the loop, the next model takes a new snapshot. A zero intensity still takes a snapshot per model because `+0.0` and `-0.0` compare equal but can produce different exact clip input bits.

Normal six-model sampling drops from **six snapshot Dictionary allocations to one**. The focused reentrant case drops from **twelve to three** snapshots across two sampling passes. The change preserves model iteration, clip sampling, final-intensity bookkeeping, clear notification and retire behavior. It does not add lightning or audio functionality.

Frozen pre-edit `systems/weather_world.gd` SHA-256: `73b8475ce5d0b5e567d410c10331678b43a59f4d833299cbdce22ad503f02611` (`.cache/nwn48/clip-snapshot-a/control.gd`). Current source SHA-256: `ba1af523a295fb087113ac8273a4c3cd3df9d82d7aa10d8495272380556dc9bb`. `git diff --check -- systems/weather_world.gd` passed.

The portable focused fixture `tools/nwn48/clip-snapshot-test.gd` (SHA-256 `1a43fd0e78ea851615f0d567ede61f824f7fe08ecdc34ad92373bc1d75ede2ee`) passed **23/23** checks for six ordered samples, unchanged-intensity no-op, mid-loop intensity change, clear-time retirement and no work after retire. A private copy of the same fixture loaded frozen control source and also passed 23/23. The two outputs had exactly the same twelve clip events and one release command; their snapshot counts were 12 control versus 3 candidate. Candidate report SHA-256 `51f77c4a845e5b2dd4a303c0b45dab4a026760bdf1a1059e84ae5ffab315758b`; control report SHA-256 `0fb25361efa181d4318dccb1c09b0ea1fc5fb47416c0a4ad1a15681d26cdc1e1`.

These checks use mock visual models and a real `WeatherWorld.advance()` path. Original-asset visual/audio timing and live server acceptance remain outside this slice; no FPS measurement was made. NWN-48 remains open.
