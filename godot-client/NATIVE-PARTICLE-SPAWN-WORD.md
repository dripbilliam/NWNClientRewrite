# Native particle source-word admission

This is a scoped adapter correction during the active binary-guided world
streaming goal. It does not close the goal, explain every historical crash or
accept a complete scene or 60 FPS.

## Failure and evidence

The actual default Prelude run `native-session-particle-integer-diag-v1` exposed
six emitters rejected with `spawnType=4294967295`. The preceding generic error
did not identify the field. `native/particle_kernel.cpp` now includes field and
value in signed integer range errors.

The native binary MDL decoder in `systems/native_data/emitter_data.gd` retains
the original spawn property as an unsigned dword. The compiled simulator was
using its signed-int32 adapter for that property. It rejected the valid bit
pattern `0xFFFFFFFF` before reaching the fountain branch.

Read-only target: NWN:EE 89.8193.37-17, executable SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
REA dossier: `../backups/animations/rea-particle-spawn-word-v1.json`.
Complete analyzed FountainEmitter::Update body is
`140064b30..140065280` inclusive. At `140064d12`, the original executes
`CMP dword ptr [R15 + 0xb4], 0`. The subsequent branch distinguishes zero from
nonzero; no signed ordering or 0/1-only validation is introduced there.
This is evidence about that use site, not a claim about every engine field.

`../scripts/inspect-native-fountain-update.py --spawn-word-corpus` executes that
unchanged owner and its lifetime helper in the existing hash-gated emulator.
Its 224 cases cover zero, one, signed -1/INT_MIN/INT_MAX and unsigned high-bit
spellings, zero/nonzero rate and time, two render modes, empty/recycled particle
lists, chunk/nonchunk construction and two positions. Allocation, virtual
initialization, movement, randomization and model operations remain explicitly
supplied lower providers; this is not full renderer or scene-physics proof.
Derived observations are in
`../backups/animations/native-fountain-spawn-words-v1.json` (SHA256
`424362c098f4dc36a6bd240c11c0fd87b48d14eada2d0967c022fe6d5039bcd7`).

## Correction and current checks

`word32` is used only for this spawn property. It accepts exact finite integers
in signed or unsigned 32-bit spellings, preserves their dword pattern and
rejects fractions, nonfinite values and out-of-range values. Signed sizes,
counts and other existing adapter fields retain their prior checks.
`tests/native_particle_spawn_words_test.gd` checks the original cases and
invalid boundaries through the compiled backend.

- `native-spawn-words-v1`: 2,140 checks, including the existing original schedule,
  lifetime and frame corpus, the new 224 original executions and invalid input
  checks. No arithmetic tolerance was added.
- `native-spawn-words-simulation-v1`: 18,084 existing checks across 2,160 authored
  moving-emitter frames: state, provider order, RNG and exact vertex bytes.
- `native-spawn-words-vertices-v1`: 492 checks against the existing original
  packed vertex corpus.
- `native-session-spawn-words-v1`: actual default native launcher on owned local
  Prelude, player ready at 1428.837 ms, movement while background objects remain,
  20 final entities/nine tiles, finish acknowledged, zero remaining workers and
  clean exit. Eight emitters have simulation frames versus two before this fix;
  all six integer-range failures are gone. The remaining 49 failures are 17
  point-wind and 32 scene-intersection providers. Active particles are zero at
  the final sample, so this does not prove their complete visible effects.
- `native-capture-spawn-words-v1`: existing offline room, 48 tiles/889 static
  objects/eight animated creatures/one item, zero remaining workers. Screenshot
  inspected; original native clocks and skin positions advance. The 1,182
  diagnosed effect failures remain unchanged. Settled 179 frame intervals average
  20.651 ms, p95 23.307 ms, worst 27.497 ms. Editor PID 1776 is preserved; these
  are uncontrolled wall-clock intervals, not a paired speedup, clean GPU timing
  or complete-scene 60 FPS acceptance. Final snapshot plus native animation,
  rather than full moving protocol replay.

`tools/check-native-particle-spawn-word.mjs` audits these five report sets,
current source/DLL pins, original corpus identity and signed/unsigned trace
equivalence, partial failures, protocol-only module inventory and clean logs.
Its successful output is `reports/native-particle-spawn-word-v1.verified.json`.
The initial audit selected the zero case while matching signed aliases; its
matcher was corrected to require spawnType=-1. The original observations and
native test results did not change.

The named runs use normal-heap CDB, four armed exception traps, unchanged source
pins and no trapped exception or engine/lifetime error. Older proof pins remain
historical checkpoints after this DLL/source change. Do not relabel their
whole-tree audits as current. No new public connections were made. Complete
wind/intersection providers, effects, transitions/reconnect acceptance, clean
cold/warm dense-world FPS and the remaining JS migration are still open.
