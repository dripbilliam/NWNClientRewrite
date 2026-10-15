# Combat UI session integration, 2026-10-13

The renderer now supplies a selectable local PvP setting instead of leaving
the native reputation provider without required session configuration. The
startup-script checkbox skips opening/initial area scripts while preserving
native AI, perception, action and round updates. Isolated owner tests retain
their existing startup-disabled AI bypass unless explicitly enabled.

An unavailable perception query previously aborted the entire creature frame,
including round clocks and action execution. The runtime adapter now records
the failing query and continues other targets. It retains that target's prior
visibility and does not fabricate sight/hearing success. This is explicitly a
replacement failure-recovery policy, **not evidence that indoor sound or
failure behavior matches the original game**. The mapped perception helper
and original successful event ordering remain unchanged.

Repeated session failures appear once per message/area in the HUD and console.
All observed failures remain in the durable diagnostic journal; the session
also retains repeat counts. Indoor sound, ActionUseSkill and other engine
calls are still unimplemented. No such call was replaced with a success stub.

## Validation and interactive launch

- 966 tests and production build pass, including explicit AI/startup
  separation, per-target failure isolation, and notification/journal checks.
- Existing eight-event original perception comparison passes. Its scope
  remains nonstealthed gain/loss flags and ordering, not campaign fights.
- `smoke-ui-combat.mjs` loads the installed Prelude with `fighter.bic`, enters
  m0q1d near its authored M1Q0D19Goblin, and sends normal player attack input.
  No creature stats, equipment, faction, scripts, CR or immortality are altered.
  Captured replacement trace: input accepted, real perception flags3, round
  starts, goblin HP17→−11, attack action eventually removed. Authored event
  scripts still report missing dependencies. This is **not a native encounter
  parity comparison**, and random attack results vary between runs.
- User observed rolls/damage in the interactive renderer after repair.
- Launcher supports a selected installed BIC and an entry-position override.
  Only the input File's IFO entry is changed in memory. Installed assets are
  never written or copied into the workspace. Original Prelude SHA-256 remains
  `3DAAE6B779197CD71A202D87A06BD9C5B2362D3957067490562EA32740D5ADB8`.
- Entry-position tests enable a manual preview sun and elevated camera for
  visibility; that lighting is not an original-game parity claim.

Interactive command, with ELECTRON_RUN_AS_NODE unset:

```text
electron scripts/smoke-viewer.cjs ../FullDecomp/NwnRootInstall ../FullDecomp/NwnRootInstall/data/nwm/Prelude.nwm m0q1d backups/animations/easy-combat-prelude.png --interactive --full-scene --character --character-file=fighter.bic --entry-at=72.8,104.8,0.00001 --play
```

Combat animation/presentation, NPC script support, indoor sound, equipment
exhaustion, status/on-hit/death owners and independent native fights still
block combat readiness. Ghidra and original binaries remain unmodified.
